import Toybox.Lang;

// Release identity shared by the watch UI and relay diagnostics. Keep these
// values aligned with the version submitted to Garmin's developer portal.
module BuildInfo {
    const APP_VERSION = "0.23.5-beta.1";
    const INTERNAL_VERSION = 28;

    function displayVersion() as String {
        return "v" + APP_VERSION + " (" + INTERNAL_VERSION.toString() + ")";
    }

    function relayClient(refreshToken as String) as Dictionary {
        var end = refreshToken.length();
        if (end > 8) { end = 8; }
        return {
            "appVersion" => APP_VERSION,
            "internalVersion" => INTERNAL_VERSION,
            "authPrefix" => refreshToken.substring(0, end)
        };
    }
}
