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

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new HomeView();
        return [ view, new HomeDelegate(view) ];
    }

}

function getApp() as BabyDaybookApp {
    return Application.getApp() as BabyDaybookApp;
}
