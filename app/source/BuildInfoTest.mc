import Toybox.Test;
import Toybox.Lang;

(:test)
module BuildInfoTest {
    (:test)
    function testReleaseIdentityMatchesRelayAndDisplay(logger as Test.Logger) as Boolean {
        var client = BuildInfo.relayClient("AMf-vBy-long-token");
        return client.get("appVersion").equals("0.23.5-beta.1") &&
            client.get("internalVersion") == 28 &&
            client.get("authPrefix").equals("AMf-vBy-") &&
            BuildInfo.displayVersion().equals("v0.23.5-beta.1 (28)");
    }
}
