import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

// ServiceDelegate woken by the temporal event BabyDaybookApp registers.
// Drains the shared queue through the Fly relay, exactly like foreground
// recording and manual retry. No direct Firestore or phone handoff is used.
//
// Budget: the platform gives a background wake ~30 s of wall clock and
// ~28 KB of usable memory. WALL_CLOCK_BUDGET_MILLIS below stops the flush
// chain a few seconds under that hard cap so this process calls
// Background.exit() itself rather than being killed mid-request. That only
// holds because RelaySync sends at most ten items per request and checks the
// persisted queue before dispatching another batch. A transport failure
// leaves every unacknowledged item queued for the next wake.
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
        if (!hasBudget() || !RelaySync.request()) {
            finish();
        }
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
        if (!RelaySync.isSyncing() || elapsedMillis() >= WALL_CLOCK_BUDGET_MILLIS) {
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
        // Refresh published ages at the end of every wake, not just when a
        // flush actually changed something, so the displayed age keeps
        // advancing with wall-clock time while the app stays closed.
        ComplicationsPublisher.updateAll();
        Background.exit(null);
    }

}
