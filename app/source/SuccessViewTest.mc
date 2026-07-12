import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

// Exercises SuccessView's pure logic: the 24h -> 12h/AM-PM clock format
// (split out from formatClock() so it doesn't depend on Gregorian.info()'s
// device-timezone conversion) and isSynced()'s queue-membership check.
// onShow()/onDismissTimer()/dismiss() drive a live Timer and WatchUi.popView/
// System.exit, so -- like HomeDelegate's input handlers -- those are
// exercised manually in the simulator instead of here. Not shipped in
// release builds (unit-test annotated).
module SuccessViewTest {

    (:test)
    function testFormatHourMinutePadsMinutesAndPicksSuffix(logger as Test.Logger) as Boolean {
        var view = new SuccessView("Wet diaper", 0l, "id", false);
        return view.formatHourMinute(0, 5).equals("12:05 AM")
            && view.formatHourMinute(12, 0).equals("12:00 PM")
            && view.formatHourMinute(13, 30).equals("1:30 PM")
            && view.formatHourMinute(23, 59).equals("11:59 PM");
    }

    (:test)
    function testIsSyncedReflectsQueueMembership(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setSyncQueue([{ "id" => "abc" }]);
        var queuedView = new SuccessView("Wet diaper", 0l, "abc", false);
        var queuedOk = !queuedView.isSynced();

        var syncedView = new SuccessView("Wet diaper", 0l, "missing", false);
        var syncedOk = syncedView.isSynced();

        Storage.clearValues();
        return queuedOk && syncedOk;
    }

}
