import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

// Exercises BottleConfirmView's pure stepper math, prefill, and
// geometry/hit-testing -- the parts that don't require a live touch/button
// event to observe. onHold/onRelease's repeat timer and BottleConfirmDelegate
// itself are exercised manually in the simulator, like HomeDelegate's input
// handlers. Not shipped in release builds (unit-test annotated).
module BottleConfirmViewTest {

    (:test)
    function testInitializePrefillsFromLastBottleMlElseDefault(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastBottleMl(180);
        var prefilledView = new BottleConfirmView();
        var prefilledOk = prefilledView.getAmountMl() == 180;

        Storage.clearValues();
        var defaultView = new BottleConfirmView();
        var defaultOk = defaultView.getAmountMl() == Config.getDefaultBottleMl();

        Storage.clearValues();
        return prefilledOk && defaultOk;
    }

    (:test)
    function testIncrementClampsAtMax(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastBottleMl(Config.getBottleMaxMl());
        var view = new BottleConfirmView();
        Storage.clearValues();

        view.increment();
        return view.getAmountMl() == Config.getBottleMaxMl();
    }

    (:test)
    function testDecrementBelowMinimumParksAtNoAmount(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastBottleMl(Config.getBottleMinMl());
        var view = new BottleConfirmView();
        Storage.clearValues();

        var atMinOk = view.getAmountMl() == Config.getBottleMinMl();
        view.decrement();
        var noAmountOk = view.getAmountMl() == null;
        var textOk = view.amountText().equals("— ml");

        // decrementing again while already at "no amount" stays there
        view.decrement();
        var staysNoAmountOk = view.getAmountMl() == null;

        return atMinOk && noAmountOk && textOk && staysNoAmountOk;
    }

    (:test)
    function testIncrementFromNoAmountJumpsToMinimum(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastBottleMl(Config.getBottleMinMl());
        var view = new BottleConfirmView();
        Storage.clearValues();

        view.decrement();
        var noAmountOk = view.getAmountMl() == null;

        view.increment();
        var backAtMinOk = view.getAmountMl() == Config.getBottleMinMl();

        return noAmountOk && backAtMinOk;
    }

    (:test)
    function testAmountTextFormatsMl(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastBottleMl(150);
        var view = new BottleConfirmView();
        Storage.clearValues();

        return view.amountText().equals("150 ml");
    }

    (:test)
    function testHitTestingZonesAgreeWithComputedBounds(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var view = new BottleConfirmView();
        Storage.clearValues();

        view.computeZoneBounds(260, 260);
        var midY = (view.amountTop + view.amountBottom) / 2;

        var minusOk = view.isMinusZone(0, midY) && !view.isMinusZone(view.minusRight, midY);
        var plusOk = view.isPlusZone(259, midY) && !view.isPlusZone(view.plusLeft - 1, midY);
        var outsideBandOk = !view.isMinusZone(0, view.amountTop - 1) && !view.isPlusZone(259, view.amountBottom);
        var confirmOk = view.isConfirmZone(view.confirmTop) && !view.isConfirmZone(view.confirmTop - 1);

        return minusOk && plusOk && outsideBandOk && confirmOk;
    }

}
