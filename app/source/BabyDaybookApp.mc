import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class BabyDaybookApp extends Application.AppBase {

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

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new HomeView();
        return [ view, new HomeDelegate(view) ];
    }

}

function getApp() as BabyDaybookApp {
    return Application.getApp() as BabyDaybookApp;
}
