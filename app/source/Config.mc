import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;

// Typed access to build-time properties (resources/properties.xml), with a
// runtime Application.Storage override for values Firebase rotates after
// first launch (currently just the refresh token, cached under "authCache"
// by TokenClient — Storage wins whenever a rotated value is present).
module Config {

    const SYNC_INTERVAL_MINUTES_FLOOR = 5;

    function getRefreshToken() as String {
        var authCache = Storage.getValue("authCache");
        if (authCache instanceof Dictionary) {
            var stored = authCache.get("refreshToken");
            if (stored instanceof String && stored.length() > 0) {
                return stored;
            }
        }
        var baked = Properties.getValue("refreshToken");
        return (baked instanceof String) ? baked : "";
    }

    function getBabyUid() as String {
        var value = Properties.getValue("babyUid");
        return (value instanceof String) ? value : "";
    }

    // Clamped to the Connect IQ temporal-event floor; smaller values would
    // throw InvalidBackgroundTimeException when registering the background
    // event.
    function getSyncIntervalMinutes() as Number {
        var value = Properties.getValue("syncIntervalMinutes");
        var minutes = (value instanceof Number) ? value : 15;
        return clampSyncIntervalMinutes(minutes);
    }

    // Split out from getSyncIntervalMinutes() so the floor clamp is
    // directly testable without baking an invalid properties.xml default.
    function clampSyncIntervalMinutes(minutes as Number) as Number {
        return (minutes < SYNC_INTERVAL_MINUTES_FLOOR) ? SYNC_INTERVAL_MINUTES_FLOOR : minutes;
    }

    function getDefaultBottleMl() as Number {
        var value = Properties.getValue("defaultBottleMl");
        return (value instanceof Number) ? value : 120;
    }

    function getBottleStepMl() as Number {
        var value = Properties.getValue("bottleStepMl");
        return (value instanceof Number) ? value : 10;
    }

    function getBottleMinMl() as Number {
        var value = Properties.getValue("bottleMinMl");
        return (value instanceof Number) ? value : 30;
    }

    function getBottleMaxMl() as Number {
        var value = Properties.getValue("bottleMaxMl");
        return (value instanceof Number) ? value : 300;
    }

}
