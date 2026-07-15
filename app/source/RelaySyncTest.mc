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
        var applied = RelaySync.applyLatest({ "bottle" => 3000l, "wet" => 2000l, "dirty" => 1000l });
        var latest = Store.getAllLastEventMillis();
        var ok = applied && latest.get(Store.ACTION_BOTTLE) == 3000l
            && latest.get(Store.ACTION_WET) == 2000l
            && latest.get(Store.ACTION_DIRTY) == 1000l;
        Storage.clearValues();
        return ok;
    }

    (:test)
    function testNullSnapshotClearsDeletedUpstreamEvents(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.replaceAllLastEventMillis(3000l, 2000l, 1000l);
        var applied = RelaySync.applyLatest({ "bottle" => null, "wet" => null, "dirty" => null });
        var latest = Store.getAllLastEventMillis();
        var ok = applied && latest.get(Store.ACTION_BOTTLE) == null
            && latest.get(Store.ACTION_WET) == null
            && latest.get(Store.ACTION_DIRTY) == null;
        Storage.clearValues();
        return ok;
    }

    (:test)
    function testPartialOrMalformedSnapshotPreservesLocalState(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.replaceAllLastEventMillis(3000l, 2000l, 1000l);
        var partial = RelaySync.applyLatest({ "bottle" => null, "wet" => null });
        var malformed = RelaySync.applyLatest({ "bottle" => null, "wet" => "bad", "dirty" => null });
        var latest = Store.getAllLastEventMillis();
        var ok = !partial && !malformed
            && latest.get(Store.ACTION_BOTTLE) == 3000l
            && latest.get(Store.ACTION_WET) == 2000l
            && latest.get(Store.ACTION_DIRTY) == 1000l;
        Storage.clearValues();
        return ok;
    }
}
