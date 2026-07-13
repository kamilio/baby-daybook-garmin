import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Bottle's confirm step -- the only action that doesn't record instantly.
// Prefills the amount from Store.lastBottleMl (else Config.defaultBottleMl),
// steps by Config.bottleStepMl within bottleMinMl..bottleMaxMl. Stepping the
// down arrow below bottleMinMl parks amountMl at null ("-- ml" on screen),
// which records a bottle with no amount -- the amount is optional and can be
// filled in on the phone later. Geometry (like HomeView's) is recomputed
// every onUpdate() from the current dc dimensions and exposed to
// BottleConfirmDelegate so touch hit-testing always agrees with what's drawn.
class BottleConfirmView extends WatchUi.View {

    var amountMl as Number?;
    var exitOnConfirm as Boolean;

    var amountTop as Number = 0;
    var amountBottom as Number = 0;
    var minusRight as Number = 0;
    var plusLeft as Number = 0;
    var confirmTop as Number = 0;

    // exitOnConfirm is set when this view is the app's initial view (the
    // Bottle complication-launch path, BabyDaybookApp.getInitialView()) --
    // there's no home view underneath to pop back to, so BottleConfirmDelegate
    // pushes SuccessView on top instead of popping this view first.
    function initialize(exitOnConfirm as Boolean) {
        View.initialize();
        self.exitOnConfirm = exitOnConfirm;
        var lastMl = Store.getLastBottleMl();
        amountMl = (lastMl != null) ? lastMl : Config.getDefaultBottleMl();
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        computeZoneBounds(width, height);

        dc.setColor(Theme.COLOR_BACKGROUND, Theme.COLOR_BACKGROUND);
        dc.clear();

        drawTitle(dc, width);
        drawAmount(dc, width);
        drawConfirmButton(dc, width, height);
    }

    // --- geometry ---

    function computeZoneBounds(width as Number, height as Number) as Void {
        amountTop = (height * 0.32).toNumber();
        confirmTop = (height * 0.76).toNumber();
        amountBottom = confirmTop;

        minusRight = (width * 0.32).toNumber();
        plusLeft = (width * 0.68).toNumber();
    }

    function isMinusZone(x as Number, y as Number) as Boolean {
        return y >= amountTop && y < amountBottom && x < minusRight;
    }

    function isPlusZone(x as Number, y as Number) as Boolean {
        return y >= amountTop && y < amountBottom && x >= plusLeft;
    }

    function isConfirmZone(y as Number) as Boolean {
        return y >= confirmTop;
    }

    // --- stepper logic ---

    function increment() as Void {
        if (amountMl == null) {
            amountMl = Config.getBottleMinMl();
        } else {
            var next = amountMl + Config.getBottleStepMl();
            var max = Config.getBottleMaxMl();
            amountMl = (next > max) ? max : next;
        }
        WatchUi.requestUpdate();
    }

    function decrement() as Void {
        if (amountMl == null) {
            return;
        }
        var next = amountMl - Config.getBottleStepMl();
        amountMl = (next < Config.getBottleMinMl()) ? null : next;
        WatchUi.requestUpdate();
    }

    function getAmountMl() as Number? {
        return amountMl;
    }

    function amountText() as String {
        return (amountMl == null) ? "— ml" : (amountMl.toString() + " ml");
    }

    // --- drawing ---

