import Toybox.Complications;
import Toybox.Lang;

// Publishes the app's three per-action complications (Bottle/Wet/Dirty --
// resources/complications.xml, ids matching Store.ACTION_* below and the
// complication-launch-routing task's Bottle=0/Wet=1/Dirty=2 mapping) with a
// compact "time since last event" value. (:background)-safe: called from
// RecordController after every record, RelaySync after an upstream pull,
// and BackgroundServiceDelegate at the end of every temporal wake, so the
// published age stays fresh within the sync interval even while the app is
// closed. No UI imports -- Toybox.Complications is a data-publish API, not
// a WatchUi one.
(:background)
module ComplicationsPublisher {

    const ID_BOTTLE = 0;
    const ID_WET = 1;
    const ID_DIRTY = 2;

    (:background)
    function updateAll() as Void {
        var now = TimeUtil.nowEpochMillis();
        var lastMillis = Store.getAllLastEventMillis();
        updateOne(ID_BOTTLE, now, lastMillis.get(Store.ACTION_BOTTLE));
        updateOne(ID_WET, now, lastMillis.get(Store.ACTION_WET));
        updateOne(ID_DIRTY, now, lastMillis.get(Store.ACTION_DIRTY));
    }

    (:background)
    function updateOne(id as Number, nowMillis as Numeric, lastEventMillis as Numeric?) as Void {
        var label = formatAge(nowMillis, lastEventMillis);
        try {
            Complications.updateComplication(id, {
                :value => label,
                :shortLabel => label
            });
        } catch (e instanceof Lang.OperationNotAllowedException) {
            // Not associated with this app (e.g. a stale id after a
            // resource change) -- nothing useful to do at a fire-and-forget
            // freshness update, so drop it rather than crash the caller.
        }
    }

    // Compact short label (Complications.shortLabel is documented as a
    // five-character string): "—" when never recorded, "<n>m" under an
    // hour, "<n>h" under a day, "<n>d" beyond that.
    (:background)
    function formatAge(nowMillis as Numeric, lastEventMillis as Numeric?) as String {
        if (lastEventMillis == null) {
            return "—";
        }
        var diffMillis = nowMillis - lastEventMillis;
        if (diffMillis < 0) {
            diffMillis = 0;
        }
        var minutes = (diffMillis / 60000).toNumber();
        if (minutes < 60) {
            return minutes.toString() + "m";
        }
        var hours = minutes / 60;
        if (hours < 24) {
            return hours.toString() + "h";
        }
        var days = hours / 24;
        return days.toString() + "d";
    }

}
