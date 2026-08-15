import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  APPLE_CLIENT_ID,
  APPLE_REDIRECT_URI,
  GARMIN_SYNC_RELAY_URL,
  appleAuthorizationUrl,
  decodeDocument,
  decodeFields,
  firebaseError,
  loadBrowserSyncCredentials,
  parseAppleCallback,
  parseWatchEvents,
  storeBrowserSyncCredentials,
  syncWatchEventsWithRelay,
} from "./auth-core.mjs";

test("builds Baby Daybook's registered Apple authorization request", () => {
  const url = new URL(appleAuthorizationUrl("state-1"));
  assert.equal(url.origin + url.pathname, "https://appleid.apple.com/auth/authorize");
  assert.equal(url.searchParams.get("client_id"), APPLE_CLIENT_ID);
  assert.equal(url.searchParams.get("redirect_uri"), APPLE_REDIRECT_URI);
  assert.equal(url.searchParams.get("response_mode"), "form_post");
  assert.equal(url.searchParams.get("state"), "state-1");
});

test("parses a matching one-time Apple intent callback", () => {
  const parsed = parseAppleCallback(
    "intent://callback?state=state-1&code=apple-code&id_token=apple-id#Intent;scheme=signinwithapple;end",
    "state-1",
  );
  assert.deepEqual(parsed, { idToken: "apple-id", authorizationCode: "apple-code" });
});

test("rejects stale, incomplete, and failed callbacks", () => {
  assert.throws(() => parseAppleCallback("https://example.com", "state-1"), /complete callback/);
  assert.throws(() => parseAppleCallback("intent://callback?state=wrong&code=c&id_token=i", "state-1"), /different sign-in/);
  assert.throws(() => parseAppleCallback("intent://callback?state=state-1&code=c", "state-1"), /missing/);
  assert.throws(() => parseAppleCallback("intent://callback?state=state-1&error=access_denied", "state-1"), /access_denied/);
});

test("decodes Firestore baby profile fields", () => {
  assert.deepEqual(decodeFields({
    name: { stringValue: "Victoria" },
    deleted: { booleanValue: false },
    birthdayMillis: { integerValue: "1786049460000" },
    tags: { arrayValue: { values: [{ stringValue: "girl" }] } },
    nested: { mapValue: { fields: { color: { stringValue: "#FF647E" } } } },
  }), {
    name: "Victoria",
    deleted: false,
    birthdayMillis: 1786049460000,
    tags: ["girl"],
    nested: { color: "#FF647E" },
  });
});

test("uses the Firestore document id when babyUid is omitted from fields", () => {
  const result = decodeDocument({
    name: "projects/x/databases/(default)/documents/userData/user/createdBabies/victoria-uid",
    fields: { deleted: { booleanValue: false } },
  }, "babyUid");
  assert.equal(result.babyUid, "victoria-uid");
});

test("parses compact watch event batches for the relay", () => {
  assert.deepEqual(parseWatchEvents("100-1|bottle|1000|120|0|0~101-2|diaper_change|2000||1|0"), [
    { id: "100-1", type: "bottle", startMillis: 1000, volume: 120 },
    { id: "101-2", type: "diaper_change", startMillis: 2000, pee: true, poo: false },
  ]);
  assert.throws(() => parseWatchEvents("bad"), /invalid event/);
  assert.throws(() => parseWatchEvents("100-1|bottle|1000|NaN|0|0"), /invalid bottle/);
  assert.throws(() => parseWatchEvents("100-1|bottle|1000|120|0|0~100-1|bottle|1000|120|0|0"), /duplicate/);
});

