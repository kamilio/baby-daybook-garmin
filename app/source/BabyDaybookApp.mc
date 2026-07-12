import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class BabyDaybookApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new BabyDaybookView(), new BabyDaybookDelegate() ];
    }

}

function getApp() as BabyDaybookApp {
    return Application.getApp() as BabyDaybookApp;
}
