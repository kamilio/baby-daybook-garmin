import Toybox.Communications;
import Toybox.Lang;

// Primary sync transport. The Firebase refresh token travels in the HTTPS
// request body because Garmin rejects Firestore's long Authorization header.
// The Fly relay performs the authenticated Firestore commit and returns only
// acknowledged event IDs plus Firebase's rotated refresh token.
(:background)
module RelaySync {
    const SYNC_URL = "https://baby-daybook-kjopek.fly.dev/garmin/sync";
    const MAX_BATCH_SIZE = 10;
    (:background)
    var syncing = false;

    (:background)
    function request() as Boolean {
        if (syncing) { return false; }
        var events = batch(Store.getSyncQueue());
        if (events.size() == 0) {
            Store.setSyncDiagnostic("relay_empty", 0);
            return false;
        }
        syncing = true;
        Store.setQueueLastError(false);
        Store.setSyncDiagnostic("relay_uploading", 0);
        var body = {
            "refreshToken" => Config.getRefreshToken(),
            "babyUid" => Config.getBabyUid(),
            "events" => events
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(SYNC_URL, body, options, new Lang.Method(RelaySync, :onResponse));
        return true;
    }

    (:background)
    function isSyncing() as Boolean { return syncing; }

    (:background)
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
            result.add(event);
        }
        return result;
    }

    (:background)
    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (code >= 200 && code < 300 && data instanceof Dictionary) {
            var acked = data.get("acked");
            var refreshToken = data.get("refreshToken");
            var userId = data.get("userId");
            if (acked instanceof Array && refreshToken instanceof String && userId instanceof String) {
                Store.setAuthCache("", 0, userId, refreshToken);
                SyncQueue.acknowledgeRelaySync(acked);
                syncing = false;
                if (SyncQueue.pendingCount() > 0) {
                    request();
                } else {
                    SyncQueue.notifyChanged();
                }
                return;
            }
        }
        syncing = false;
        Store.setQueueLastError(true);
        Store.setQueueNeedsToken(code == 401);
        Store.setSyncDiagnostic("relay_failed", code);
        SyncQueue.notifyChanged();
    }
}
