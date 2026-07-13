import Toybox.Application.Storage;
import Toybox.Authentication;
import Toybox.Lang;
import Toybox.WatchUi;

// Uses Connect IQ's OAuth hand-off as a secure provisioning transport. The
// GitHub Pages form never submits credentials to a server; it redirects the
// in-app browser to connectiq://oauth, which Garmin intercepts and returns to
// this callback.
module AuthProvisioner {

    const PROVISIONING_URL = "https://kamilio.github.io/baby-daybook-garmin/";
    const RESULT_URL = "connectiq://oauth";
    const RESULT_REFRESH_TOKEN = "refreshToken";
    const RESULT_BABY_UID = "babyUid";

    var registered = false;
    var requested = false;

    function initialize() as Void {
        if (!registered) {
            Authentication.registerForOAuthMessages(new Lang.Method(AuthProvisioner, :onOAuthMessage));
            registered = true;
        }
    }

    function requestIfNeeded() as Void {
        if (requested || (Config.getRefreshToken().length() > 0 && Config.getBabyUid().length() > 0)) {
            return;
        }
        issueRequest();
    }

    function issueRequest() as Void {
        requested = true;
        Authentication.makeOAuthRequest(
            PROVISIONING_URL,
            { "garminOAuth" => "1" },
            RESULT_URL,
            Authentication.OAUTH_RESULT_TYPE_URL,
            {
                "refreshToken" => RESULT_REFRESH_TOKEN,
                "babyUid" => RESULT_BABY_UID
            }
        );
        Store.setSyncDiagnostic("oauth_notification", 0);
    }

    // User-initiated retries must always create a fresh Connect IQ Mobile
    // notification. The platform does not open the phone browser directly.
    function requestNow() as Void {
        requested = false;
        issueRequest();
    }

    function onOAuthMessage(message as Authentication.OAuthMessage) as Void {
        var data = message.data;
        if (data instanceof Dictionary) {
            var acked = data.get("acked");
            if (acked instanceof String && acked.length() > 0) {
                SyncQueue.acknowledgeBrowserSync(acked);
                WatchUi.requestUpdate();
                return;
            }
            var syncError = data.get("syncError");
            if (syncError instanceof String) {
                Store.setSyncDiagnostic("phone_sync_error", 0);
                Store.setQueueLastError(true);
                WatchUi.requestUpdate();
                return;
            }
        }
        if (applyCredentials((data instanceof Dictionary) ? data : null)) {
            Store.setQueueNeedsToken(false);
            Store.setQueueLastError(false);
            WatchUi.requestUpdate();
        } else {
            requested = false;
            Store.setSyncDiagnostic("oauth_failed", 0);
        }
    }

    // Kept separate from the platform callback so credential validation and
    // persistence can be unit-tested without constructing an OAuthMessage.
    function applyCredentials(data as Dictionary?) as Boolean {
        if (data == null) {
            return false;
        }

        var refreshToken = data.get(RESULT_REFRESH_TOKEN);
        var babyUid = data.get(RESULT_BABY_UID);
        if (!(refreshToken instanceof String) || refreshToken.length() == 0 ||
            !(babyUid instanceof String) || babyUid.length() == 0) {
            return false;
        }

        Store.setAuthCache("", 0, "", refreshToken);
        Storage.setValue("provisionedBabyUid", babyUid);
        requested = false;
        return true;
    }
}
