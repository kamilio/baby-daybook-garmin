import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

// Exercises the parts of SyncQueue.mc that don't require a live network
// round trip: enqueue()'s stamping/cap/drop-oldest behavior, the pure
// id/action/queue-mutation helpers, and the paused/last-error flags. With
// Storage cleared and no refresh token configured (properties.xml bakes in
// "" and there's no cached authCache), TokenClient's refresh path takes its
// synchronous no-web-request branch (see TokenClientTest), so calling
// enqueue() -> flush() here never actually reaches the network -- it always
// settles into the paused-for-token state, which this file asserts on
// directly. The commit HTTP round trip itself is exercised in the
// simulator, not here. Not shipped in release builds (unit-test annotated).
module SyncQueueTest {

    (:test)
    function testEnqueueStampsIdStartMillisAndAttempts(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        SyncQueue.enqueue({ "type" => "diaper_change", "pee" => true, "poo" => false });
        var queue = Store.getSyncQueue();
        var item = queue[0];
        var startMillis = item.get("startMillis");
        Storage.clearValues();
        return queue.size() == 1
            && item.get("type").equals("diaper_change")
            && (item.get("id") as String).find("-") != null
            && (startMillis instanceof Number || startMillis instanceof Long)
            && item.get("attempts") == 0;
    }

    (:test)
    function testEnqueuePausesQueueWhenNoRefreshTokenConfigured(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        SyncQueue.enqueue({ "type" => "bottle" });
        var paused = SyncQueue.needsToken();
        Storage.clearValues();
        return paused;
    }

    (:test)
    function testFlushDoesNothingWhileQueueIsPaused(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setSyncQueue([{ "id" => "a", "type" => "bottle", "startMillis" => 1l, "attempts" => 0 }]);
        Store.setQueueNeedsToken(true);
        SyncQueue.flush();
        var queue = Store.getSyncQueue();
        Storage.clearValues();
        return queue.size() == 1 && queue[0].get("id").equals("a");
    }

    (:test)
    function testEnqueueCapsQueueAndDropsOldestSettingOverflowFlag(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var seed = [];
        for (var i = 0; i < 100; i++) {
            seed.add({ "id" => "item-" + i.toString(), "type" => "bottle", "startMillis" => 0l, "attempts" => 0 });
        }
        Store.setSyncQueue(seed);

        SyncQueue.enqueue({ "type" => "diaper_change", "pee" => true, "poo" => false });
        var queue = Store.getSyncQueue();
        var overflowed = SyncQueue.isQueueOverflowed();
        Storage.clearValues();
        return queue.size() == 100 && queue[0].get("id").equals("item-1") && overflowed;
    }

    (:test)
    function testActionForEventMapsBottleWetAndDirty(logger as Test.Logger) as Boolean {
        var bottle = SyncQueue.actionForEvent({ "type" => "bottle" });
        var wet = SyncQueue.actionForEvent({ "type" => "diaper_change", "pee" => true, "poo" => false });
        var dirty = SyncQueue.actionForEvent({ "type" => "diaper_change", "pee" => false, "poo" => true });
        return bottle.equals(Store.ACTION_BOTTLE) && wet.equals(Store.ACTION_WET) && dirty.equals(Store.ACTION_DIRTY);
    }

    (:test)
    function testFindItemByIdReturnsNullWhenMissing(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setSyncQueue([{ "id" => "a" }]);
        var found = SyncQueue.findItemById("missing");
        Storage.clearValues();
        return found == null;
    }

    (:test)
    function testRemoveItemByIdRemovesOnlyMatchingItem(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setSyncQueue([{ "id" => "a" }, { "id" => "b" }]);
        var removed = SyncQueue.removeItemById("a");
        var queue = Store.getSyncQueue();
        Storage.clearValues();
        return removed.get("id").equals("a") && queue.size() == 1 && queue[0].get("id").equals("b");
    }

    (:test)
    function testIncrementAttemptsByIdBumpsMatchingItemOnly(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setSyncQueue([{ "id" => "a", "attempts" => 0 }, { "id" => "b", "attempts" => 0 }]);
        SyncQueue.incrementAttemptsById("a");
        var queue = Store.getSyncQueue();
        Storage.clearValues();
        return queue[0].get("attempts") == 1 && queue[1].get("attempts") == 0;
    }

    (:test)
    function testConsumeLastErrorReadsOnceThenClears(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setQueueLastError(true);
        var first = SyncQueue.consumeLastError();
        var second = SyncQueue.consumeLastError();
        Storage.clearValues();
        return first && !second;
    }

    (:test)
    function testNeedsTokenReflectsStoreFlag(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var before = SyncQueue.needsToken();
        Store.setQueueNeedsToken(true);
        var after = SyncQueue.needsToken();
        Storage.clearValues();
        return !before && after;
    }

    (:test)
    function testPendingCountReflectsQueueSize(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setSyncQueue([{ "id" => "a" }, { "id" => "b" }]);
        var count = SyncQueue.pendingCount();
        Storage.clearValues();
        return count == 2;
    }

    (:test)
    function testIsFlushingFalseWhenNoCommitInFlight(logger as Test.Logger) as Boolean {
        // No pending refresh token configured, so enqueue()'s flush() settles
        // synchronously into the paused-for-token state (see file header)
        // rather than leaving a commit in flight.
        Storage.clearValues();
        SyncQueue.enqueue({ "type" => "bottle" });
        var flushing = SyncQueue.isFlushing();
        Storage.clearValues();
        return !flushing;
    }

    // Regression test for the background-service wall-clock budget: flush()
    // must refuse to dispatch a new item once the caller's gate says no,
    // rather than starting it and only being told to stop afterwards.
    // Without the flushGate check, this would reach TokenClient (calling
    // back synchronously here per the no-refresh-token path -- see file
    // header) and settle into paused-for-token, which the assertions below
    // would also catch: needsToken would flip true and the queue item would
    // still be attempted.
    (:test)
    function testFlushGateBlocksDispatchOfNewItem(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setSyncQueue([{ "id" => "a", "type" => "bottle", "startMillis" => 1l, "attempts" => 0 }]);
        SyncQueue.setFlushGate(new Lang.Method(SyncQueueTest, :denyGate));
        SyncQueue.flush();
        var queue = Store.getSyncQueue();
        var flushing = SyncQueue.isFlushing();
        var neededToken = Store.getQueueNeedsToken();
        SyncQueue.setFlushGate(null);
        Storage.clearValues();
        return queue.size() == 1 && queue[0].get("id").equals("a") && !flushing && !neededToken;
    }

    // Plain helper (not (:test) -- the harness would otherwise pick it up
    // as its own test case and fail invoking it with a logger argument).
    function denyGate() as Boolean {
        return false;
    }

}
