import Toybox.Lang;
import Toybox.Test;

module BottleAmountPickerTest {
    (:test)
    function testFactoryCoversHalfOunceRangeAndClampsDefaults(logger as Test.Logger) as Boolean {
        var factory = new BottleAmountFactory();
        var lastIndex = factory.getSize() - 1;
        return factory.getValue(0) == factory.minimum
            && factory.getValue(1) == factory.minimum + 0.5d
            && factory.getValue(lastIndex) == factory.maximum
            && factory.indexFor(factory.minimum - 100) == 0
            && factory.indexFor(factory.maximum + 100) == lastIndex;
    }


    (:test)
    function testUpAddsAndDownReduces(logger as Test.Logger) as Boolean {
        var picker = new BottleAmountPicker(false, {});
        picker.selectedIndex = picker.factory.indexFor(4);
        var delegate = new BottleAmountPickerDelegate(picker);
        delegate.onPreviousPage(); // Fenix UP
        var afterUp = picker.currentValue();
        delegate.onNextPage(); // Fenix DOWN
        return afterUp == 4.5d && picker.currentValue() == 4;
    }
}
