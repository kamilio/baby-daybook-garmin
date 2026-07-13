import {
  HttpError,
  appleAuthorizationUrl,
  decodeDocument,
  decodeFields,
  firebaseError,
  parseAppleCallback,
} from "./auth-core.mjs?v=20260712-2";

const FIREBASE_API_KEY = "AIzaSyDIjjUS-7888pKeaVgNM1g2lSLOX4i6Na8";
const FIREBASE_PROJECT_ID = "baby-daybook-app";
const ANDROID_PACKAGE = "com.drillyapps.babydaybook";
const ANDROID_CERT = "F63803E1E071269A0DDAB71664A1A55F6F27F8D4";

const state = randomState();
const appleLink = document.querySelector("#apple-link");
const callbackForm = document.querySelector("#callback-form");
const babyForm = document.querySelector("#baby-form");
const babyOptions = document.querySelector("#baby-options");
const status = document.querySelector("#status");
const setupCode = document.querySelector("#setup-code");
const copySetupCode = document.querySelector("#copy-setup-code");

let refreshToken = "";

appleLink.href = appleAuthorizationUrl(state);
appleLink.addEventListener("click", () => showStep(2));

callbackForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  clearStatus();
  setLoading(true, "Verifying Apple sign-in…");

  try {
    const callback = parseAppleCallback(new FormData(callbackForm).get("callback"), state);
    const session = await exchangeAppleCredential(callback);
    refreshToken = session.refreshToken;
    const babies = await listBabies(session.idToken, session.localId);
    renderBabies(babies);
    showStep(3);
    clearStatus();
  } catch (error) {
    showError(readableError(error));
  } finally {
    setLoading(false);
  }
});

babyForm.addEventListener("submit", (event) => {
  event.preventDefault();
  clearStatus();
  const values = new FormData(babyForm);
  const babyUid = String(values.get("babyUid") || "").trim();
  if (!refreshToken || !babyUid) {
    showError("Choose a baby profile before continuing.");
    return;
  }

  if (!/^[A-Za-z0-9_-]+$/.test(refreshToken) || !/^[A-Za-z0-9_-]+$/.test(babyUid)) {
    showError("Baby Daybook returned a setup value Garmin cannot import.");
    return;
  }
  const callbackUrl = `connectiq://oauth?refreshToken=${refreshToken}&babyUid=${babyUid}`;
  setupCode.value = callbackUrl;
  showStep(4);
});

copySetupCode.addEventListener("click", async () => {
  await navigator.clipboard.writeText(setupCode.value);
  copySetupCode.textContent = "Copied";
});

document.querySelectorAll("[data-back]").forEach((button) => {
  button.addEventListener("click", () => showStep(Number(button.dataset.back)));
});

async function exchangeAppleCredential(credential) {
  const postBody = new URLSearchParams({
    providerId: "apple.com",
    id_token: credential.idToken,
    access_token: credential.authorizationCode,
  });
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=${encodeURIComponent(FIREBASE_API_KEY)}`,
    {
      method: "POST",
      headers: firebaseHeaders(),
      body: JSON.stringify({
        postBody: postBody.toString(),
        requestUri: "http://localhost",
        returnIdpCredential: true,
        returnSecureToken: true,
      }),
    },
  );
  const body = await response.json();
  if (!response.ok) throw new Error(firebaseError(body));
  if (!body.idToken || !body.refreshToken || !body.localId) {
    throw new Error("Baby Daybook returned an incomplete login session.");
  }
  return body;
}

async function listBabies(idToken, userId) {
  const [created, accepted] = await Promise.all([
    listCollection(idToken, `userData/${userId}/createdBabies`, "babyUid"),
    listCollection(idToken, `userData/${userId}/acceptedInvites`, "babyUid"),
  ]);
  const babyUids = [...new Set([...created, ...accepted]
    .filter((record) => !record.deleted && typeof record.babyUid === "string")
    .map((record) => record.babyUid))];

  const babies = await Promise.all(babyUids.map(async (uid) => {
    const normalizedUid = uid.replace(/^babyUid_/, "");
    const document = await getDocument(idToken, `babyData/babyUid_${normalizedUid}`);
    return document ? { ...document, uid: document.uid || normalizedUid } : null;
  }));
  return babies.filter((baby) => baby && !baby.deleted);
}

async function listCollection(idToken, path, idField) {
  const response = await firestoreRequest(idToken, path);
  if (!response.documents) return [];
  return response.documents.map((document) => decodeDocument(document, idField));
}

async function getDocument(idToken, path) {
  try {
    const response = await firestoreRequest(idToken, path);
    return decodeFields(response.fields || {});
  } catch (error) {
    if (error instanceof HttpError && error.status === 404) return null;
    throw error;
  }
}

async function firestoreRequest(idToken, path) {
  const encodedPath = path.split("/").map(encodeURIComponent).join("/");
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/${encodedPath}`,
    { headers: { Authorization: `Bearer ${idToken}` } },
  );
  const body = await response.json();
  if (!response.ok) throw new HttpError(response.status, body?.error?.message || "Could not load Baby Daybook profiles.");
  return body;
}

function renderBabies(babies) {
  babyOptions.replaceChildren();
  if (babies.length === 0) {
    showError("No Baby Daybook profiles were found for this Apple account.");
    return;
  }

  const label = document.createElement("label");
  label.htmlFor = "baby-select";
  label.textContent = "Baby profile";
  const select = document.createElement("select");
  select.id = "baby-select";
  select.name = "babyUid";
  select.required = true;
  const hasVictoria = babies.some((baby) => baby.name === "Victoria");
  babies.forEach((baby, index) => {
    const option = document.createElement("option");
    option.value = baby.uid;
    option.textContent = baby.name || "Baby Daybook profile";
    option.selected = baby.name === "Victoria" || (index === 0 && !hasVictoria);
    select.append(option);
  });
  babyOptions.append(label, select);
}

function firebaseHeaders() {
  return {
    "Content-Type": "application/json",
    "X-Android-Package": ANDROID_PACKAGE,
    "X-Android-Cert": ANDROID_CERT,
  };
}

function showStep(step) {
  document.querySelectorAll("[data-step]").forEach((section) => {
    const active = Number(section.dataset.step) === step;
    section.hidden = !active;
    section.classList.toggle("active", active);
  });
  document.querySelectorAll("[data-progress]").forEach((item) => {
    const itemStep = Number(item.dataset.progress);
    item.classList.toggle("active", itemStep === step);
    item.classList.toggle("done", itemStep < step);
    const badge = item.querySelector("span");
    badge.textContent = itemStep < step ? "✓" : String(itemStep);
  });
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function setLoading(loading, message = "") {
  callbackForm.querySelector("button[type=submit]").disabled = loading;
  if (loading) {
    status.hidden = false;
    status.className = "status loading";
    status.textContent = message;
  }
}

function showError(message) {
  status.hidden = false;
  status.className = "status";
  status.textContent = message;
}

function clearStatus() {
  status.hidden = true;
  status.textContent = "";
}

function randomState() {
  const bytes = crypto.getRandomValues(new Uint8Array(24));
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function readableError(error) {
  return error instanceof Error ? error.message : "Something went wrong. Please try again.";
}
