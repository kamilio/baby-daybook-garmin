import Toybox.Application.Storage;
import Toybox.Lang;

// Typed access to the app's persistent state (Toybox.Application.Storage).
// Storage is shared foreground/background on CIQ >= 3.2 -- the background
// sync service reads and writes these same keys -- so no accessor here
// caches a value in a module variable; every read goes straight to Storage
// so the queue accessor (and everything else) always sees the latest
// last-writer-wins state. Every read also guards against null/malformed
// shapes, since Storage survives app updates and the on-disk shape may
// drift between builds. No UI imports: this module must stay safe to pull
// into the (:background) build.
(:background)
module Store {

    const KEY_AUTH_CACHE = "authCache";
    const KEY_SYNC_QUEUE = "syncQueue";
    const KEY_QUEUE_STATUS = "queueStatus";
    const KEY_LAST_EVENT_MILLIS = "lastEventMillis";
    const KEY_LAST_BOTTLE_ML = "lastBottleMl";
    const KEY_LAST_ACTION = "lastAction";
    const KEY_REGISTERED_SYNC_INTERVAL_MINUTES = "registeredSyncIntervalMinutes";

    const ACTION_BOTTLE = "bottle";
    const ACTION_WET = "wet";
    const ACTION_DIRTY = "dirty";

    // epoch-millisecond fields (authCache.expiresAtMillis, lastEventMillis
    // entries) exceed the 32-bit Number range, so Storage may hand back
    // either a Number or a Long depending on how the value was written.
    (:background)
    function isEpochMillis(value as Object) as Boolean {
        return (value instanceof Number) || (value instanceof Long);
    }

    // --- authCache: { idToken, expiresAtMillis, userId, refreshToken } ---

    (:background)
    function getAuthCache() as Dictionary {
        var raw = Storage.getValue(KEY_AUTH_CACHE);
        var idToken = "";
        var expiresAtMillis = 0;
        var userId = "";
        var refreshToken = "";
        if (raw instanceof Dictionary) {
            var storedIdToken = raw.get("idToken");
            if (storedIdToken instanceof String) {
                idToken = storedIdToken;
            }
            var storedExpiresAtMillis = raw.get("expiresAtMillis");
            if (isEpochMillis(storedExpiresAtMillis)) {
                expiresAtMillis = storedExpiresAtMillis;
            }
            var storedUserId = raw.get("userId");
            if (storedUserId instanceof String) {
                userId = storedUserId;
            }
            var storedRefreshToken = raw.get("refreshToken");
            if (storedRefreshToken instanceof String) {
                refreshToken = storedRefreshToken;
            }
        }
        return {
            "idToken" => idToken,
            "expiresAtMillis" => expiresAtMillis,
            "userId" => userId,
            "refreshToken" => refreshToken
        };
    }

    (:background)
    function setAuthCache(idToken as String, expiresAtMillis as Numeric, userId as String, refreshToken as String) as Void {
        Storage.setValue(KEY_AUTH_CACHE, {
            "idToken" => idToken,
            "expiresAtMillis" => expiresAtMillis,
            "userId" => userId,
            "refreshToken" => refreshToken
        });
    }

    // --- syncQueue: array of pending event dictionaries ---

    (:background)
    function getSyncQueue() as Array {
        var raw = Storage.getValue(KEY_SYNC_QUEUE);
        return (raw instanceof Array) ? raw : [];
    }

    (:background)
    function setSyncQueue(queue as Array) as Void {
        Storage.setValue(KEY_SYNC_QUEUE, queue);
    }

    // --- queueStatus: { needsToken, lastError } -- set by SyncQueue, read by
    // the UI. Persisted (not held in module memory) because the background
    // sync process can be the one that discovers a dead refresh token or a
    // permanent rejection, and the foreground UI needs to see that after the
    // process that set it has already exited. ---

    (:background)
    function getQueueNeedsToken() as Boolean {
        var value = getQueueStatusField("needsToken");
        return (value instanceof Boolean) ? value : false;
    }

