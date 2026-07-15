import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

// Exercises Store.mc edge cases: safe defaults on empty/malformed Storage,
// and round-tripping each accessor. Not shipped in release builds
// (unit-test annotated).
module StoreTest {

    (:test)
    function testAuthCacheDefaultsWhenStorageEmpty(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var cache = Store.getAuthCache();
        return cache.get("idToken").equals("")
            && cache.get("expiresAtMillis") == 0
            && cache.get("userId").equals("")
            && cache.get("refreshToken").equals("");
    }

    (:test)
    function testAuthCacheIgnoresMalformedShape(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Storage.setValue("authCache", "not-a-dictionary");
        var cache = Store.getAuthCache();
        Storage.clearValues();
        return cache.get("idToken").equals("") && cache.get("expiresAtMillis") == 0;
    }

    (:test)
    function testAuthCacheRoundTrips(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setAuthCache("id-token-1", 1720261201154l, "user-1", "refresh-1");
        var cache = Store.getAuthCache();
        Storage.clearValues();
        return cache.get("idToken").equals("id-token-1")
            && cache.get("expiresAtMillis") == 1720261201154l
            && cache.get("userId").equals("user-1")
            && cache.get("refreshToken").equals("refresh-1");
    }

    (:test)
    function testSyncQueueDefaultsToEmptyArray(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var queue = Store.getSyncQueue();
        return (queue instanceof Array) && queue.size() == 0;
    }

    (:test)
    function testSyncQueueIgnoresMalformedShape(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Storage.setValue("syncQueue", "not-an-array");
        var queue = Store.getSyncQueue();
        Storage.clearValues();
        return (queue instanceof Array) && queue.size() == 0;
    }

    (:test)
    function testSyncQueueRoundTrips(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setSyncQueue([{ "id" => "a" }, { "id" => "b" }]);
        var queue = Store.getSyncQueue();
        Storage.clearValues();
        return queue.size() == 2 && queue[0].get("id").equals("a");
    }

    (:test)
    function testQueueStatusFlagsDefaultToFalse(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var needsToken = Store.getQueueNeedsToken();
        var lastError = Store.getQueueLastError();
        return !needsToken && !lastError;
    }

    (:test)
    function testQueueStatusFlagsRoundTripIndependently(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setQueueNeedsToken(true);
        var needsTokenOnly = Store.getQueueNeedsToken() && !Store.getQueueLastError();
        Store.setQueueLastError(true);
        var bothSet = Store.getQueueNeedsToken() && Store.getQueueLastError();
        Storage.clearValues();
        return needsTokenOnly && bothSet;
    }

    (:test)
    function testLastSyncMillisDefaultsAndRoundTrips(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var missing = Store.getLastSyncMillis() == null;
        Store.setLastSyncMillis(1720261201154l);
        var stored = Store.getLastSyncMillis() == 1720261201154l;
        Storage.clearValues();
        return missing && stored;
    }

    (:test)
    function testSyncDiagnosticContainsOnlyOperationalFields(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setSyncDiagnostic("transport_error", -1001);
        var value = Store.getSyncDiagnostic();
        var ok = value.get("stage").equals("transport_error")
            && value.get("code") == -1001
            && ((value.get("atMillis") instanceof Long) || (value.get("atMillis") instanceof Number))
            && value.size() == 3;
        Storage.clearValues();
        return ok;
    }

    (:test)
    function testLastEventMillisReturnsNullWhenMissing(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        return Store.getLastEventMillis(Store.ACTION_BOTTLE) == null;
    }

    (:test)
    function testLastEventMillisIgnoresMalformedShape(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Storage.setValue("lastEventMillis", "not-a-dictionary");
        var value = Store.getLastEventMillis(Store.ACTION_WET);
        Storage.clearValues();
        return value == null;
    }

    (:test)
    function testLastEventMillisRoundTripsPerAction(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastEventMillis(Store.ACTION_BOTTLE, 1720261201154l);
        Store.setLastEventMillis(Store.ACTION_WET, 1720261300000l);
        var bottle = Store.getLastEventMillis(Store.ACTION_BOTTLE);
        var wet = Store.getLastEventMillis(Store.ACTION_WET);
        var dirty = Store.getLastEventMillis(Store.ACTION_DIRTY);
        Storage.clearValues();
        return bottle == 1720261201154l && wet == 1720261300000l && dirty == null;
    }

    (:test)
    function testGetAllLastEventMillisNormalizesMissingActionsToNull(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastEventMillis(Store.ACTION_DIRTY, 42l);
        var all = Store.getAllLastEventMillis();
        Storage.clearValues();
        return all.get(Store.ACTION_BOTTLE) == null
            && all.get(Store.ACTION_WET) == null
            && all.get(Store.ACTION_DIRTY) == 42l;
    }

    (:test)
    function testLastBottleOzDefaultsToNull(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        return Store.getLastBottleOz() == null;
    }

    (:test)
    function testLastBottleOzIgnoresNonNumberShape(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Storage.setValue("lastBottleOz", "4");
        var value = Store.getLastBottleOz();
        Storage.clearValues();
        return value == null;
    }

    (:test)
    function testLastBottleOzRoundTrips(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastBottleOz(4.5d);
        var value = Store.getLastBottleOz();
        Storage.clearValues();
        return value == 4.5d;
    }

    (:test)
    function testLastActionDefaultsToNull(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        return Store.getLastAction() == null;
    }

    (:test)
    function testLastActionIgnoresNonStringShape(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Storage.setValue("lastAction", 5);
        var value = Store.getLastAction();
        Storage.clearValues();
        return value == null;
    }

    (:test)
    function testLastActionRoundTrips(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastAction(Store.ACTION_WET);
        var value = Store.getLastAction();
        Storage.clearValues();
        return value.equals(Store.ACTION_WET);
    }

    (:test)
    function testRegisteredSyncIntervalMinutesDefaultsToNegativeOne(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        return Store.getRegisteredSyncIntervalMinutes() == -1;
    }

    (:test)
    function testRegisteredSyncIntervalMinutesRoundTrips(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setRegisteredSyncIntervalMinutes(15);
        var value = Store.getRegisteredSyncIntervalMinutes();
        Storage.clearValues();
        return value == 15;
    }

}
