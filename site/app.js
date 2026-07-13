const form = document.querySelector("#provisioning-form");
const status = document.querySelector("#status");

form.addEventListener("submit", (event) => {
  event.preventDefault();

  const data = new FormData(form);
  const refreshToken = String(data.get("refreshToken") || "").trim();
  const babyUid = String(data.get("babyUid") || "").trim();

  if (!refreshToken || !babyUid) {
    status.textContent = "Both values are required.";
    return;
  }

  status.textContent = "Returning credentials to Garmin…";
  const params = new URLSearchParams({ refreshToken, babyUid });
  window.location.assign(`connectiq://oauth?${params.toString()}`);
});
