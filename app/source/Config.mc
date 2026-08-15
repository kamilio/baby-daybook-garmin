import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;

// Typed access to build-time properties (resources/properties.xml), with a
// runtime Application.Storage override for values Firebase rotates after
// first launch (currently just the refresh token, cached under "authCache"
// by RelaySync — Storage wins whenever a rotated value is present). No UI
// imports: this module stays lightweight for network and glance callers.
module Config {

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
        var provisioned = Storage.getValue("provisionedBabyUid");
        if (provisioned instanceof String && provisioned.length() > 0) {
            return provisioned;
        }
        var value = Properties.getValue("babyUid");
        return (value instanceof String) ? value : "";
    }

    function getDefaultBottleOz() as Numeric {
        var value = Properties.getValue("defaultBottleOz");
        return (value instanceof Number) ? value : 4;
    }

    function getBottleMinOz() as Numeric {
        var value = Properties.getValue("bottleMinOz");
        return (value instanceof Number) ? value : 1;
    }

    function getBottleMaxOz() as Numeric {
        var value = Properties.getValue("bottleMaxOz");
        return (value instanceof Number) ? value : 10;
    }

}
