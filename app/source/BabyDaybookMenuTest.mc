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
        Store.setSyncDiagnostic("rejected", 403);
        var menu = new BabyDaybookNativeMenu();
        var status = menu.statusText();
        Storage.clearValues();
        return status.equals("Error 403 · 1 retained");
    }

    (:test)
    function testStatusShowsRawTransportCode(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setAuthCache("", 0, "", "refresh");
        Storage.setValue("provisionedBabyUid", "baby");
        Store.setSyncQueue([{ "id" => "a" }, { "id" => "b" }]);
        Store.setSyncDiagnostic("transport_error", -1001);
        var menu = new BabyDaybookNativeMenu();
        var status = menu.statusText();
        Storage.clearValues();
        return status.equals("Offline -1001 · 2 queued");
    }

    (:test)
    function testStatusKeepsAuthenticationErrorCode(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setAuthCache("", 0, "", "refresh");
        Storage.setValue("provisionedBabyUid", "baby");
        Store.setSyncQueue([{ "id" => "a" }]);
        Store.setSyncDiagnostic("auth_required", 401);
        var menu = new BabyDaybookNativeMenu();
        var status = menu.statusText();
        Storage.clearValues();
        return status.equals("Auth error 401 · 1 queued");
    }
}
