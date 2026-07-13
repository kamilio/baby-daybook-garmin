import Toybox.Application.Properties;
import Toybox.Lang;

// Connect IQ settings are a dependable cross-phone handoff: finish setup in
// a browser, paste its callback URL into the app setting, then sync/launch.
module SettingsProvisioner {
    function applyFromProperties() as Boolean {
        var value = Properties.getValue("setupCallbackUrl");
        if (!(value instanceof String) || value.length() == 0) {
            return false;
        }
        var data = parseCallbackUrl(value);
        if (!AuthProvisioner.applyCredentials(data)) {
            return false;
        }
        Properties.setValue("setupCallbackUrl", "");
        Store.setQueueNeedsToken(false);
        Store.setQueueLastError(false);
        return true;
    }

    function parseCallbackUrl(url as String) as Dictionary? {
        var question = url.find("?");
        if (question == null || question >= url.length() - 1) {
            return null;
        }
        var data = {};
        var remaining = url.substring(question + 1, url.length());
        while (remaining.length() > 0) {
            var amp = remaining.find("&");
            var end = (amp == null) ? remaining.length() : amp;
            var pair = remaining.substring(0, end);
            var equals = pair.find("=");
            if (equals != null) {
                var key = pair.substring(0, equals);
                var value = pair.substring(equals + 1, pair.length());
                if (key.equals("refreshToken") || key.equals("babyUid")) {
                    data.put(key, value);
                }
            }
            if (amp == null) { break; }
            remaining = remaining.substring(amp + 1, remaining.length());
        }
        return data;
    }
}
