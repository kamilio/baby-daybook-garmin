import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Confirms the app always opens its main menu.
module BabyDaybookAppTest {

    (:test)
    function testGetInitialViewReturnsNativeMenu(logger as Test.Logger) as Boolean {
        var app = new BabyDaybookApp();
        var result = app.getInitialView();
        return result[0] instanceof WatchUi.Menu2;
    }

}
