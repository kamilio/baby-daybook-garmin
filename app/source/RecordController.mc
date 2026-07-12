import Toybox.Lang;
import Toybox.WatchUi;

// Instant-record path for the two diaper actions plus the bottle action
// (the latter invoked by BottleConfirmView after its confirm step, never
// directly from a tap zone). Every record enqueues via SyncQueue before any
// network I/O -- the queue is the source of truth, so this never waits for
// the commit to land -- then shows SuccessView carrying the item's queue
// id so that screen can watch the same item drain from "Queued" to
// "Synced". UI-only: unlike Store/SyncQueue this module is never pulled
// into the (:background) build, so it's free to push views directly.
module RecordController {

    function recordDiaper(kind as String) as Void {
        var pee = kind.equals(Store.ACTION_WET);
        var poo = kind.equals(Store.ACTION_DIRTY);
        record({ "type" => "diaper_change", "pee" => pee, "poo" => poo }, kind, labelForDiaper(kind));
    }

    function recordBottle(volume as Number?) as Void {
        var event = { "type" => "bottle" };
        if (volume != null) {
            event.put("volume", volume);
        }
        record(event, Store.ACTION_BOTTLE, labelForBottle(volume));
    }

    // Shared by both actions: stamp one "now" that's used both as the
    // event's startMillis (SyncQueue.enqueue keeps a caller-supplied value
    // rather than re-deriving its own) and as Store.lastEventMillis / the
    // time SuccessView displays, so all three always agree.
    function record(event as Dictionary, action as String, label as String) as Void {
        var nowMillis = TimeUtil.nowEpochMillis();
        event.put("startMillis", nowMillis);
        var itemId = SyncQueue.enqueue(event);

        Store.setLastEventMillis(action, nowMillis);
        Store.setLastAction(action);
        ComplicationsPublisher.updateAll();

        var successView = new SuccessView(label, nowMillis, itemId, false);
        WatchUi.pushView(successView, new SuccessDelegate(successView), WatchUi.SLIDE_IMMEDIATE);
    }

    function labelForDiaper(kind as String) as String {
        return kind.equals(Store.ACTION_DIRTY) ? "Dirty diaper" : "Wet diaper";
    }

    function labelForBottle(volume as Number?) as String {
        if (volume == null) {
            return "Bottle";
        }
        return "Bottle " + volume.toString() + " ml";
    }

}
