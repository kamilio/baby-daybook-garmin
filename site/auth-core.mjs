export const APPLE_CLIENT_ID = "babydaybook.com";
export const APPLE_REDIRECT_URI = "https://us-central1-baby-daybook-app.cloudfunctions.net/signInWithAppleAndroid";

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
