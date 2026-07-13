import Toybox.Test;
import Toybox.Lang;

(:test)
module SettingsProvisionerTest {
    (:test)
    function testParsesCopiedCallbackUrl(logger as Test.Logger) as Boolean {
        var data = SettingsProvisioner.parseCallbackUrl(
            "connectiq://oauth?refreshToken=refresh_123-abc&babyUid=baby_456"
        );
        return data != null &&
            data.get("refreshToken").equals("refresh_123-abc") &&
            data.get("babyUid").equals("baby_456");
    }

    (:test)
    function testRejectsValueWithoutQuery(logger as Test.Logger) as Boolean {
        return SettingsProvisioner.parseCallbackUrl("not-a-callback") == null;
    }
}
