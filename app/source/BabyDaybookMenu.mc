import Toybox.Application.Storage;
import Toybox.Graphics;
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

    function lastEventLabelAt(last as Numeric) as String {
        var minutes = (((TimeUtil.nowEpochMillis() - last) / 60000).toNumber());
        if (minutes < 1) { return "Just now"; }
        if (minutes < 60) { return minutes.toString() + " min ago"; }
        var hours = minutes / 60;
        if (hours < 24) { return hours.toString() + " hr ago"; }
        return (hours / 24).toString() + " days ago";
    }

    function sleepTitle() as String { return Store.getActiveSleep() == null ? "Start sleep" : "Stop sleep"; }
    function sleepStatus() as String { return Store.getActiveSleep() == null ? "Not running" : "Running"; }

    function iconItem(label as String, subLabel as String?, id as Symbol) as WatchUi.MenuItem {
        return new WatchUi.MenuItem(label, subLabel, id, null);
    }

    function createSleepItem() as WatchUi.MenuItem {
        return iconItem(sleepTitle(), sleepStatus(), :sleep);
    }
}

class BabyDaybookNativeMenu extends WatchUi.Menu2 {
    var syncItem as WatchUi.MenuItem;
    var bottleItem as WatchUi.MenuItem;
    var wetItem as WatchUi.MenuItem;
    var dirtyItem as WatchUi.MenuItem;
    var sleepItem as WatchUi.MenuItem;

    function initialize() {
        Menu2.initialize({ :title => "Baby Daybook" });
        if (!BabyDaybookMenu.isProvisioned() || SyncQueue.needsToken()) {
            addItem(BabyDaybookMenu.iconItem(
                "Setup required",
                "Open app settings",
                :setup
            ));
        }
        bottleItem = BabyDaybookMenu.iconItem("Bottle", null, :bottle);
        wetItem = BabyDaybookMenu.iconItem("Wet diaper", null, :wet);
        dirtyItem = BabyDaybookMenu.iconItem("Dirty diaper", null, :dirty);
        sleepItem = BabyDaybookMenu.createSleepItem();
        addItem(bottleItem);
        addItem(wetItem);
        addItem(dirtyItem);
        addItem(sleepItem);
        syncItem = BabyDaybookMenu.iconItem("Sync", statusText(), :sync);
        addItem(syncItem);
        addItem(BabyDaybookMenu.iconItem("Event log", "Watch only · latest 10", :event_log));
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
        sleepItem.setLabel(BabyDaybookMenu.sleepTitle());
        sleepItem.setSubLabel(BabyDaybookMenu.sleepStatus());
        syncItem.setSubLabel(statusText());
        WatchUi.requestUpdate();
    }

    function statusText() as String {
        if (!BabyDaybookMenu.isProvisioned() || SyncQueue.needsToken()) {
            return "Paste setup code in settings";
        }
        var pending = SyncQueue.pendingCount();
        var diagnostic = Store.getSyncDiagnostic();
        var stage = diagnostic.get("stage") as String;
        var code = diagnostic.get("code") as Number;
        if (Store.getQueueLastError()) {
            return "Error " + code.toString() + " · " + pending.toString() + " retained";
        }
        if (RelaySync.isSyncing()) {
            if (stage.equals("token_request") || stage.equals("auth")) {
                return "Authenticating · " + pending.toString() + " queued";
            }
            return "Uploading · " + pending.toString() + " queued";
        }
        if (pending > 0) {
            if (stage.equals("phone_notification")) {
                return "Check phone · " + pending.toString() + " queued";
            }
            if (stage.equals("transport_error") || stage.equals("token_error")) {
                return "Offline " + code.toString() + " · " + pending.toString() + " queued";
            }
            if (stage.equals("token_rejected") || stage.equals("auth_required")) {
                return "Auth error " + code.toString() + " · " + pending.toString() + " queued";
            }
            return pending.toString() + " queued · tap to retry";
        }
        return "Ready";
    }
}

class BabyDaybookMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :setup) {
            var hadSettings = SettingsProvisioner.hasPendingValues();
            var configured = SettingsProvisioner.applyFromProperties();
            if (!configured && !hadSettings) { Store.setSyncDiagnostic("settings_missing", 0); }
        } else if (id == :sync) {
            SettingsProvisioner.applyFromProperties();
            if (!BabyDaybookMenu.isProvisioned()) {
                Store.setSyncDiagnostic("settings_missing", 0);
                return;
            }
            Store.setQueueLastError(false);
            RelaySync.request();
        } else if (id == :bottle) {
            var milk = new BottleMilkMenu();
            WatchUi.pushView(milk, new BottleMilkMenuDelegate(false), WatchUi.SLIDE_UP);
        } else if (id == :wet) {
            RecordController.recordDiaper(Store.ACTION_WET);
        } else if (id == :dirty) {
            RecordController.recordDiaper(Store.ACTION_DIRTY);
        } else if (id == :sleep) {
            var intendedStart = item.getLabel().equals("Start sleep");
            RelaySync.setOnComplete(new Lang.Method(self, :onSleepSyncComplete));
            pendingSleepStart = intendedStart;
            if (!RelaySync.request() && !RelaySync.isSyncing()) {
                RelaySync.setOnComplete(null);
                pendingSleepStart = null;
            }
        } else if (id == :event_log) {
            var log = new WatchEventLogMenu();
            WatchUi.pushView(log, new WatchEventLogMenuDelegate(), WatchUi.SLIDE_UP);
        }
    }

    var pendingSleepStart as Boolean?;

    function onSleepSyncComplete(success as Boolean) as Void {
        var intendedStart = pendingSleepStart;
        pendingSleepStart = null;
        if (!success || intendedStart == null) { return; }

        var isRunning = Store.getActiveSleep() != null;
        if ((intendedStart as Boolean) && !isRunning) {
            RecordController.startSleep();
        } else if (!(intendedStart as Boolean) && isRunning) {
            RecordController.stopSleep();
        } else {
            var prompt = isRunning ? "Sleep is running. Stop it?" : "Sleep is stopped. Start it?";
            var dialog = new WatchUi.Confirmation(prompt);
            WatchUi.pushView(dialog, new SleepConflictDelegate(!isRunning), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class SleepConflictDelegate extends WatchUi.ConfirmationDelegate {
    var startSleep as Boolean;

    function initialize(shouldStart as Boolean) {
        ConfirmationDelegate.initialize();
        startSleep = shouldStart;
    }

    function onResponse(value as WatchUi.Confirm) as Boolean {
        if (value == WatchUi.CONFIRM_YES) {
            if (startSleep) { RecordController.startSleep(); }
            else { RecordController.stopSleep(); }
        }
        return true;
    }
}
