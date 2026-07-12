import Toybox.Communications;
import Toybox.Lang;

// Firebase ID-token lifecycle over the securetoken.googleapis.com REST
// endpoint. Caches the ID token in Store.authCache and only refreshes once
// it is within TOKEN_EXPIRY_SKEW_MILLIS of expiring. The API key rejects
// requests missing the Android app identification headers below, since it
// is scoped to the Baby Daybook Android app rather than a generic client.
// No UI imports: this module must stay safe to pull into the (:background)
// build, where the background sync service calls it directly.
(:background)
module TokenClient {

    const TOKEN_URL = "https://securetoken.googleapis.com/v1/token?key=AIzaSyDIjjUS-7888pKeaVgNM1g2lSLOX4i6Na8";
    const ANDROID_PACKAGE = "com.drillyapps.babydaybook";
    const ANDROID_CERT = "F63803E1E071269A0DDAB71664A1A55F6F27F8D4";

    const TOKEN_EXPIRY_SKEW_MILLIS = 60000;
    const DEFAULT_EXPIRES_IN_SECONDS = 3600l;

    // Error codes passed to getIdToken's callback in place of a token.
    const AUTH_INVALID = 1;
    const RETRYABLE = 2;

    // Callbacks queued while a refresh request is in flight, so concurrent
    // getIdToken() calls (e.g. sync queue + a UI-triggered check) share one
    // HTTP request instead of racing duplicate refreshes.
    (:background)
    var pendingCallbacks = [] as Array<Method>;
    (:background)
    var refreshInFlight = false as Boolean;

    (:background)
    function getIdToken(callback as Method(idToken as String?, error as Number?) as Void) as Void {
        var cache = Store.getAuthCache();
        var cachedIdToken = cache.get("idToken") as String;
        var cachedExpiresAtMillis = cache.get("expiresAtMillis") as Numeric;
        if (cachedIdToken.length() > 0 && (cachedExpiresAtMillis - TimeUtil.nowEpochMillis()) > TOKEN_EXPIRY_SKEW_MILLIS) {
            callback.invoke(cachedIdToken, null);
            return;
        }

        pendingCallbacks.add(callback);
        if (refreshInFlight) {
            return;
        }
        refreshInFlight = true;
        requestRefresh();
    }

    // Forces the next getIdToken() call to refresh instead of serving the
    // cache, used for exactly one retry after a 401 from Firestore. Keeps
    // the refresh token and user id -- only the expiry is invalidated.
    (:background)
    function invalidateIdToken() as Void {
        var cache = Store.getAuthCache();
        Store.setAuthCache(cache.get("idToken") as String, 0, cache.get("userId") as String, cache.get("refreshToken") as String);
    }

    (:background)
    function getUserId() as String {
        return Store.getAuthCache().get("userId") as String;
    }

    (:background)
    function requestRefresh() as Void {
        var refreshToken = Config.getRefreshToken();
        if (refreshToken.length() == 0) {
            // No web request goes out on this path, so onRefreshResponse
            // never runs to clear the flag -- without this, every later
            // getIdToken() call would queue forever and never retry.
            refreshInFlight = false;
            finishPending(null, AUTH_INVALID);
            return;
        }

        var params = {
            "grant_type" => "refresh_token",
            "refresh_token" => refreshToken
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => "application/x-www-form-urlencoded",
                "X-Android-Package" => ANDROID_PACKAGE,
                "X-Android-Cert" => ANDROID_CERT
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        // method(:sym) only binds to an implicit self on class instances;
        // a module has no self, so the Method must be constructed explicitly.
        Communications.makeWebRequest(TOKEN_URL, params, options, new Lang.Method(TokenClient, :onRefreshResponse));
    }

    (:background)
    function onRefreshResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        refreshInFlight = false;

        if (responseCode == 200 && data instanceof Dictionary) {
            var idToken = data.get("id_token");
            var refreshToken = data.get("refresh_token");
            var userId = data.get("user_id");
            if (idToken instanceof String && refreshToken instanceof String && userId instanceof String) {
                var expiresAtMillis = TimeUtil.nowEpochMillis() + (parseExpiresInSeconds(data.get("expires_in")) * 1000L);
                Store.setAuthCache(idToken, expiresAtMillis, userId, refreshToken);
                finishPending(idToken, null);
                return;
            }
        }

        if (responseCode == 400 || responseCode == 401) {
            finishPending(null, AUTH_INVALID);
            return;
        }
        finishPending(null, RETRYABLE);
    }

    // expires_in comes back as a numeric string ("3600") per the securetoken
    // API; fall back to the default on anything malformed rather than
    // throwing out of a network callback.
    (:background)
    function parseExpiresInSeconds(value as Object?) as Long {
        if (value instanceof String) {
            var parsed = value.toNumber();
            if (parsed != null) {
                return parsed as Long;
            }
        } else if (value instanceof Number or value instanceof Long) {
            return value as Long;
        }
        return DEFAULT_EXPIRES_IN_SECONDS;
    }

    (:background)
    function finishPending(idToken as String?, error as Number?) as Void {
        var callbacks = pendingCallbacks;
        pendingCallbacks = [];
        for (var i = 0; i < callbacks.size(); i++) {
            callbacks[i].invoke(idToken, error);
        }
    }

}
