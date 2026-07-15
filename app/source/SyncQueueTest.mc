import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

module SyncQueueTest {
    (:test)
    function testEnqueueStampsAndPersistsEvent(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        SyncQueue.enqueue({ "type" => "diaper_change", "pee" => true, "poo" => false });
        var queue = Store.getSyncQueue();
        var item = queue[0];
        var startMillis = item.get("startMillis");
        var ok = queue.size() == 1
            && Store.getPendingCount() == 1
            && item.get("type").equals("diaper_change")
            && (item.get("id") as String).find("-") != null
            && (startMillis instanceof Number || startMillis instanceof Long)
            && item.get("attempts") == null;
        Storage.clearValues();
        return ok;
    }

    (:test)
    function testEnqueueCapsQueueAndDropsOldest(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var seed = [];
        for (var i = 0; i < 100; i++) { seed.add({ "id" => "item-" + i.toString() }); }
        Store.setSyncQueue(seed);
        SyncQueue.enqueue({ "type" => "bottle" });
        var queue = Store.getSyncQueue();
        var ok = queue.size() == 100 && queue[0].get("id").equals("item-1")
            && SyncQueue.isQueueOverflowed() && Store.getPendingCount() == 100;
        Storage.clearValues();
        return ok;
    }

    (:test)
    function testFindAndRemoveById(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setSyncQueue([{ "id" => "a" }, { "id" => "b" }]);
        var found = SyncQueue.findItemById("b");
        var removed = SyncQueue.removeItemById("a");
        var queue = Store.getSyncQueue();
        var ok = found.get("id").equals("b") && removed.get("id").equals("a")
            && queue.size() == 1 && queue[0].get("id").equals("b")
            && Store.getPendingCount() == 1;
        Storage.clearValues();
        return ok;
    }

    (:test)
    function testAcknowledgeRelayRemovesOnlyAckedIds(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setSyncQueue([{ "id" => "a" }, { "id" => "b" }, { "id" => "c" }]);
        SyncQueue.acknowledgeRelaySync(["a", "c"]);
        var queue = Store.getSyncQueue();
        var diagnostic = Store.getSyncDiagnostic();
        var ok = queue.size() == 1 && queue[0].get("id").equals("b")
            && Store.getPendingCount() == 1
            && diagnostic.get("stage").equals("relay_synced")
            && diagnostic.get("code") == 200;
        Storage.clearValues();
        return ok;
    }

    (:test)
    function testStatusFlags(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setQueueLastError(true);
        var first = SyncQueue.consumeLastError();
        var second = SyncQueue.consumeLastError();
        Store.setQueueNeedsToken(true);
        var ok = first && !second && SyncQueue.needsToken();
        Storage.clearValues();
        return ok;
    }
}
