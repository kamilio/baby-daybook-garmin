import Toybox.Lang;
import Toybox.Test;

// Exercises the pure register/skip decision behind
// BabyDaybookApp.registerBackgroundSync() without touching the real
// Background.registerForTemporalEvent() API. Not shipped in release builds
// (unit-test annotated).
module BabyDaybookAppTest {

    (:test)
    function testShouldRegisterWhenNeverRegistered(logger as Test.Logger) as Boolean {
        var app = new BabyDaybookApp();
        return app.shouldRegisterSyncInterval(15, -1, false);
    }

    (:test)
    function testShouldRegisterWhenIntervalChanged(logger as Test.Logger) as Boolean {
        var app = new BabyDaybookApp();
        return app.shouldRegisterSyncInterval(30, 15, true);
    }

    (:test)
    function testSkipsWhenAlreadyRegisteredForSameInterval(logger as Test.Logger) as Boolean {
        var app = new BabyDaybookApp();
        return !app.shouldRegisterSyncInterval(15, 15, true);
    }

    (:test)
    function testRegistersWhenIntervalMatchesButPlatformRegistrationMissing(logger as Test.Logger) as Boolean {
        var app = new BabyDaybookApp();
        // A stale Store value from a prior install with the registration
        // itself since cleared (e.g. deleteTemporalEventRegistration or a
        // fresh app data reset) must not be trusted on its own.
        return app.shouldRegisterSyncInterval(15, 15, false);
    }

}
