import Toybox.Lang;
import Toybox.Test;

// Exercises ComplicationsPublisher.formatAge(), the pure age-formatting
// logic behind the published complication values. updateOne()/updateAll()
// themselves call Complications.updateComplication(), which needs a real
// subscriber to observe -- not exercised by (:test); see DEVELOPMENT.md for
// the simulator/watch-face verification steps. Not shipped in release
// builds (unit-test annotated).
module ComplicationsPublisherTest {

    (:test)
    function testFormatAgeNeverRecorded(logger as Test.Logger) as Boolean {
        return ComplicationsPublisher.formatAge(1000000L, null).equals("—");
    }

    (:test)
    function testFormatAgeUnderAnHourInMinutes(logger as Test.Logger) as Boolean {
        var now = 1000000L;
        return ComplicationsPublisher.formatAge(now, now - 0L).equals("0m")
            && ComplicationsPublisher.formatAge(now, now - 45L * 60000L).equals("45m")
            && ComplicationsPublisher.formatAge(now, now - 59L * 60000L).equals("59m");
    }

    (:test)
    function testFormatAgeAtHourBoundarySwitchesToHours(logger as Test.Logger) as Boolean {
        var now = 1000000L;
        return ComplicationsPublisher.formatAge(now, now - 60L * 60000L).equals("1h")
            && ComplicationsPublisher.formatAge(now, now - 2L * 60L * 60000L).equals("2h")
            && ComplicationsPublisher.formatAge(now, now - 23L * 60L * 60000L).equals("23h");
    }

    (:test)
    function testFormatAgeAtDayBoundarySwitchesToDays(logger as Test.Logger) as Boolean {
        var now = 1000000L;
        return ComplicationsPublisher.formatAge(now, now - 24L * 60L * 60000L).equals("1d")
            && ComplicationsPublisher.formatAge(now, now - 3L * 24L * 60L * 60000L).equals("3d");
    }

    (:test)
    function testFormatAgeClampsFutureLastEventToZero(logger as Test.Logger) as Boolean {
        // Defensive: a lastEventMillis somehow after "now" (clock skew)
        // must not go negative.
        var now = 1000000L;
        return ComplicationsPublisher.formatAge(now, now + 60000L).equals("0m");
    }

}
