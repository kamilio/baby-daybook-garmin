import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

// Exercises GlanceView's pure helpers: ageLabel() (the compact age format)
// and summaryLine() (its composition against Store.lastEventMillis).
// onUpdate()/drawSyncBadge() draw to a real Dc and need the simulator's
// glance carousel to observe -- see DEVELOPMENT.md. Not shipped in release
// builds (unit-test annotated).
module GlanceViewTest {

    (:test)
    function testAgeLabelNeverRecorded(logger as Test.Logger) as Boolean {
        var view = new GlanceView();
        return view.ageLabel(1000000L, null).equals("—");
    }

    (:test)
    function testAgeLabelMinutesThenHoursThenDays(logger as Test.Logger) as Boolean {
        var view = new GlanceView();
        var now = 1000000L;
        return view.ageLabel(now, now - 45L * 60000L).equals("45m")
            && view.ageLabel(now, now - 2L * 60L * 60000L).equals("2h")
            && view.ageLabel(now, now - 3L * 24L * 60L * 60000L).equals("3d");
    }

    (:test)
    function testAgeLabelClampsFutureLastEventToZero(logger as Test.Logger) as Boolean {
        var view = new GlanceView();
        var now = 1000000L;
        return view.ageLabel(now, now + 60000L).equals("0m");
    }

    (:test)
    function testSummaryLineComposesAllThreeActions(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastEventMillis(Store.ACTION_BOTTLE, 1720261201154l);
        Store.setLastEventMillis(Store.ACTION_WET, 1720261201154l);
        var view = new GlanceView();
        var line = view.summaryLine();
        Storage.clearValues();
        return line.find("B ") == 0
            && line.find("W ") != null
            && line.find("D —") != null;
    }

}
