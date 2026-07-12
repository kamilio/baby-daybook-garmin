import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

// Exercises the parts of TokenClient.mc that don't require a live network
// round trip: cache-hit short-circuiting, invalidateIdToken(), getUserId(),
// and the expires_in parsing helper. The refresh-request path itself
// (Communications.makeWebRequest) is exercised in the simulator, not here.
// Not shipped in release builds (unit-test annotated).
module TokenClientTest {

    var capturedIdToken as String? = null;
    var capturedError as Number? = null;

    function resetCapture() as Void {
        capturedIdToken = null;
        capturedError = null;
    }

    function captureCallback(idToken as String?, error as Number?) as Void {
        capturedIdToken = idToken;
        capturedError = error;
    }

    (:test)
    function testGetIdTokenReturnsCachedTokenWhenFarFromExpiry(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        resetCapture();
        var farFuture = (Time.now().value() as Long) * 1000L + 3600000L;
        Store.setAuthCache("cached-id-token", farFuture, "user-1", "refresh-1");
        TokenClient.getIdToken(new Lang.Method(TokenClientTest, :captureCallback));
        Storage.clearValues();
        return capturedIdToken != null && capturedIdToken.equals("cached-id-token") && capturedError == null;
    }

    (:test)
    function testInvalidateIdTokenKeepsRefreshTokenAndUserId(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var farFuture = (Time.now().value() as Long) * 1000L + 3600000L;
        Store.setAuthCache("cached-id-token", farFuture, "user-1", "refresh-1");
        TokenClient.invalidateIdToken();
        var cache = Store.getAuthCache();
        Storage.clearValues();
        return cache.get("expiresAtMillis") == 0
            && cache.get("idToken").equals("cached-id-token")
            && cache.get("userId").equals("user-1")
            && cache.get("refreshToken").equals("refresh-1");
    }

    (:test)
    function testGetUserIdReturnsStoredValue(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setAuthCache("id-token", 0, "user-42", "refresh-token");
        var userId = TokenClient.getUserId();
        Storage.clearValues();
        return userId.equals("user-42");
    }

    (:test)
    function testGetUserIdDefaultsToEmptyStringWhenUnset(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var userId = TokenClient.getUserId();
        return userId.equals("");
    }

    (:test)
    function testGetIdTokenReportsAuthInvalidOnRepeatedCallsWithNoRefreshToken(logger as Test.Logger) as Boolean {
        // properties.xml bakes in "" for refreshToken and Storage is clear,
        // so Config.getRefreshToken() returns "" and requestRefresh() takes
        // the no-web-request branch. Calling getIdToken() twice in a row
        // guards against refreshInFlight getting stuck true on that branch
        // -- if it did, this second call would queue silently and the
        // capture below would still hold the first call's result.
        Storage.clearValues();
        resetCapture();
        TokenClient.getIdToken(new Lang.Method(TokenClientTest, :captureCallback));
        var firstOk = capturedIdToken == null && capturedError == TokenClient.AUTH_INVALID;

        resetCapture();
        TokenClient.getIdToken(new Lang.Method(TokenClientTest, :captureCallback));
        var secondOk = capturedIdToken == null && capturedError == TokenClient.AUTH_INVALID;

        Storage.clearValues();
        return firstOk && secondOk;
    }

    (:test)
    function testParseExpiresInSecondsParsesStringValue(logger as Test.Logger) as Boolean {
        return TokenClient.parseExpiresInSeconds("3600") == 3600l;
    }

    (:test)
    function testParseExpiresInSecondsParsesNumberValue(logger as Test.Logger) as Boolean {
        return TokenClient.parseExpiresInSeconds(1800) == 1800l;
    }

    (:test)
    function testParseExpiresInSecondsFallsBackOnMalformedValue(logger as Test.Logger) as Boolean {
        return TokenClient.parseExpiresInSeconds("not-a-number") == TokenClient.DEFAULT_EXPIRES_IN_SECONDS
            && TokenClient.parseExpiresInSeconds(null) == TokenClient.DEFAULT_EXPIRES_IN_SECONDS;
    }

}
