import Toybox.Lang;
import Toybox.WatchUi;

module BottleMilk {
    function choiceId(group as Dictionary) as String {
        var uid = group.get("uid");
        if (uid instanceof String && uid.length() > 0) { return uid; }
        return group.get("messageKey") as String;
    }

    function selectedGroup() as Dictionary {
        var groups = Store.getBottleGroups();
        var selected = Store.getLastMilkType();
        for (var i = 0; i < groups.size(); i++) {
            var group = groups[i] as Dictionary;
            if (choiceId(group).equals(selected)) { return group; }
        }
        return groups[0] as Dictionary;
    }
}

class BottleMilkMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Bottle type" });
        var groups = Store.getBottleGroups();
        var selected = BottleMilk.choiceId(BottleMilk.selectedGroup());
        for (var i = 0; i < groups.size(); i++) {
            var group = groups[i] as Dictionary;
            var id = BottleMilk.choiceId(group);
            if (id.equals(selected)) {
                addItem(new WatchUi.MenuItem(group.get("title") as String, "Selected", id, group));
            }
        }
        for (var j = 0; j < groups.size(); j++) {
            var other = groups[j] as Dictionary;
            var otherId = BottleMilk.choiceId(other);
            if (!otherId.equals(selected)) {
                addItem(new WatchUi.MenuItem(other.get("title") as String, "", otherId, other));
            }
        }
    }
}

class BottleMilkMenuDelegate extends WatchUi.Menu2InputDelegate {
    var exitOnConfirm as Boolean;

    function initialize(exitAfter as Boolean) {
        Menu2InputDelegate.initialize();
        exitOnConfirm = exitAfter;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        var groups = Store.getBottleGroups();
        for (var i = 0; i < groups.size(); i++) {
            var group = groups[i] as Dictionary;
            if (BottleMilk.choiceId(group).equals(id)) {
                Store.setLastMilkType(id);
                var picker = new BottleAmountPicker(exitOnConfirm, group);
                WatchUi.pushView(picker, new BottleAmountPickerDelegate(picker), WatchUi.SLIDE_UP);
                return;
            }
        }
    }
}
