import Toybox.Lang;
import Toybox.Test;

(:test)
module BottleUnitsTest {
    (:test)
    function testFormatsWholeAndLegacyHalfOunces(logger as Test.Logger) as Boolean {
        return BottleUnits.formatOunces(4).equals("4")
            && BottleUnits.formatOunces(4.5d).equals("4.5");
    }

    (:test)
    function testConvertsOuncesToInternalMilliliters(logger as Test.Logger) as Boolean {
        var ml = BottleUnits.ouncesToMilliliters(4);
        return ml > 118.29d && ml < 118.30d;
    }
}
