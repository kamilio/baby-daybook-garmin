import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class BabyDaybookApp extends Application.AppBase {

    // Set from onStart()'s state dictionary; read by getInitialView() (which
    // runs after onStart() per AppBase's documented call order) to decide
    // whether to route straight into a record/confirm flow instead of
    // HomeView. Only meaningful in the foreground app -- the background
    // process's onStart() also sets this, but never calls getInitialView().
    var launchedFromComplication as Number?;

    (:background)
    function initialize() {
        AppBase.initialize();
    }

    // Runs in both the foreground app and every background wake (the
    // background process instantiates AppBase too, calling onStart() before
    // getServiceDelegate()/onTemporalEvent()) -- registerBackgroundSync()'s
    // own already-registered check keeps repeat calls here cheap.
    (:background)
    function onStart(state as Dictionary?) as Void {
        registerBackgroundSync();
        ComplicationsPublisher.updateAll();

        // :launchedFromComplication is the complication index (Bottle=0,
        // Wet=1, Dirty=2 -- ComplicationsPublisher.ID_*) the app was
        // launched from, present only when a watch face called
        // Complications.exitTo() for one of this app's own complications.
        var value = (state != null) ? state.get(:launchedFromComplication) : null;
        launchedFromComplication = (value instanceof Number) ? value : null;
    }

    (:background)
    function onStop(state as Dictionary?) as Void {
    }

    // Applies the configured sync interval to the platform's temporal-event
    // schedule. Re-registering overwrites the previous schedule -- that's
    // what makes the interval configurable -- but registerForTemporalEvent()
    // isn't free, so skip it once the current config is already what's
    // registered. getTemporalEventRegisteredTime() only exposes the next
    // scheduled Moment, not the interval that produced it, so the interval
    // actually compared against is tracked ourselves in Store.
    (:background)
    function registerBackgroundSync() as Void {
        var minutes = Config.getSyncIntervalMinutes();
        var hasRegistration = Background.getTemporalEventRegisteredTime() != null;
        if (!shouldRegisterSyncInterval(minutes, Store.getRegisteredSyncIntervalMinutes(), hasRegistration)) {
            return;
        }
        Background.registerForTemporalEvent(new Time.Duration(minutes * 60));
        Store.setRegisteredSyncIntervalMinutes(minutes);
    }

    // Split out from registerBackgroundSync() so the skip/re-register
    // decision is directly testable without touching the real Background
    // registration.
    (:background)
    function shouldRegisterSyncInterval(minutes as Number, registeredMinutes as Number, hasRegistration as Boolean) as Boolean {
        return !hasRegistration || minutes != registeredMinutes;
    }

    (:background)
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new BackgroundServiceDelegate() ];
    }

    // Wet/Dirty -> record instantly and show only SuccessView (exits itself
    // after the checkmark). Bottle -> open BottleConfirmView directly, since
    // it's the one action that needs a confirm step before recording.
    // Normal launches (launcher, glance, hotkey) have no
    // :launchedFromComplication and fall through to HomeView as before.
    // Selecting the glance in the carousel falls through to
    // getInitialView() below (default platform behavior) -- no extra
    // routing code needed here.
    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [ new GlanceView() ];
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var complicationId = launchedFromComplication;
        if (complicationId == ComplicationsPublisher.ID_WET) {
            return RecordController.recordDiaperInitialView(Store.ACTION_WET);
        } else if (complicationId == ComplicationsPublisher.ID_DIRTY) {
            return RecordController.recordDiaperInitialView(Store.ACTION_DIRTY);
        } else if (complicationId == ComplicationsPublisher.ID_BOTTLE) {
            var bottleView = new BottleConfirmView(true);
            return [ bottleView, new BottleConfirmDelegate(bottleView) ];
        }

        var view = new HomeView();
        return [ view, new HomeDelegate(view) ];
    }

}

function getApp() as BabyDaybookApp {
    return Application.getApp() as BabyDaybookApp;
}
