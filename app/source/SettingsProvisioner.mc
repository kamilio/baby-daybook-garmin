import Toybox.Application.Properties;
import Toybox.Lang;

// Connect IQ settings are a dependable cross-phone handoff: finish setup in
// a browser, paste its callback URL into the app setting, then sync/launch.
module SettingsProvisioner {
    function hasPendingValues() as Boolean {
        var setup = Properties.getValue("setupCallbackUrl");
        var token = Properties.getValue("manualRefreshToken");
        var baby = Properties.getValue("manualBabyUid");
        return (setup instanceof String && setup.length() > 0) ||
            (token instanceof String && token.length() > 0) ||
            (baby instanceof String && baby.length() > 0);
    }

    function applyFromProperties() as Boolean {
        var value = Properties.getValue("setupCallbackUrl");
        var data = null as Dictionary?;
        if (value instanceof String && value.length() > 0) {
            data = parseSetupCode(value);
        } else {
            var refreshToken = Properties.getValue("manualRefreshToken");
            var babyUid = Properties.getValue("manualBabyUid");
            if (refreshToken instanceof String && refreshToken.length() > 0 &&
                babyUid instanceof String && babyUid.length() > 0) {
                data = { "refreshToken" => refreshToken, "babyUid" => babyUid };
            } else {
                return false;
            }
        }
        if (!AuthProvisioner.applyCredentials(data)) {
            Store.setSyncDiagnostic("settings_invalid", 400);
            return false;
        }
        Properties.setValue("setupCallbackUrl", "");
        Properties.setValue("manualRefreshToken", "");
        Properties.setValue("manualBabyUid", "");
        Store.setQueueNeedsToken(false);
        Store.setQueueLastError(false);
        Store.setSyncDiagnostic("settings_ok", 200);
        return true;
    }

    // Accept the generated callback URL, a copied query string, or the same
    // values on separate lines. This keeps setup resilient to how a phone's
    // clipboard and Connect IQ settings editor format the pasted text.
    function parseSetupCode(code as String) as Dictionary? {
        var start = 0;
        var question = code.find("?");
        if (question != null) {
            start = question + 1;
        }
        if (start >= code.length()) {
            return null;
        }
        var data = {};
        var remaining = code.substring(start, code.length());
        while (remaining.length() > 0) {
            var amp = remaining.find("&");
            var newline = remaining.find("\n");
            var carriage = remaining.find("\r");
            var end = remaining.length();
            if (amp != null && amp < end) { end = amp; }
            if (newline != null && newline < end) { end = newline; }
            if (carriage != null && carriage < end) { end = carriage; }
            var pair = remaining.substring(0, end);
            var equals = pair.find("=");
            if (equals != null) {
                var key = pair.substring(0, equals);
                var value = pair.substring(equals + 1, pair.length());
                if (key.equals("refreshToken") || key.equals("babyUid")) {
                    data.put(key, value);
                }
            }
            if (end >= remaining.length()) { break; }
            remaining = remaining.substring(end + 1, remaining.length());
        }
        return (data.get("refreshToken") instanceof String &&
                data.get("babyUid") instanceof String) ? data : null;
    }

    // Compatibility name retained for existing tests and older callers.
    function parseCallbackUrl(url as String) as Dictionary? {
        return parseSetupCode(url);
    }
}
