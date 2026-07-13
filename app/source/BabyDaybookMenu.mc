import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

// Use Garmin's own menu rendering, focus, touch, button navigation and
// accessibility behavior instead of maintaining a custom card UI.
module BabyDaybookMenu {
    function create() as WatchUi.Menu2 {
        return new BabyDaybookNativeMenu();
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

class BabyDaybookNativeMenu extends WatchUi.Menu2 {
    var syncItem as WatchUi.MenuItem;

    function initialize() {
        Menu2.initialize({ :title => "Baby Daybook" });
        addItem(new WatchUi.MenuItem("Bottle", BabyDaybookMenu.lastEventLabel(Store.ACTION_BOTTLE), :bottle, null));
        addItem(new WatchUi.MenuItem("Wet diaper", BabyDaybookMenu.lastEventLabel(Store.ACTION_WET), :wet, null));
        addItem(new WatchUi.MenuItem("Dirty diaper", BabyDaybookMenu.lastEventLabel(Store.ACTION_DIRTY), :dirty, null));
        syncItem = new WatchUi.MenuItem("Sync", statusText(), :sync, null);
        addItem(syncItem);
    }

    function onShow() as Void {
        SyncQueue.setOnChanged(new Lang.Method(self, :onSyncChanged));
        refreshStatus();
    }

    function onHide() as Void {
        SyncQueue.setOnChanged(null);
    }

    function onSyncChanged() as Void {
        refreshStatus();
    }

    function refreshStatus() as Void {
        syncItem.setSubLabel(statusText());
        WatchUi.requestUpdate();
    }

    function statusText() as String {
        if (!BabyDaybookMenu.isProvisioned() || SyncQueue.needsToken()) {
            return "Setup required";
        }
        var pending = SyncQueue.pendingCount();
        if (Store.getQueueLastError()) {
            return "Sync error · " + pending.toString() + " retained";
        }
        if (SyncQueue.isFlushing()) {
            return "Syncing · " + pending.toString() + " queued";
        }
        if (pending > 0) {
            return pending.toString() + " queued · tap to retry";
        }
        var last = Store.getLastSyncMillis();
        if (last == null) {
            return "Ready";
        }
        var minutes = ((TimeUtil.nowEpochMillis() - last) / 60000).toNumber();
        if (minutes < 1) { return "Synced just now"; }
        if (minutes < 60) { return "Synced " + minutes.toString() + " min ago"; }
        return "Synced " + (minutes / 60).toString() + " hr ago";
    }
}

class BabyDaybookMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :sync) {
            SettingsProvisioner.applyFromProperties();
            Store.setQueueLastError(false);
            SyncQueue.flush();
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
