import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;

// Typed access to build-time properties (resources/properties.xml), with a
// runtime Application.Storage override for values Firebase rotates after
// first launch (currently just the refresh token, cached under "authCache"
// by TokenClient — Storage wins whenever a rotated value is present). No UI
// imports: this module must stay safe to pull into the (:background)
// build, where the background sync service reads the refresh token,
// baby uid, and sync interval directly.
(:background)
module Config {

    const SYNC_INTERVAL_MINUTES_FLOOR = 5;

    (:background)
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

    (:background)
    function getBabyUid() as String {
        var provisioned = Storage.getValue("provisionedBabyUid");
        if (provisioned instanceof String && provisioned.length() > 0) {
            return provisioned;
        }
        var value = Properties.getValue("babyUid");
        return (value instanceof String) ? value : "";
    }

    // Clamped to the Connect IQ temporal-event floor; smaller values would
    // throw InvalidBackgroundTimeException when registering the background
    // event.
    (:background)
    function getSyncIntervalMinutes() as Number {
        var value = Properties.getValue("syncIntervalMinutes");
        var minutes = (value instanceof Number) ? value : 15;
        return clampSyncIntervalMinutes(minutes);
    }

    // Split out from getSyncIntervalMinutes() so the floor clamp is
    // directly testable without baking an invalid properties.xml default.
    (:background)
    function clampSyncIntervalMinutes(minutes as Number) as Number {
        return (minutes < SYNC_INTERVAL_MINUTES_FLOOR) ? SYNC_INTERVAL_MINUTES_FLOOR : minutes;
    }

    (:background)
    function getDefaultBottleMl() as Number {
        var value = Properties.getValue("defaultBottleMl");
        return (value instanceof Number) ? value : 120;
    }

    (:background)
    function getBottleStepMl() as Number {
        var value = Properties.getValue("bottleStepMl");
        return (value instanceof Number) ? value : 10;
    }

    (:background)
    function getBottleMinMl() as Number {
        var value = Properties.getValue("bottleMinMl");
        return (value instanceof Number) ? value : 30;
    }

    (:background)
    function getBottleMaxMl() as Number {
        var value = Properties.getValue("bottleMaxMl");
        return (value instanceof Number) ? value : 300;
    }

}
