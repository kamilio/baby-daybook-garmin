import Toybox.Lang;
import Toybox.WatchUi;

// Instant-record path for the two diaper actions plus the bottle action
// (the latter invoked by BottleConfirmView after its confirm step, never
// directly from a tap zone). Every record enqueues via SyncQueue before any
// network I/O -- the queue is the source of truth, so this never waits for
// the commit to land -- then shows SuccessView carrying the item's queue
// id so that screen can watch the same item drain from "Queued" to
// "Synced". UI-only: unlike Store/SyncQueue this module is never pulled
// into the glance build, so it's free to push views directly.
module RecordController {

    function recordDiaper(kind as String) as Void {
        var event = diaperEvent(kind);
        event.put("watchLabel", labelForDiaper(kind));
        pushSuccessView(event, kind, labelForDiaper(kind), false);
    }

    function recordBottle(ounces as Numeric?, group as Dictionary, exitOnDismiss as Boolean) as Void {
        var event = { "type" => "bottle" };
        if (ounces != null) {
            event.put("volume", BottleUnits.ouncesToMilliliters(ounces));
        }
        var uid = group.get("uid");
        if (uid instanceof String && uid.length() > 0) { event.put("bottleGroupUid", uid); }
        var messageKey = group.get("messageKey");
        if (messageKey instanceof String && messageKey.length() > 0) { event.put("milkType", messageKey); }
        var title = group.get("title") as String;
        event.put("watchLabel", labelForBottle(ounces) + " · " + title);
        pushSuccessView(event, Store.ACTION_BOTTLE, labelForBottle(ounces), exitOnDismiss);
    }

    function diaperEvent(kind as String) as Dictionary {
        var pee = kind.equals(Store.ACTION_WET) || kind.equals(Store.ACTION_WET_DIRTY);
        var poo = kind.equals(Store.ACTION_DIRTY) || kind.equals(Store.ACTION_WET_DIRTY);
        return { "type" => "diaper_change", "pee" => pee, "poo" => poo };
    }

    function toggleSleep() as Void {
        if (Store.getActiveSleep() == null) { startSleep(); }
        else { stopSleep(); }
    }

    function startSleep() as Void {
        if (Store.getActiveSleep() != null) { return; }
        var nowMillis = TimeUtil.nowEpochMillis();
        var event = SleepEvents.start(nowMillis);
        var itemId = SyncQueue.enqueue(event);
        Store.setActiveSleep({ "activityId" => itemId, "startMillis" => nowMillis });
        finishRecord(Store.ACTION_SLEEP, "Sleep started", nowMillis, itemId, false);
    }

    function stopSleep() as Void {
        var active = Store.getActiveSleep();
        if (active == null) { return; }
        var nowMillis = TimeUtil.nowEpochMillis();
        var event = SleepEvents.stop(active, nowMillis);
        var stopItemId = SyncQueue.enqueue(event);
        Store.setActiveSleep(null);
        finishRecord(Store.ACTION_SLEEP, "Sleep stopped", nowMillis, stopItemId, false);
    }

    function finishRecord(action as String, label as String, nowMillis as Numeric, itemId as String, exitOnDismiss as Boolean) as Void {
        RelaySync.request();
        Store.setLastEventMillis(action, nowMillis);
        if (action.equals(Store.ACTION_WET_DIRTY)) {
            Store.setLastEventMillis(Store.ACTION_WET, nowMillis);
            Store.setLastEventMillis(Store.ACTION_DIRTY, nowMillis);
        }
        Store.setLastAction(action);
        var successView = new SuccessView(label, nowMillis, itemId, exitOnDismiss);
        WatchUi.pushView(successView, new SuccessDelegate(successView), WatchUi.SLIDE_IMMEDIATE);
    }

    function pushSuccessView(event as Dictionary, action as String, label as String, exitOnDismiss as Boolean) as Void {
        var successView = record(event, action, label, exitOnDismiss);
        WatchUi.pushView(successView, new SuccessDelegate(successView), WatchUi.SLIDE_IMMEDIATE);
    }

    // Shared by every entry point above: stamp one "now" that's used both as
    // the event's startMillis (SyncQueue.enqueue keeps a caller-supplied
    // value rather than re-deriving its own) and as Store.lastEventMillis /
    // the time SuccessView displays, so all three always agree.
    function record(event as Dictionary, action as String, label as String, exitOnDismiss as Boolean) as SuccessView {
        var nowMillis = TimeUtil.nowEpochMillis();
        event.put("startMillis", nowMillis);
        if (!(event.get("watchLabel") instanceof String)) { event.put("watchLabel", label); }
        var itemId = SyncQueue.enqueue(event);

        // Foreground uploads use the same Fly relay as manual retries.
        // Recording remains offline-first: the
        // event is durable in Storage before this asynchronous request.
        RelaySync.request();

        Store.setLastEventMillis(action, nowMillis);
        if (action.equals(Store.ACTION_WET_DIRTY)) {
            Store.setLastEventMillis(Store.ACTION_WET, nowMillis);
            Store.setLastEventMillis(Store.ACTION_DIRTY, nowMillis);
        }
        Store.setLastAction(action);

        return new SuccessView(label, nowMillis, itemId, exitOnDismiss);
    }

    function labelForDiaper(kind as String) as String {
        if (kind.equals(Store.ACTION_WET_DIRTY)) { return "Wet + dirty diaper"; }
        return kind.equals(Store.ACTION_DIRTY) ? "Dirty diaper" : "Wet diaper";
    }

    function labelForBottle(ounces as Numeric?) as String {
        if (ounces == null) {
            return "Bottle";
        }
        return "Bottle " + BottleUnits.formatOunces(ounces) + " oz";
    }

}
