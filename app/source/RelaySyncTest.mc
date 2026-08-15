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
        queue.add({ "id" => "sleep-stop", "type" => "sleeping", "activityId" => "sleep-start", "startMillis" => 2000l, "endMillis" => 3000l, "duration" => 1000l, "inProgress" => false });
        for (var i = 2; i < 12; i++) { queue.add({ "id" => i.toString(), "type" => "bottle", "startMillis" => i }); }
        var result = RelaySync.batch(queue);
        return result.size() == 10 && result[0].get("volume") == 120 && result[0].get("attempts") == null &&
            result[1].get("pee") == true && result[1].get("poo") == false &&
            result[2].get("activityId").equals("sleep-start") && result[2].get("inProgress") == false;
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

    (:test)
    function testAppliesFetchedBottleGroups(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var applied = RelaySync.applyBottleGroups([
            { "uid" => "mother", "title" => "Mother's milk", "messageKey" => "mothers_milk" },
            { "uid" => "formula", "title" => "Formula", "messageKey" => "formula" }
        ]);
        var groups = Store.getBottleGroups();
        var ok = applied && groups.size() == 2 && groups[1].get("uid").equals("formula");
        Storage.clearValues();
        return ok;
    }

    (:test)
    function testAppliesAndClearsFetchedActiveSleep(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var applied = RelaySync.applyActiveSleep({ "activityId" => "phone-sleep", "startMillis" => 1000l });
        var active = Store.getActiveSleep();
        var valid = applied && active.get("activityId").equals("phone-sleep");
        var cleared = RelaySync.applyActiveSleep(null) && Store.getActiveSleep() == null;
        Storage.clearValues();
        return valid && cleared;
    }

    (:test)
    function testAppliesBabyProfileForGlance(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var applied = RelaySync.applyBabyProfile({ "name" => "Victoria", "birthdayMillis" => 1000l });
        var profile = Store.getBabyProfile();
        var rejected = !RelaySync.applyBabyProfile({ "name" => "", "birthdayMillis" => "bad" });
        var ok = applied && rejected && profile.get("name").equals("Victoria")
            && profile.get("birthdayMillis") == 1000l;
        Storage.clearValues();
        return ok;
    }
}
