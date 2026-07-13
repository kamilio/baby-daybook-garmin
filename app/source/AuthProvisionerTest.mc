import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

(:test)
module AuthProvisionerTest {

    (:test)
    function testApplyCredentialsRejectsMissingValues(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var noData = !AuthProvisioner.applyCredentials(null);
        var noToken = !AuthProvisioner.applyCredentials({ "babyUid" => "baby-1" });
        var noBaby = !AuthProvisioner.applyCredentials({ "refreshToken" => "refresh-1" });
        Storage.clearValues();
        return noData && noToken && noBaby;
    }

    (:test)
    function testApplyCredentialsPersistsProvisioning(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var applied = AuthProvisioner.applyCredentials({
            "refreshToken" => "refresh-1",
            "babyUid" => "baby-1"
        });
        var cache = Store.getAuthCache();
        var ok = applied
            && cache.get("refreshToken").equals("refresh-1")
            && Config.getBabyUid().equals("baby-1");
        Storage.clearValues();
        return ok;
    }
}
