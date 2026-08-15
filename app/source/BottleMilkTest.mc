import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

module BottleMilkTest {
    (:test)
    function testSelectsRememberedFetchedGroup(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setBottleGroups([
            { "uid" => "mother", "messageKey" => "mothers_milk", "title" => "Mother's milk" },
            { "uid" => "formula", "messageKey" => "formula", "title" => "Formula" }
        ]);
        Store.setLastMilkType("formula");
        var selected = BottleMilk.selectedGroup();
        var ok = selected.get("uid").equals("formula") && selected.get("title").equals("Formula");
        Storage.clearValues();
        return ok;
    }
}
