import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Value model shared by the picker view and boundary tests.
class BottleAmountFactory extends WatchUi.PickerFactory {
    var minimum as Numeric;
    var maximum as Numeric;
    var step as Numeric;

    function initialize() {
        PickerFactory.initialize();
        minimum = Config.getBottleMinOz();
        maximum = Config.getBottleMaxOz();
        step = 0.5d;
    }

    function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable? {
        // Match Garmin's SDK Picker sample exactly: picker content is white
        // on the black canvas established by BottleAmountPicker.onUpdate().
        // The selected flag is not a theme signal and differs across firmware,
        // so it must not control the foreground color.
        return new WatchUi.Text({
            :text => BottleUnits.formatOunces(getValue(index) as Numeric) + " oz",
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_LARGE,
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

// Fenix 7 firmware and the simulator paint WatchUi.Picker with opposite
// canvases, after the app's onUpdate(), so neither a black nor white factory
// label is portable. This compact picker owns its pixels while retaining the
// normal Garmin UP/DOWN/START/BACK behavior.
class BottleAmountPicker extends WatchUi.View {
    var exitOnConfirm as Boolean;
    var bottleGroup as Dictionary;
    var factory as BottleAmountFactory;
    var selectedIndex as Number;
    var screenHeight as Number = 260;

    function initialize(exitAfter as Boolean, group as Dictionary) {
        exitOnConfirm = exitAfter;
        bottleGroup = group;
        View.initialize();
        factory = new BottleAmountFactory();
        var last = Store.getLastBottleOz();
        var initial = (last != null) ? last : Config.getDefaultBottleOz();
        selectedIndex = factory.indexFor(initial);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        screenHeight = height;
        var centerX = width / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 0.16).toNumber(), Graphics.FONT_MEDIUM,
            "Bottle amount", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // A restrained full-width focus pill makes the selected value
        // unmistakable without moving its optical center.
        var pillWidth = (width * 0.78).toNumber();
        var pillHeight = (height * 0.25).toNumber();
        var pillY = height / 2;
        dc.setColor(0x202020, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(centerX - pillWidth / 2, pillY - pillHeight / 2,
            pillWidth, pillHeight, pillHeight / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, pillY, Graphics.FONT_LARGE, amountLabel(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawChevron(dc, centerX, (height * 0.30).toNumber(), true);
        drawChevron(dc, centerX, (height * 0.70).toNumber(), false);

        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 0.86).toNumber(), Graphics.FONT_XTINY,
            "START = SAVE",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawChevron(dc as Graphics.Dc, x as Number, y as Number, up as Boolean) as Void {
        var halfWidth = (dc.getWidth() * 0.055).toNumber();
        var halfHeight = (dc.getHeight() * 0.025).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        if (up) {
            dc.drawLine(x - halfWidth, y + halfHeight, x, y - halfHeight);
            dc.drawLine(x, y - halfHeight, x + halfWidth, y + halfHeight);
        } else {
            dc.drawLine(x - halfWidth, y - halfHeight, x, y + halfHeight);
            dc.drawLine(x, y + halfHeight, x + halfWidth, y - halfHeight);
        }
        dc.setPenWidth(1);
    }

    function amountLabel() as String {
        return BottleUnits.formatOunces(currentValue()) + " oz";
    }

    function currentValue() as Numeric {
        return factory.getValue(selectedIndex) as Numeric;
    }

    function increment() as Void {
        if (selectedIndex < factory.getSize() - 1) {
            selectedIndex += 1;
            WatchUi.requestUpdate();
        }
    }

    function decrement() as Void {
        if (selectedIndex > 0) {
            selectedIndex -= 1;
            WatchUi.requestUpdate();
        }
    }

}

class BottleAmountPickerDelegate extends WatchUi.BehaviorDelegate {
    var picker as BottleAmountPicker;

    function initialize(view as BottleAmountPicker) {
        BehaviorDelegate.initialize();
        picker = view;
    }

    function accept() as Boolean {
        var amount = picker.currentValue();
        Store.setLastBottleOz(amount);
        if (!picker.exitOnConfirm) {
            // Remove both bottle-flow views before showing success. When the
            // success screen dismisses, the main menu is now underneath it.
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
        RecordController.recordBottle(amount, picker.bottleGroup, picker.exitOnConfirm);
        return true;
    }

    function onSelect() as Boolean {
        return accept();
    }

    function onNextPage() as Boolean {
        picker.decrement();
        return true;
    }

    function onPreviousPage() as Boolean {
        picker.increment();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var point = event.getCoordinates();
        if (point[1] < picker.screenHeight * 0.4) {
            picker.increment();
        } else if (point[1] > picker.screenHeight * 0.6) {
            picker.decrement();
        } else {
            accept();
        }
        return true;
    }
}
