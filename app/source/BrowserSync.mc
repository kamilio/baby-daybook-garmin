import Toybox.Authentication;
import Toybox.Lang;

// Server-free sync transport. Garmin cannot carry Firestore's long
// Authorization header (-200), so a Connect IQ notification opens the
// provisioning page and lets the phone browser perform the authenticated
// commit. Only compact event data is placed in the notification URL.
module BrowserSync {
    const SYNC_URL = "https://kamilio.github.io/baby-daybook-garmin/";
    const RESULT_URL = "connectiq://oauth";
    const MAX_BATCH_SIZE = 10;

    function request() as Boolean {
        var payload = buildPayload(Store.getSyncQueue());
        if (payload.length() == 0) {
            return false;
        }
        Store.setSyncDiagnostic("phone_notification", 0);
        Authentication.makeOAuthRequest(
            SYNC_URL,
            { "sync" => "1", "events" => payload },
            RESULT_URL,
            Authentication.OAUTH_RESULT_TYPE_URL,
            { "acked" => "acked", "syncError" => "syncError" }
        );
        return true;
    }

    function buildPayload(queue as Array) as String {
        var result = "";
        var count = queue.size();
        if (count > MAX_BATCH_SIZE) { count = MAX_BATCH_SIZE; }
        for (var i = 0; i < count; i++) {
            var event = queue[i] as Dictionary;
            if (i > 0) { result += "~"; }
            result += field(event, "id") + "|";
            result += field(event, "type") + "|";
            result += field(event, "startMillis") + "|";
            result += field(event, "volume") + "|";
            result += ((event.get("pee") == true) ? "1" : "0") + "|";
            result += ((event.get("poo") == true) ? "1" : "0");
        }
        return result;
    }

    function field(event as Dictionary, key as String) as String {
        var value = event.get(key);
        return (value == null) ? "" : value.toString();
    }
}
