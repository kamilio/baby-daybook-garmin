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
// recordDiaperInitialView() is the one exception to "push": it's used by
// BabyDaybookApp.getInitialView() for the Wet/Dirty complication-launch
// path, which has no existing view to push onto.
module RecordController {

    function recordDiaper(kind as String) as Void {
        pushSuccessView(diaperEvent(kind), kind, labelForDiaper(kind), false);
    }

    // Used only by BabyDaybookApp.getInitialView() when the app is launched
    // directly by a tap on the Wet/Dirty complication: there's no home view
    // to push onto yet, so the SuccessView itself must be the app's initial
    // view, with exitOnDismiss set so its auto-dismiss calls System.exit()
    // instead of trying to pop a nonexistent view underneath.
    function recordDiaperInitialView(kind as String) as [Views, InputDelegates] {
        return asInitialView(diaperEvent(kind), kind, labelForDiaper(kind));
    }

    function recordBottle(ounces as Numeric?, exitOnDismiss as Boolean) as Void {
        var event = { "type" => "bottle" };
        if (ounces != null) {
            event.put("volume", BottleUnits.ouncesToMilliliters(ounces));
        }
        pushSuccessView(event, Store.ACTION_BOTTLE, labelForBottle(ounces), exitOnDismiss);
    }

    function diaperEvent(kind as String) as Dictionary {
        var pee = kind.equals(Store.ACTION_WET);
        var poo = kind.equals(Store.ACTION_DIRTY);
        return { "type" => "diaper_change", "pee" => pee, "poo" => poo };
    }

    function pushSuccessView(event as Dictionary, action as String, label as String, exitOnDismiss as Boolean) as Void {
        var successView = record(event, action, label, exitOnDismiss);
        WatchUi.pushView(successView, new SuccessDelegate(successView), WatchUi.SLIDE_IMMEDIATE);
    }

    function asInitialView(event as Dictionary, action as String, label as String) as [Views, InputDelegates] {
        var successView = record(event, action, label, true);
        return [ successView, new SuccessDelegate(successView) ];
    }

    // Shared by every entry point above: stamp one "now" that's used both as
    // the event's startMillis (SyncQueue.enqueue keeps a caller-supplied
    // value rather than re-deriving its own) and as Store.lastEventMillis /
    // the time SuccessView displays, so all three always agree.
    function record(event as Dictionary, action as String, label as String, exitOnDismiss as Boolean) as SuccessView {
        var nowMillis = TimeUtil.nowEpochMillis();
        event.put("startMillis", nowMillis);
        var itemId = SyncQueue.enqueue(event);

        // All foreground uploads use the same Fly relay as background
        // wakes and manual retries. Recording remains offline-first: the
        // event is durable in Storage before this asynchronous request.
        RelaySync.request();

        Store.setLastEventMillis(action, nowMillis);
        Store.setLastAction(action);
        ComplicationsPublisher.updateAll();

        return new SuccessView(label, nowMillis, itemId, exitOnDismiss);
    }

    function labelForDiaper(kind as String) as String {
        return kind.equals(Store.ACTION_DIRTY) ? "Dirty diaper" : "Wet diaper";
    }

    function labelForBottle(ounces as Numeric?) as String {
        if (ounces == null) {
            return "Bottle";
        }
        return "Bottle " + BottleUnits.formatOunces(ounces) + " oz";
    }

}
