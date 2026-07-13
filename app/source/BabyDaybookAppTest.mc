import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Exercises the pure register/skip decision behind
// BabyDaybookApp.registerBackgroundSync() without touching the real
// Background.registerForTemporalEvent() API, plus getInitialView()'s
// complication-launch routing (launchedFromComplication is a plain public
// instance var, so tests set it directly rather than going through onStart()
// and its Dictionary-shaped state argument). Not shipped in release builds
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

    (:test)
    function testGetInitialViewRoutesWetComplicationToExitingSuccessView(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var app = new BabyDaybookApp();
        app.launchedFromComplication = ComplicationsPublisher.ID_WET;
        var result = app.getInitialView();
        var view = result[0] as SuccessView;
        var ok = (view instanceof SuccessView) && view.exitOnDismiss && view.label.equals("Wet diaper");
        Storage.clearValues();
        return ok;
    }

    (:test)
    function testGetInitialViewRoutesDirtyComplicationToExitingSuccessView(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var app = new BabyDaybookApp();
        app.launchedFromComplication = ComplicationsPublisher.ID_DIRTY;
        var result = app.getInitialView();
        var view = result[0] as SuccessView;
        var ok = (view instanceof SuccessView) && view.exitOnDismiss && view.label.equals("Dirty diaper");
        Storage.clearValues();
        return ok;
    }

    (:test)
    function testGetInitialViewRoutesBottleComplicationToExitOnConfirmPicker(logger as Test.Logger) as Boolean {
        var app = new BabyDaybookApp();
        app.launchedFromComplication = ComplicationsPublisher.ID_BOTTLE;
        var result = app.getInitialView();
        var view = result[0] as BottleAmountPicker;
        return (view instanceof BottleAmountPicker) && view.exitOnConfirm;
    }

    (:test)
    function testGetInitialViewFallsBackToNativeMenuWithoutComplicationLaunch(logger as Test.Logger) as Boolean {
        var app = new BabyDaybookApp();
        app.launchedFromComplication = null;
        var result = app.getInitialView();
        return result[0] instanceof WatchUi.Menu2;
    }

}
