import Toybox.Test;
import Toybox.Lang;

(:test)
module WatchEventLogMenuTest {
    (:test)
    function testReservesFinalTenthRowForVersion(logger as Test.Logger) as Boolean {
        return WatchEventLog.MAX_EVENT_ROWS == 9 &&
            WatchEventLog.firstVisibleIndex(0) == 0 &&
            WatchEventLog.firstVisibleIndex(9) == 0 &&
            WatchEventLog.firstVisibleIndex(10) == 1 &&
            BuildInfo.displayVersion().equals("v0.23.5-beta.1 (28)");
    }
}
