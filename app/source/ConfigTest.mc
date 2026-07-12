import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

// Exercises Config.mc edge cases: Storage-over-Properties precedence,
// malformed Storage shapes, and the sync-interval floor clamp. Not shipped
// in release builds (unit-test annotated).
module ConfigTest {

    (:test)
    function testRefreshTokenFallsBackToBakedPropertyWhenStorageEmpty(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var token = Config.getRefreshToken();
        // properties.xml default is "", so this should be an empty string, not null/exception.
        return token.equals("");
    }

    (:test)
    function testRefreshTokenStorageOverrideWins(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Storage.setValue("authCache", { "refreshToken" => "rotated-token-123" });
        var token = Config.getRefreshToken();
        Storage.clearValues();
        return token.equals("rotated-token-123");
    }

    (:test)
    function testRefreshTokenIgnoresMalformedAuthCache(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        // authCache present but not a Dictionary at all.
        Storage.setValue("authCache", "not-a-dictionary");
        var token = Config.getRefreshToken();
        Storage.clearValues();
        return token.equals("");
    }

    (:test)
    function testRefreshTokenIgnoresNonStringStoredValue(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Storage.setValue("authCache", { "refreshToken" => 12345 });
        var token = Config.getRefreshToken();
        Storage.clearValues();
        return token.equals("");
    }

    (:test)
    function testRefreshTokenIgnoresEmptyStringOverride(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        // Storage has the key but with an empty string; must fall back to
        // the baked-in property rather than "override" with emptiness.
        Storage.setValue("authCache", { "refreshToken" => "" });
        var token = Config.getRefreshToken();
        Storage.clearValues();
        return token.equals("");
    }

    (:test)
    function testSyncIntervalFloorClampsBelowMinimum(logger as Test.Logger) as Boolean {
        return Config.clampSyncIntervalMinutes(1) == Config.SYNC_INTERVAL_MINUTES_FLOOR
            && Config.clampSyncIntervalMinutes(4) == Config.SYNC_INTERVAL_MINUTES_FLOOR
            && Config.clampSyncIntervalMinutes(0) == Config.SYNC_INTERVAL_MINUTES_FLOOR
            && Config.clampSyncIntervalMinutes(-100) == Config.SYNC_INTERVAL_MINUTES_FLOOR;
    }

    (:test)
    function testSyncIntervalFloorPassesThroughAtOrAboveMinimum(logger as Test.Logger) as Boolean {
        return Config.clampSyncIntervalMinutes(5) == 5
            && Config.clampSyncIntervalMinutes(15) == 15;
    }

    (:test)
    function testSyncIntervalUsesBakedPropertyWhenAboveFloor(logger as Test.Logger) as Boolean {
        // properties.xml bakes in 15 by default; confirm the real getter
        // (Properties-backed, not just the pure clamp helper) reflects it.
        return Config.getSyncIntervalMinutes() == 15;
    }

    (:test)
    function testBottleGettersReturnNumbersNotNull(logger as Test.Logger) as Boolean {
        return (Config.getDefaultBottleMl() instanceof Number)
            && (Config.getBottleStepMl() instanceof Number)
            && (Config.getBottleMinMl() instanceof Number)
            && (Config.getBottleMaxMl() instanceof Number);
    }

    (:test)
    function testBabyUidReturnsStringNotNull(logger as Test.Logger) as Boolean {
        return Config.getBabyUid() instanceof String;
    }

}
