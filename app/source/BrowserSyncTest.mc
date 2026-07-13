import Toybox.Lang;
import Toybox.Test;

(:test)
module BrowserSyncTest {
    (:test)
    function testPayloadCarriesCompactEventFields(logger as Test.Logger) as Boolean {
        var payload = BrowserSync.buildPayload([
            { "id" => "100-1", "type" => "bottle", "startMillis" => 1000l, "volume" => 120 },
            { "id" => "101-2", "type" => "diaper_change", "startMillis" => 2000l, "pee" => true, "poo" => false }
        ]);
        return payload.equals("100-1|bottle|1000|120|0|0~101-2|diaper_change|2000||1|0");
    }

    (:test)
    function testPayloadLimitsNotificationBatch(logger as Test.Logger) as Boolean {
        var queue = [];
        for (var i = 0; i < 12; i++) {
            queue.add({ "id" => i.toString() + "-1", "type" => "bottle", "startMillis" => i });
        }
        var payload = BrowserSync.buildPayload(queue);
        var separators = 0;
        for (var j = 0; j < payload.length(); j++) {
            if (payload.substring(j, j + 1).equals("~")) { separators++; }
        }
        return separators == 9;
    }
}
