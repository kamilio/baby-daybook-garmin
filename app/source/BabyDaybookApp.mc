import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class BabyDaybookApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // Runs in foreground, background, and glance processes. Keep it free of
    // storage/network/background-registration work so glance startup stays
    // lightweight.
    function onStart(state as Dictionary?) as Void {
    }

    function onSettingsChanged() as Void {
        SettingsProvisioner.applyFromProperties();
    }

    function onStop(state as Dictionary?) as Void {
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [ new GlanceView() ];
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        SettingsProvisioner.applyFromProperties();
        var menu = BabyDaybookMenu.create();
        return [ menu, new BabyDaybookMenuDelegate() ];
    }

}

function getApp() as BabyDaybookApp {
    return Application.getApp() as BabyDaybookApp;
}
