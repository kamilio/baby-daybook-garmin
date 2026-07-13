import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

// Use Garmin's own menu rendering, focus, touch, button navigation and
// accessibility behavior instead of maintaining a custom card UI.
module BabyDaybookMenu {
    function create() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({ :title => "Baby Daybook" });

        if (!isProvisioned()) {
            menu.addItem(new WatchUi.MenuItem("Setup required", "Use Connect IQ app settings", :setup, null));
        }

        menu.addItem(new WatchUi.MenuItem("Bottle", lastEventLabel(Store.ACTION_BOTTLE), :bottle, null));
        menu.addItem(new WatchUi.MenuItem("Wet diaper", lastEventLabel(Store.ACTION_WET), :wet, null));
        menu.addItem(new WatchUi.MenuItem("Dirty diaper", lastEventLabel(Store.ACTION_DIRTY), :dirty, null));
        return menu;
    }

    function isProvisioned() as Boolean {
        return Config.getRefreshToken().length() > 0 && Config.getBabyUid().length() > 0;
    }

    function lastEventLabel(action as String) as String {
        var last = Store.getLastEventMillis(action);
        if (last == null) {
            return "Not logged yet";
        }
        var minutes = (((TimeUtil.nowEpochMillis() - last) / 60000).toNumber());
        if (minutes < 1) { return "Just now"; }
        if (minutes < 60) { return minutes.toString() + " min ago"; }
        var hours = minutes / 60;
        if (hours < 24) { return hours.toString() + " hr ago"; }
        return (hours / 24).toString() + " days ago";
    }
}

class BabyDaybookMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :setup) {
            // Re-read in case settings were synced while the app stayed open.
            SettingsProvisioner.applyFromProperties();
        } else if (id == :bottle) {
            var picker = new BottleAmountPicker(false);
            WatchUi.pushView(picker, new BottleAmountPickerDelegate(picker), WatchUi.SLIDE_UP);
        } else if (id == :wet) {
            RecordController.recordDiaper(Store.ACTION_WET);
        } else if (id == :dirty) {
            RecordController.recordDiaper(Store.ACTION_DIRTY);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
