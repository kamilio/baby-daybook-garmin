export const APPLE_CLIENT_ID = "babydaybook.com";
export const APPLE_REDIRECT_URI = "https://us-central1-baby-daybook-app.cloudfunctions.net/signInWithAppleAndroid";
export const GARMIN_SYNC_RELAY_URL = "https://baby-daybook-kjopek.fly.dev/garmin/sync";
export const SESSION_REFRESH_TOKEN = "babyDaybookGarmin.refreshToken";
export const SESSION_BABY_UID = "babyDaybookGarmin.babyUid";

export function appleAuthorizationUrl(state) {
  const url = new URL("https://appleid.apple.com/auth/authorize");
  url.search = new URLSearchParams({
    client_id: APPLE_CLIENT_ID,
    redirect_uri: APPLE_REDIRECT_URI,
    scope: "email name",
    response_type: "code id_token",
    response_mode: "form_post",
    state,
  }).toString();
  return url.href;
}

export function parseAppleCallback(value, expectedState) {
  const raw = String(value || "").trim();
  if (!raw.startsWith("intent://callback?")) {
    throw new Error("Paste the complete callback beginning with intent://callback?.");
  }

  const url = new URL(raw);
  const error = url.searchParams.get("error");
  if (error) throw new Error(`Apple sign-in failed: ${error}`);
  if (url.searchParams.get("state") !== expectedState) {
    throw new Error("This callback belongs to a different sign-in attempt. Start Apple sign-in again.");
  }

  const idToken = url.searchParams.get("id_token")?.trim();
  const authorizationCode = url.searchParams.get("code")?.trim();
  if (!idToken || !authorizationCode) {
    throw new Error("The Apple callback is missing its one-time credential.");
  }
  return { idToken, authorizationCode };
}

export function decodeFields(fields) {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]));
}

export function decodeDocument(document, idField) {
  const data = decodeFields(document.fields || {});
  if (idField && data[idField] === undefined) {
    data[idField] = String(document.name || "").split("/").at(-1);
  }
  return data;
}

export function parseWatchEvents(payload) {
  const raw = String(payload || "");
  if (!raw) throw new Error("The watch did not send any queued events.");
  const records = raw.split("~");
  if (records.length > 10) throw new Error("The watch sent too many queued events at once.");
  const events = records.map((record) => {
    const fields = record.split("|");
    if (fields.length !== 6) throw new Error("The watch sent an invalid event.");
    const [id, type, rawStartMillis, rawVolume, rawPee, rawPoo] = fields;
    if (!/^[0-9]+-[0-9]+$/.test(id) || !["bottle", "diaper_change"].includes(type) || !/^\d+$/.test(rawStartMillis)) {
      throw new Error("The watch sent an invalid event.");
    }
    const startMillis = Number(rawStartMillis);
    if (!Number.isSafeInteger(startMillis)) throw new Error("The watch sent an invalid event time.");
    if (type === "bottle") {
      if (rawPee !== "0" || rawPoo !== "0" || (rawVolume && !/^\d+(?:\.\d+)?$/.test(rawVolume))) {
        throw new Error("The watch sent an invalid bottle event.");
      }
      const volume = rawVolume ? Number(rawVolume) : undefined;
      if (volume !== undefined && (!Number.isFinite(volume) || volume < 0 || volume > 5_000)) {
        throw new Error("The watch sent an invalid bottle volume.");
      }
      return { id, type, startMillis, ...(volume === undefined ? {} : { volume }) };
    }
    if (rawVolume || !["0", "1"].includes(rawPee) || !["0", "1"].includes(rawPoo)) {
      throw new Error("The watch sent an invalid diaper event.");
    }
    return { id, type, startMillis, pee: rawPee === "1", poo: rawPoo === "1" };
  });
  if (new Set(events.map(({ id }) => id)).size !== events.length) {
    throw new Error("The watch sent a duplicate queued event.");
  }
  return events;
}

export async function syncWatchEventsWithRelay({
  payload,
  refreshToken,
  babyUid,
  fetchImpl = globalThis.fetch,
}) {
  const normalizedRefreshToken = String(refreshToken || "");
  const normalizedBabyUid = String(babyUid || "");
  if (!normalizedRefreshToken || !normalizedBabyUid) {
    throw new Error("Sign in from the watch once before syncing events.");
  }
  if (normalizedRefreshToken.length > 4_096 || !/^[A-Za-z0-9_-]{1,128}$/.test(normalizedBabyUid)) {
    throw new Error("The saved Baby Daybook connection is invalid. Reconnect the watch.");
  }
  const events = parseWatchEvents(payload);
  const response = await fetchImpl(GARMIN_SYNC_RELAY_URL, {
    method: "POST",
    credentials: "omit",
    cache: "no-store",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refreshToken: normalizedRefreshToken, babyUid: normalizedBabyUid, events }),
  });
  let body;
  try {
    body = await response.json();
  } catch {
    throw new Error(`Watch sync relay returned an invalid response (${response.status}).`);
  }
  if (!response.ok || body?.ok !== true) {
    throw new Error(relayErrorMessage(body?.error, response.status));
  }
  const expectedIds = events.map(({ id }) => id);
  if (!Array.isArray(body.acked)
      || body.acked.length !== expectedIds.length
      || body.acked.some((id, index) => id !== expectedIds[index])) {
    throw new Error("Watch sync relay did not acknowledge the complete event batch.");
  }
  if (typeof body.refreshToken !== "string" || !body.refreshToken) {
    throw new Error("Watch sync relay did not return the rotated Baby Daybook session.");
  }
  return { events, acked: body.acked, refreshToken: body.refreshToken };
}

export function loadBrowserSyncCredentials(storage) {
  try {
    return {
      refreshToken: storage.getItem(SESSION_REFRESH_TOKEN) || "",
      babyUid: storage.getItem(SESSION_BABY_UID) || "",
    };
  } catch {
    return { refreshToken: "", babyUid: "" };
  }
}

export function storeBrowserSyncCredentials(storage, { refreshToken, babyUid }) {
  try {
    storage.setItem(SESSION_REFRESH_TOKEN, refreshToken);
    storage.setItem(SESSION_BABY_UID, babyUid);
    return true;
  } catch {
    return false;
  }
}

function relayErrorMessage(code, status) {
  if (code === "invalid_token") return "The saved Baby Daybook sign-in expired. Reconnect the watch and try again.";
  if (code === "forbidden") return "Baby Daybook denied access to this baby profile. Reconnect the watch and try again.";
  if (code === "invalid_request") return "The watch sent an invalid sync request. Update the watch app and try again.";
  if (code === "upstream_error") return "Baby Daybook is temporarily unavailable. Try syncing again later.";
  return `Watch sync relay rejected the request (${status}).`;
}

export function decodeValue(value) {
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("booleanValue" in value) return value.booleanValue;
  if ("nullValue" in value) return null;
  if ("timestampValue" in value) return value.timestampValue;
  if ("arrayValue" in value) return (value.arrayValue.values || []).map(decodeValue);
  if ("mapValue" in value) return decodeFields(value.mapValue.fields || {});
  return undefined;
}

export function firebaseError(body) {
  const message = body?.error?.message || "Apple sign-in could not be completed.";
  if (message.includes("INVALID_IDP_RESPONSE")) {
    return "Apple rejected this one-time callback. Start a fresh Apple sign-in and try again.";
  }
  return message.replaceAll("_", " ").toLowerCase().replace(/^./, (letter) => letter.toUpperCase());
}

export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
