import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

// ServiceDelegate woken by the temporal event BabyDaybookApp registers.
// Drains the shared sync queue oldest-first through the existing
// TokenClient/FirestoreClient/SyncQueue pipeline (SyncQueue.flush() already
// chains itself from item to item and stops at the first failure -- see
// SyncQueue.mc), then exits. No UI imports: this class must stay safe to
// pull into the (:background) build.
//
// Budget: the platform gives a background wake ~30 s of wall clock and
// ~28 KB of usable memory. WALL_CLOCK_BUDGET_MILLIS below stops the flush
// chain a few seconds under that hard cap so this process calls
// Background.exit() itself rather than being killed mid-request. That only
// holds if new items stop being *dispatched* once the budget is gone --
// TokenClient.getIdToken() answers synchronously on a cached-token hit, so
// SyncQueue's item-to-item self-chaining can start a fresh commit request
// before this class ever gets a chance to check the clock again. flushGate
// (set below) closes that gap: SyncQueue.flush() itself refuses to start a
// new item once hasBudget() says no, so checkSettled() only ever finish()es
// between items, never mid-request. There is no separate memory guard here:
// a wake that's genuinely too tight on memory surfaces as a makeWebRequest
// failure (BLE_REQUEST_TOO_LARGE), which SyncQueue's commit-result handling
// already classifies as RETRYABLE -- it stops the chain and leaves the rest
// of the queue for the next wake, exactly the "post one item, leave the
// rest" fallback this budget comment describes.
(:background)
class BackgroundServiceDelegate extends System.ServiceDelegate {

    const WALL_CLOCK_BUDGET_MILLIS = 27000;

    (:background)
    var startedAtMillis as Number = 0;

    (:background)
    function initialize() {
        ServiceDelegate.initialize();
    }

    (:background)
    function onTemporalEvent() as Void {
        startedAtMillis = System.getTimer();
        SyncQueue.setOnChanged(new Lang.Method(self, :onQueueChanged));
        // Stops flush() from dispatching a *new* item once the budget is
        // gone -- see the flushGate comment in SyncQueue.mc for why this
        // can't be handled by checking the clock only in checkSettled().
        SyncQueue.setFlushGate(new Lang.Method(self, :hasBudget));
        SyncQueue.flush();
        // flush() is a synchronous no-op (no onChanged fires) when the
        // queue is already empty, already paused for a token, or the gate
        // above just blocked it -- check right away instead of waiting for
        // a callback that never comes.
        checkSettled();
    }

    (:background)
    function onQueueChanged() as Void {
        checkSettled();
    }

    // Exits once SyncQueue has nothing left in flight (drained, paused for
    // a token, or stopped after a retryable failure), or once the wall-clock
    // budget runs out, whichever comes first.
    (:background)
    function checkSettled() as Void {
        if (!SyncQueue.isFlushing() || elapsedMillis() >= WALL_CLOCK_BUDGET_MILLIS) {
            finish();
        }
    }

    (:background)
    function hasBudget() as Boolean {
        return elapsedMillis() < WALL_CLOCK_BUDGET_MILLIS;
    }

    (:background)
    function elapsedMillis() as Number {
        return System.getTimer() - startedAtMillis;
    }

    (:background)
    function finish() as Void {
        SyncQueue.setOnChanged(null);
        SyncQueue.setFlushGate(null);
        Background.exit(null);
    }

}
