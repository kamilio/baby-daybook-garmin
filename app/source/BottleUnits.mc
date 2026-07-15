import Toybox.Lang;

// Baby Daybook stores bottle volume in milliliters internally even when the
// user's display unit is fluid ounces. Keep the watch UI in US fl oz and
// convert only at the relay boundary.
module BottleUnits {
    const MILLILITERS_PER_US_FLUID_OUNCE = 29.5735295625d;

    function ouncesToMilliliters(ounces as Numeric) as Double {
        return ounces.toDouble() * MILLILITERS_PER_US_FLUID_OUNCE;
    }

    function formatOunces(ounces as Numeric) as String {
        var doubled = (ounces.toDouble() * 2.0d).toNumber();
        if ((doubled % 2) == 0) {
            return (doubled / 2).toString();
        }
        return (doubled / 2).toString() + ".5";
    }
}
