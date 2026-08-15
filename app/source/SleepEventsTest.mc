import Toybox.Lang;
import Toybox.Test;

module SleepEventsTest {
    (:test)
    function testBuildsStartAndStopForOneStableActivity(logger as Test.Logger) as Boolean {
        var start = SleepEvents.start(1000l);
        var stop = SleepEvents.stop({ "activityId" => "sleep-1", "startMillis" => 1000l }, 2500l);
        return start.get("type").equals("sleeping") && start.get("inProgress") == true
            && stop.get("activityId").equals("sleep-1") && stop.get("startMillis") == 1000l
            && stop.get("endMillis") == 2500l && stop.get("duration") == 1500l
            && stop.get("inProgress") == false;
    }

    (:test)
    function testStopClampsNegativeDurationToZero(logger as Test.Logger) as Boolean {
        var stop = SleepEvents.stop({ "activityId" => "sleep-1", "startMillis" => 2500l }, 1000l);
        return stop.get("endMillis") == 1000l && stop.get("duration") == 0;
    }
}
