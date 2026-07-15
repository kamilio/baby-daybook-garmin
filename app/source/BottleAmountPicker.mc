import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class BottleAmountFactory extends WatchUi.PickerFactory {
    var minimum as Numeric;
    var maximum as Numeric;
    var step as Numeric;

    function initialize() {
        PickerFactory.initialize();
        minimum = Config.getBottleMinOz();
        maximum = Config.getBottleMaxOz();
        step = 1;
    }

    function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable? {
        return new WatchUi.Text({
            :text => BottleUnits.formatOunces(getValue(index) as Numeric) + " oz",
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_NUMBER_MEDIUM,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    function getValue(index as Number) as Object? {
        return minimum + (index * step);
    }

    function getSize() as Number {
        return ((maximum - minimum) / step) + 1;
    }

    function indexFor(value as Numeric) as Number {
        var clamped = value;
        if (clamped < minimum) { clamped = minimum; }
        if (clamped > maximum) { clamped = maximum; }
        return ((clamped - minimum) / step).toNumber();
    }
}

class BottleAmountPicker extends WatchUi.Picker {
    var exitOnConfirm as Boolean;

    function initialize(exitAfter as Boolean) {
        exitOnConfirm = exitAfter;
        var factory = new BottleAmountFactory();
        var last = Store.getLastBottleOz();
        var initial = (last != null) ? last : Config.getDefaultBottleOz();
        var title = new WatchUi.Text({
            :text => "Bottle amount",
            :color => Graphics.COLOR_WHITE,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });
        Picker.initialize({
            :title => title,
            :pattern => [factory],
            :defaults => [factory.indexFor(initial)]
        });
    }
}

class BottleAmountPickerDelegate extends WatchUi.PickerDelegate {
    var picker as BottleAmountPicker;

    function initialize(view as BottleAmountPicker) {
        PickerDelegate.initialize();
        picker = view;
    }

    function onAccept(values as Array) as Boolean {
        var amount = values[0] as Numeric;
        Store.setLastBottleOz(amount);
        if (!picker.exitOnConfirm) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
        RecordController.recordBottle(amount, picker.exitOnConfirm);
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
