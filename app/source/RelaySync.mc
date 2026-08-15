import Toybox.Communications;
import Toybox.Lang;

// Primary sync transport. The Firebase refresh token travels in the HTTPS
// request body because Garmin rejects Firestore's long Authorization header.
// The Fly relay performs the authenticated Firestore commit and returns only
// acknowledged event IDs plus Firebase's rotated refresh token.
module RelaySync {
    const SYNC_URL = "https://baby-daybook-kjopek.fly.dev/garmin/sync";
    const MAX_BATCH_SIZE = 10;
    var syncing = false;
    var activeBatch = [];
    var onComplete as Lang.Method?;

    function setOnComplete(callback as Lang.Method?) as Void { onComplete = callback; }

    function notifyComplete(success as Boolean) as Void {
        var callback = onComplete;
        onComplete = null;
        if (callback != null) { callback.invoke(success); }
    }

    function request() as Boolean {
        if (syncing) { return false; }
        var events = batch(Store.getSyncQueue());
        activeBatch = events;
        syncing = true;
        Store.setQueueLastError(false);
        Store.setSyncDiagnostic("relay_uploading", 0);
        // Make manual Sync immediately repaint as loading, including a
        // pull-only sync with no queued uploads.
        SyncQueue.notifyChanged();
        var refreshToken = Config.getRefreshToken();
        var body = {
            "refreshToken" => refreshToken,
            "babyUid" => Config.getBabyUid(),
            "events" => events,
            "client" => BuildInfo.relayClient(refreshToken)
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(SYNC_URL, body, options, new Lang.Method(RelaySync, :onResponse));
        return true;
    }

    function isSyncing() as Boolean { return syncing; }

    function batch(queue as Array) as Array {
        var result = [];
        var count = queue.size();
        if (count > MAX_BATCH_SIZE) { count = MAX_BATCH_SIZE; }
        for (var i = 0; i < count; i++) {
            var source = queue[i] as Dictionary;
            var event = {
                "id" => source.get("id"),
                "type" => source.get("type"),
                "startMillis" => source.get("startMillis")
            };
            if (source.get("volume") != null) { event.put("volume", source.get("volume")); }
            if (source.get("pee") != null) { event.put("pee", source.get("pee")); }
            if (source.get("poo") != null) { event.put("poo", source.get("poo")); }
            if (source.get("bottleGroupUid") != null) { event.put("bottleGroupUid", source.get("bottleGroupUid")); }
            if (source.get("milkType") != null) { event.put("milkType", source.get("milkType")); }
            if (source.get("activityId") != null) { event.put("activityId", source.get("activityId")); }
            if (source.get("endMillis") != null) { event.put("endMillis", source.get("endMillis")); }
            if (source.get("duration") != null) { event.put("duration", source.get("duration")); }
            if (source.get("inProgress") != null) { event.put("inProgress", source.get("inProgress")); }
            result.add(event);
        }
        return result;
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (code >= 200 && code < 300 && data instanceof Dictionary) {
            var acked = data.get("acked");
            var refreshToken = data.get("refreshToken");
            var userId = data.get("userId");
            if (acked instanceof Array && refreshToken instanceof String && userId instanceof String) {
                Store.setAuthCache("", 0, userId, refreshToken);
                applyBabyProfile(data.get("baby"));
                applyBottleGroups(data.get("bottleGroups"));
                if (data.hasKey("activeSleep")) { applyActiveSleep(data.get("activeSleep")); }
                applyLatest(data.get("latest"));
                SyncQueue.acknowledgeRelaySync(acked);
                activeBatch = [];
                syncing = false;
                notifyComplete(true);
                if (SyncQueue.pendingCount() > 0) {
                    request();
                } else {
                    SyncQueue.notifyChanged();
                }
                return;
            }
        }
        syncing = false;
        SyncQueue.markBatchFailed(activeBatch);
        activeBatch = [];
        Store.setQueueLastError(true);
        Store.setQueueNeedsToken(code == 401);
        Store.setSyncDiagnostic("relay_failed", code);
        SyncQueue.notifyChanged();
        notifyComplete(false);
    }

    function applyLatest(value as Object?) as Boolean {
        if (!(value instanceof Dictionary) ||
            !value.hasKey("bottle") || !value.hasKey("wet") || !value.hasKey("dirty")) {
            return false;
        }
        var bottle = value.get("bottle");
        var wet = value.get("wet");
        var dirty = value.get("dirty");
        if (!isLatestValue(bottle) || !isLatestValue(wet) || !isLatestValue(dirty)) {
            return false;
        }
        Store.replaceAllLastEventMillis(
            bottle as Numeric?,
            wet as Numeric?,
            dirty as Numeric?
        );
        return true;
    }

    function isLatestValue(value as Object?) as Boolean {
        return value == null || value instanceof Number || value instanceof Long;
    }

    function applyBottleGroups(value as Object?) as Boolean {
        if (!(value instanceof Array) || value.size() == 0) { return false; }
        var groups = [];
        for (var i = 0; i < value.size(); i++) {
            var group = value[i];
            if (!(group instanceof Dictionary) || !(group.get("uid") instanceof String) ||
                !(group.get("title") instanceof String) || !(group.get("messageKey") instanceof String)) {
                return false;
            }
            groups.add({
                "uid" => group.get("uid"),
                "title" => group.get("title"),
                "messageKey" => group.get("messageKey")
            });
        }
        Store.setBottleGroups(groups);
        return true;
    }

    function applyActiveSleep(value as Object?) as Boolean {
        if (value == null) {
            Store.setActiveSleep(null);
            return true;
        }
        if (!(value instanceof Dictionary) || !(value.get("activityId") instanceof String) ||
            !Store.isEpochMillis(value.get("startMillis"))) {
            return false;
        }
        Store.setActiveSleep({
            "activityId" => value.get("activityId"),
            "startMillis" => value.get("startMillis")
        });
        return true;
    }

    function applyBabyProfile(value as Object?) as Boolean {
        if (!(value instanceof Dictionary)) { return false; }
        var name = value.get("name");
        var birthdayMillis = value.get("birthdayMillis");
        if (!(name instanceof String) || name.length() == 0 ||
            !(birthdayMillis == null || Store.isEpochMillis(birthdayMillis))) {
            return false;
        }
        Store.setBabyProfile(name, birthdayMillis as Numeric?);
        return true;
    }
}