    function drawTitle(dc as Dc, width as Number) as Void {
        var centerX = width / 2;
        Theme.drawActionIcon(dc, Store.ACTION_BOTTLE, centerX, (amountTop * 0.34).toNumber(), (width * 0.16).toNumber(), Theme.COLOR_BOTTLE);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (amountTop * 0.75).toNumber(), Graphics.FONT_XTINY, "BOTTLE AMOUNT", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawAmount(dc as Dc, width as Number) as Void {
        var centerY = (amountTop + amountBottom) / 2;

        var cardMargin = (width * 0.11).toNumber();
        var cardTop = amountTop + (width * 0.02).toNumber();
        var cardBottom = amountBottom - (width * 0.025).toNumber();
        dc.setColor(Theme.COLOR_CARD, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cardMargin, cardTop, width - cardMargin * 2, cardBottom - cardTop, (width * 0.075).toNumber());

        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        var value = (amountMl == null) ? "--" : amountMl.toString();
        dc.drawText(width / 2, centerY - (width * 0.035).toNumber(), Graphics.FONT_NUMBER_MEDIUM, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, centerY + (width * 0.11).toNumber(), Graphics.FONT_XTINY, (amountMl == null) ? "NO AMOUNT" : "MILLILITERS", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var minusCanStep = (amountMl != null);
        var plusCanStep = (amountMl == null) || (amountMl < Config.getBottleMaxMl());

        var buttonR = (width * 0.072).toNumber();
        var minusX = minusRight / 2;
        var plusX = plusLeft + (width - plusLeft) / 2;
        dc.setColor(minusCanStep ? Theme.COLOR_CARD_ACTIVE : Theme.COLOR_CARD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(minusX, centerY, buttonR);
        dc.setColor(minusCanStep ? Theme.COLOR_TEXT : Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(minusX, centerY - 1, Graphics.FONT_MEDIUM, "-", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(plusCanStep ? Theme.COLOR_BOTTLE : Theme.COLOR_CARD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(plusX, centerY, buttonR);
        dc.setColor(plusCanStep ? Theme.COLOR_TEXT : Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(plusX, centerY - 1, Graphics.FONT_MEDIUM, "+", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawConfirmButton(dc as Dc, width as Number, height as Number) as Void {
        var margin = (width * 0.20).toNumber();
        var top = confirmTop + (width * 0.03).toNumber();
        var bottom = height - (width * 0.06).toNumber();
        var centerY = (top + bottom) / 2;

        dc.setColor(Theme.COLOR_BOTTLE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(margin, top, width - margin * 2, bottom - top, (width * 0.08).toNumber());
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, centerY, Graphics.FONT_SMALL, "SAVE BOTTLE", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}

// Input for BottleConfirmView: tap hit-tests the minus/plus/confirm zones;
// holding minus/plus (onHold/onRelease) auto-repeats the step so holding
// feels as responsive as repeated tapping. Up/Down step by one, START
// confirms, BACK cancels (pop, nothing saved) -- mirrors HomeDelegate's
// pattern of holding the view instance directly so hit-testing always
// operates on the exact geometry that was last drawn.
class BottleConfirmDelegate extends WatchUi.BehaviorDelegate {

    const REPEAT_INTERVAL_MS = 180;

    var view as BottleConfirmView;
    var repeatTimer as Timer.Timer?;
    var repeatDelta as Number = 0;

    function initialize(bottleConfirmView as BottleConfirmView) {
        BehaviorDelegate.initialize();
        view = bottleConfirmView;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coordinates = clickEvent.getCoordinates();
        var x = coordinates[0];
        var y = coordinates[1];

        if (view.isMinusZone(x, y)) {
            view.decrement();
        } else if (view.isPlusZone(x, y)) {
            view.increment();
        } else if (view.isConfirmZone(y)) {
            confirm();
        }
        return true;
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coordinates = clickEvent.getCoordinates();
        var x = coordinates[0];
        var y = coordinates[1];

        if (view.isMinusZone(x, y)) {
            startRepeat(-1);
            return true;
        }
        if (view.isPlusZone(x, y)) {
            startRepeat(1);
            return true;
        }
        return false;
    }

    function onRelease(clickEvent as WatchUi.ClickEvent) as Boolean {
        stopRepeat();
        return true;
    }

    function onNextPage() as Boolean {
        view.increment();
        return true;
    }

    function onPreviousPage() as Boolean {
        view.decrement();
        return true;
    }

    function onSelect() as Boolean {
        confirm();
        return true;
    }

    function onBack() as Boolean {
        stopRepeat();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function startRepeat(delta as Number) as Void {
        step(delta);
        repeatDelta = delta;
        if (repeatTimer == null) {
            repeatTimer = new Timer.Timer();
        }
        repeatTimer.start(new Lang.Method(self, :onRepeatTimer), REPEAT_INTERVAL_MS, true);
    }

    function stopRepeat() as Void {
        if (repeatTimer != null) {
            repeatTimer.stop();
            repeatTimer = null;
        }
    }

    function onRepeatTimer() as Void {
        step(repeatDelta);
    }

    function step(delta as Number) as Void {
        if (delta > 0) {
            view.increment();
        } else {
            view.decrement();
        }
    }

    // Normal flow (view.exitOnConfirm == false): pops BottleConfirmView off
    // the stack before recording, so SuccessView ends up on top of HomeView
    // and its auto-dismiss pop lands back on the home screen instead of back
    // on this confirm screen.
    // Complication-launch flow (view.exitOnConfirm == true): this view *is*
    // the app's only view, so popping it first would exit the app before
    // SuccessView ever showed. Instead SuccessView is pushed on top of it,
    // and its exitOnDismiss flag calls System.exit() directly on dismiss.
    function confirm() as Void {
        stopRepeat();
        var volume = view.getAmountMl();
        if (volume != null) {
            Store.setLastBottleMl(volume);
        }
        if (view.exitOnConfirm) {
            RecordController.recordBottle(volume, true);
        } else {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            RecordController.recordBottle(volume, false);
        }
    }

}