    (:background)
    function setQueueNeedsToken(value as Boolean) as Void {
        setQueueStatusField("needsToken", value);
    }

    (:background)
    function getQueueLastError() as Boolean {
        var value = getQueueStatusField("lastError");
        return (value instanceof Boolean) ? value : false;
    }

    (:background)
    function setQueueLastError(value as Boolean) as Void {
        setQueueStatusField("lastError", value);
    }

    (:background)
    function getQueueStatusField(field as String) as Object? {
        var raw = Storage.getValue(KEY_QUEUE_STATUS);
        return (raw instanceof Dictionary) ? raw.get(field) : null;
    }

    (:background)
    function setQueueStatusField(field as String, value as Boolean) as Void {
        var raw = Storage.getValue(KEY_QUEUE_STATUS);
        var updated = (raw instanceof Dictionary) ? raw : {};
        updated.put(field, value);
        Storage.setValue(KEY_QUEUE_STATUS, updated);
    }

    // --- lastEventMillis: dictionary keyed by "bottle" / "wet" / "dirty" ---

    (:background)
    function getLastEventMillis(action as String) as Numeric? {
        var raw = Storage.getValue(KEY_LAST_EVENT_MILLIS);
        if (raw instanceof Dictionary) {
            var value = raw.get(action);
            if (isEpochMillis(value)) {
                return value;
            }
        }
        return null;
    }

    // Normalized view of all three actions in one Storage read, for
    // callers (glance, complications) that need every action at once.
    (:background)
    function getAllLastEventMillis() as Dictionary {
        var raw = Storage.getValue(KEY_LAST_EVENT_MILLIS);
        var actions = [ACTION_BOTTLE, ACTION_WET, ACTION_DIRTY];
        var result = {};
        for (var i = 0; i < actions.size(); i++) {
            var action = actions[i];
            var value = (raw instanceof Dictionary) ? raw.get(action) : null;
            result.put(action, isEpochMillis(value) ? value : null);
        }
        return result;
    }

    (:background)
    function setLastEventMillis(action as String, millis as Numeric) as Void {
        var raw = Storage.getValue(KEY_LAST_EVENT_MILLIS);
        var updated = (raw instanceof Dictionary) ? raw : {};
        updated.put(action, millis);
        Storage.setValue(KEY_LAST_EVENT_MILLIS, updated);
    }

    // --- lastBottleMl: number or null ---

    (:background)
    function getLastBottleMl() as Number? {
        var value = Storage.getValue(KEY_LAST_BOTTLE_ML);
        return (value instanceof Number) ? value : null;
    }

    (:background)
    function setLastBottleMl(ml as Number?) as Void {
        Storage.setValue(KEY_LAST_BOTTLE_ML, ml);
    }

    // --- lastAction: home screen highlight for button navigation ---

    (:background)
    function getLastAction() as String? {
        var value = Storage.getValue(KEY_LAST_ACTION);
        return (value instanceof String) ? value : null;
    }

    (:background)
    function setLastAction(action as String) as Void {
        Storage.setValue(KEY_LAST_ACTION, action);
    }

    // --- registeredSyncIntervalMinutes: the interval last passed to
    // Background.registerForTemporalEvent(), so BabyDaybookApp can tell
    // "config changed, must re-register" apart from "already registered
    // for this interval, skip" without re-deriving it from the opaque
    // Moment Background.getTemporalEventRegisteredTime() returns. -1
    // default never matches a real interval, so the first app start always
    // registers. ---

    (:background)
    function getRegisteredSyncIntervalMinutes() as Number {
        var value = Storage.getValue(KEY_REGISTERED_SYNC_INTERVAL_MINUTES);
        return (value instanceof Number) ? value : -1;
    }

    (:background)
    function setRegisteredSyncIntervalMinutes(minutes as Number) as Void {
        Storage.setValue(KEY_REGISTERED_SYNC_INTERVAL_MINUTES, minutes);
    }

}
