import Toybox.Lang;
import Toybox.Test;

// Exercises RecordController's pure label-formatting helpers. record()/
// recordDiaper()/recordBottle() themselves push a WatchUi view as their
// last step, so -- like HomeDelegate's onTap/onSelect -- they're exercised
// manually in the simulator instead of here. Not shipped in release builds
// (unit-test annotated).
module RecordControllerTest {

    (:test)
    function testLabelForDiaperMapsWetAndDirty(logger as Test.Logger) as Boolean {
        return RecordController.labelForDiaper(Store.ACTION_WET).equals("Wet diaper")
            && RecordController.labelForDiaper(Store.ACTION_DIRTY).equals("Dirty diaper");
    }

    (:test)
    function testLabelForBottleWithAndWithoutVolume(logger as Test.Logger) as Boolean {
        return RecordController.labelForBottle(120).equals("Bottle 120 ml")
            && RecordController.labelForBottle(null).equals("Bottle");
    }

}
