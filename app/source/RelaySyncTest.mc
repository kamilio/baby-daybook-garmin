import Toybox.Test;
import Toybox.Application.Storage;
import Toybox.Lang;

(:test)
module RelaySyncTest {
    (:test)
    function testBatchLimitsAndCopiesSafeEventFields(logger as Test.Logger) as Boolean {
        var queue = [];
        queue.add({ "id" => "1", "type" => "bottle", "startMillis" => 1000l, "volume" => 120, "attempts" => 9 });
        queue.add({ "id" => "2", "type" => "diaper_change", "startMillis" => 2000l, "pee" => true, "poo" => false });
        for (var i = 2; i < 12; i++) { queue.add({ "id" => i.toString(), "type" => "bottle", "startMillis" => i }); }
        var result = RelaySync.batch(queue);
        return result.size() == 10 && result[0].get("volume") == 120 && result[0].get("attempts") == null &&
            result[1].get("pee") == true && result[1].get("poo") == false;
    }

    (:test)
    function testAppliesLatestUpstreamEvents(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        RelaySync.applyLatest({ "bottle" => 3000l, "wet" => 2000l, "dirty" => 1000l });
        var latest = Store.getAllLastEventMillis();
        var ok = latest.get(Store.ACTION_BOTTLE) == 3000l
            && latest.get(Store.ACTION_WET) == 2000l
            && latest.get(Store.ACTION_DIRTY) == 1000l;
        Storage.clearValues();
        return ok;
    }
}
