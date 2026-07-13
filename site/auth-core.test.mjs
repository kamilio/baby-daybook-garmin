import assert from "node:assert/strict";
import test from "node:test";
import {
  APPLE_CLIENT_ID,
  APPLE_REDIRECT_URI,
  appleAuthorizationUrl,
  decodeDocument,
  decodeFields,
  firebaseError,
  parseAppleCallback,
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

test("renders a useful Firebase rejection", () => {
  assert.match(firebaseError({ error: { message: "INVALID_IDP_RESPONSE" } }), /fresh Apple sign-in/);
});
