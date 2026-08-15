import Toybox.Lang;
import Toybox.WatchUi;

module WatchEventLog {
    const MAX_EVENT_ROWS = 9;

    function firstVisibleIndex(size as Number) as Number {
        var first = size - MAX_EVENT_ROWS;
        return first < 0 ? 0 : first;
    }
}

class WatchEventLogMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Event log" });
        var events = Store.getWatchEventLog();
        if (events.size() == 0) {
            addItem(new WatchUi.MenuItem("No watch events", "Newest 10 appear here", :empty, null));
        } else {
            var first = WatchEventLog.firstVisibleIndex(events.size());
            for (var i = events.size() - 1; i >= first; i--) {
                var event = events[i] as Dictionary;
                var label = event.get("label") as String;
                var status = event.get("status") as String;
                var millis = event.get("startMillis") as Numeric;
                addItem(new WatchUi.MenuItem(label, statusLabel(status) + " · " + BabyDaybookMenu.lastEventLabelAt(millis), event.get("id"), null));
            }
        }
        addItem(new WatchUi.MenuItem("App version", BuildInfo.displayVersion(), :app_version, null));
    }

    function statusLabel(status as String) as String {
        if (status.equals("synced")) { return "Synced"; }
        if (status.equals("failed")) { return "Failed"; }
        return "Pending";
    }
}

class WatchEventLogMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
}
