import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Simulator-only entry point. It renders production views under deterministic
// state without adding scenario hooks or fixture data to the release app.
class BabyDaybookE2EApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        Storage.clearValues();
        if (!ScenarioConfig.NAME.equals("home-unconfigured")) {
            Storage.setValue("provisionedBabyUid", "scenario-baby");
            Store.setAuthCache("", 0, "scenario-user", "scenario-refresh-token");
        }
        Store.setBottleGroups([
            { "uid" => "group-mothers", "messageKey" => Store.MILK_MOTHERS, "title" => "Mother's milk" },
            { "uid" => "group-formula", "messageKey" => Store.MILK_FORMULA, "title" => "Formula" }
        ]);
        if (ScenarioConfig.NAME.equals("bottle-type-formula")) {
            Store.setLastMilkType("group-formula");
        }
        if (ScenarioConfig.NAME.equals("bottle-amount-min")) { Store.setLastBottleOz(1); }
        if (ScenarioConfig.NAME.equals("bottle-amount-max")) { Store.setLastBottleOz(10); }
        if (ScenarioConfig.NAME.equals("sleep-active")) {
            Store.setActiveSleep({ "activityId" => "sleep-active", "startMillis" => TimeUtil.nowEpochMillis() - 1800000 });
        } else if (ScenarioConfig.NAME.equals("event-log")) {
            var now = TimeUtil.nowEpochMillis();
            Store.appendWatchEvent({ "id" => "one", "type" => "bottle", "label" => "Bottle 4 oz · Formula", "startMillis" => now - 120000, "status" => "synced" });
            Store.appendWatchEvent({ "id" => "two", "type" => "diaper_change", "label" => "Wet + dirty diaper", "startMillis" => now - 60000, "status" => "failed" });
            Store.appendWatchEvent({ "id" => "three", "type" => "sleeping", "label" => "Sleep started", "startMillis" => now, "status" => "pending" });
        } else if (ScenarioConfig.NAME.equals("glance-profile")) {
            Store.setBabyProfile("Victoria", TimeUtil.nowEpochMillis() - 10L * 86400000L);
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        if (ScenarioConfig.NAME.equals("bottle-amount") || ScenarioConfig.NAME.equals("bottle-amount-min") ||
            ScenarioConfig.NAME.equals("bottle-amount-max")) {
            return [new BottlePickerScenarioHost(), new WatchUi.BehaviorDelegate()];
        }
        if (ScenarioConfig.NAME.equals("bottle-type") || ScenarioConfig.NAME.equals("bottle-type-formula")) {
            var milk = new BottleMilkMenu();
            return [milk, new BottleMilkMenuDelegate(false)];
        }
        if (ScenarioConfig.NAME.equals("bottle-success")) {
            var bottleSuccess = new ScenarioSuccessView("Bottle 4 oz", TimeUtil.nowEpochMillis(), "scenario-synced", false);
            return [bottleSuccess, new SuccessDelegate(bottleSuccess)];
        }
        if (ScenarioConfig.NAME.equals("sleep-conflict-running")) {
            return [new WatchUi.Confirmation("Sleep is running. Stop it?"), new SleepConflictDelegate(false)];
        }
        if (ScenarioConfig.NAME.equals("event-log")) {
            return [new WatchEventLogMenu(), new WatchEventLogMenuDelegate()];
        }
        if (ScenarioConfig.NAME.equals("glance-profile")) {
            return [new GlanceScenarioView()];
        }
        if (ScenarioConfig.NAME.equals("sleep-inactive") || ScenarioConfig.NAME.equals("sleep-active")) {
            return [new SleepScenarioMenu(), new BabyDaybookMenuDelegate()];
        }
        if (ScenarioConfig.NAME.equals("wet-dirty-success")) {
            var success = new ScenarioSuccessView("Wet + dirty diaper", TimeUtil.nowEpochMillis(), "scenario-synced", false);
            return [success, new SuccessDelegate(success)];
        }
        if (ScenarioConfig.NAME.equals("sleep-start-success") || ScenarioConfig.NAME.equals("sleep-stop-success")) {
            var sleepLabel = ScenarioConfig.NAME.equals("sleep-start-success") ? "Sleep started" : "Sleep stopped";
            var sleepSuccess = new ScenarioSuccessView(sleepLabel, TimeUtil.nowEpochMillis(), "scenario-synced", false);
            return [sleepSuccess, new SuccessDelegate(sleepSuccess)];
        }

        var menu = BabyDaybookMenu.create();
        return [menu, new BabyDaybookMenuDelegate()];
    }
}

class GlanceScenarioView extends WatchUi.View {
    var glance as GlanceView;

    function initialize() {
        View.initialize();
        glance = new GlanceView();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var fullHeight = dc.getHeight();
        var glanceHeight = (fullHeight * 0.32).toNumber();
        var top = (fullHeight - glanceHeight) / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        glance.drawContent(dc, width, glanceHeight, top);
    }
}

// Keep a real view below the picker so accepting it exercises the same
// push/pop/confirmation flow as BottleMilkMenu in production.
class BottlePickerScenarioHost extends WatchUi.View {
    var didPush as Boolean = false;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        if (!didPush) {
            didPush = true;
            var picker = new BottleAmountPicker(false, BottleMilk.selectedGroup());
            WatchUi.pushView(picker, new BottleAmountPickerDelegate(picker), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
    }
}

class ScenarioSuccessView extends SuccessView {
    function initialize(label as String, recordedMillis as Numeric, itemId as String, exitOnDismiss as Boolean) {
        SuccessView.initialize(label, recordedMillis, itemId, exitOnDismiss);
    }

    function onShow() as Void {
        SyncQueue.setOnChanged(new Lang.Method(self, :onQueueChanged));
    }
}

class SleepScenarioMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Baby Daybook" });
        addItem(BabyDaybookMenu.createSleepItem());
    }
}