test("routes the browser sync fallback through the Fly relay and returns its rotated token", async () => {
  const requests = [];
  const result = await syncWatchEventsWithRelay({
    payload: "100-1|bottle|1000|120|0|0~101-2|diaper_change|2000||1|0",
    refreshToken: "refresh-token",
    babyUid: "baby-1",
    fetchImpl: async (...request) => {
      requests.push(request);
      return {
        ok: true,
        status: 200,
        json: async () => ({ ok: true, acked: ["100-1", "101-2"], refreshToken: "rotated-token" }),
      };
    },
  });

  assert.equal(requests.length, 1);
  assert.equal(requests[0][0], GARMIN_SYNC_RELAY_URL);
  assert.equal(requests[0][1].credentials, "omit");
  assert.equal(requests[0][1].cache, "no-store");
  assert.deepEqual(requests[0][1].headers, { "Content-Type": "application/json" });
  assert.deepEqual(JSON.parse(requests[0][1].body), {
    refreshToken: "refresh-token",
    babyUid: "baby-1",
    events: [
      { id: "100-1", type: "bottle", startMillis: 1000, volume: 120 },
      { id: "101-2", type: "diaper_change", startMillis: 2000, pee: true, poo: false },
    ],
  });
  assert.deepEqual(result, {
    events: [
      { id: "100-1", type: "bottle", startMillis: 1000, volume: 120 },
      { id: "101-2", type: "diaper_change", startMillis: 2000, pee: true, poo: false },
    ],
    acked: ["100-1", "101-2"],
    refreshToken: "rotated-token",
  });
});

test("refuses to acknowledge incomplete relay responses", async () => {
  await assert.rejects(syncWatchEventsWithRelay({
    payload: "100-1|bottle|1000|120|0|0",
    refreshToken: "refresh-token",
    babyUid: "baby-1",
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      json: async () => ({ ok: true, acked: [], refreshToken: "rotated-token" }),
    }),
  }), /complete event batch/);
});

test("does not contact the relay without saved credentials", async () => {
  let contacted = false;
  await assert.rejects(syncWatchEventsWithRelay({
    payload: "100-1|bottle|1000|120|0|0",
    refreshToken: "",
    babyUid: "baby-1",
    fetchImpl: async () => {
      contacted = true;
      throw new Error("unexpected request");
    },
  }), /sign in from the watch/i);
  assert.equal(contacted, false);
});

test("turns relay authentication failures into a reconnect instruction", async () => {
  await assert.rejects(syncWatchEventsWithRelay({
    payload: "100-1|bottle|1000|120|0|0",
    refreshToken: "expired",
    babyUid: "baby-1",
    fetchImpl: async () => ({
      ok: false,
      status: 401,
      json: async () => ({ ok: false, error: "invalid_token" }),
    }),
  }), /reconnect the watch/i);
});

test("persists the relay's rotated refresh token for the next browser sync", () => {
  const values = new Map();
  const storage = {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value),
  };
  assert.equal(storeBrowserSyncCredentials(storage, { refreshToken: "original", babyUid: "baby-1" }), true);
  const credentials = loadBrowserSyncCredentials(storage);
  assert.equal(storeBrowserSyncCredentials(storage, { ...credentials, refreshToken: "rotated" }), true);

  assert.deepEqual(loadBrowserSyncCredentials(storage), {
    refreshToken: "rotated",
    babyUid: "baby-1",
  });
});

test("keeps normal provisioning usable when browser storage is unavailable", () => {
  const unavailableStorage = {
    getItem: () => { throw new Error("storage disabled"); },
    setItem: () => { throw new Error("storage disabled"); },
  };

  assert.deepEqual(loadBrowserSyncCredentials(unavailableStorage), { refreshToken: "", babyUid: "" });
  assert.equal(storeBrowserSyncCredentials(unavailableStorage, {
    refreshToken: "refresh-token",
    babyUid: "baby-1",
  }), false);
});

test("the browser sync fallback has no direct Firestore writer", async () => {
  const source = (await Promise.all([
    readFile(new URL("./app.js", import.meta.url), "utf8"),
    readFile(new URL("./auth-core.mjs", import.meta.url), "utf8"),
  ])).join("\n");
  assert.doesNotMatch(source, /documents:commit/);
  assert.doesNotMatch(source, /commitWatchEvents|refreshBrowserSession/);
  assert.doesNotMatch(source, /integerValue:\s*["']3["']/);
  assert.doesNotMatch(source, /dailyActions|updateTransforms|setToServerValue/);
});

test("renders a useful Firebase rejection", () => {
  assert.match(firebaseError({ error: { message: "INVALID_IDP_RESPONSE" } }), /fresh Apple sign-in/);
});
