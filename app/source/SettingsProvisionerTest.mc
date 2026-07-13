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

    (:test)
    function testParsesQueryStringWithoutCallbackScheme(logger as Test.Logger) as Boolean {
        var data = SettingsProvisioner.parseSetupCode("refreshToken=refresh-1&babyUid=baby-1");
        return data != null && data.get("refreshToken").equals("refresh-1") &&
            data.get("babyUid").equals("baby-1");
    }

    (:test)
    function testParsesValuesOnSeparateLines(logger as Test.Logger) as Boolean {
        var data = SettingsProvisioner.parseSetupCode("refreshToken=refresh-2\nbabyUid=baby-2");
        return data != null && data.get("refreshToken").equals("refresh-2") &&
            data.get("babyUid").equals("baby-2");
    }

    (:test)
    function testRejectsIncompleteSetupCode(logger as Test.Logger) as Boolean {
        return SettingsProvisioner.parseSetupCode("refreshToken=refresh-only") == null;
    }
}
