import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

(:test)
module BabyDaybookMenuTest {
    (:test)
    function testStatusShowsQueuedCount(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setAuthCache("", 0, "", "refresh");
        Storage.setValue("provisionedBabyUid", "baby");
        Store.setSyncQueue([{ "id" => "a" }, { "id" => "b" }, { "id" => "c" }]);
        var menu = new BabyDaybookNativeMenu();
        var status = menu.statusText();
        Storage.clearValues();
        return status.equals("3 queued · tap to retry");
    }

    (:test)
    function testStatusPrioritizesRetainedSyncError(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setAuthCache("", 0, "", "refresh");
        Storage.setValue("provisionedBabyUid", "baby");
        Store.setSyncQueue([{ "id" => "a" }]);
        Store.setQueueLastError(true);
        var menu = new BabyDaybookNativeMenu();
        var status = menu.statusText();
        Storage.clearValues();
        return status.equals("Sync error · 1 retained");
    }
}
