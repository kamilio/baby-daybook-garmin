import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// Shared confirmation screen shown after every instant diaper record and
// every confirmed bottle: checkmark, action label, the recorded wall-clock
// time, and a "Synced"/"Queued" status line that tracks whether this
// specific queue item (by id) is still sitting in SyncQueue. No undo
// affordance -- mistakes are deleted in the phone app, not here. Dismisses
// itself after ~2s: pops back to whatever pushed it, or exits the app
// entirely when exitOnDismiss is set (the complication-launch flow, which
// never has a home view to pop back to).
class SuccessView extends WatchUi.View {

    const DISMISS_DELAY_MS = 2000;

    var label as String;
    var recordedMillis as Numeric;
    var itemId as String;
    var exitOnDismiss as Boolean;

    var dismissTimer as Timer.Timer?;

    function initialize(label as String, recordedMillis as Numeric, itemId as String, exitOnDismiss as Boolean) {
        View.initialize();
        self.label = label;
        self.recordedMillis = recordedMillis;
        self.itemId = itemId;
        self.exitOnDismiss = exitOnDismiss;
    }

    function onShow() as Void {
        SyncQueue.setOnChanged(new Lang.Method(self, :onQueueChanged));
        dismissTimer = new Timer.Timer();
        dismissTimer.start(new Lang.Method(self, :onDismissTimer), DISMISS_DELAY_MS, false);
    }

    function onHide() as Void {
        SyncQueue.setOnChanged(null);
        if (dismissTimer != null) {
            dismissTimer.stop();
            dismissTimer = null;
        }
    }

    function onQueueChanged() as Void {
        WatchUi.requestUpdate();
    }

    function onDismissTimer() as Void {
        dismiss();
    }

    function dismiss() as Void {
        if (exitOnDismiss) {
            System.exit();
        } else {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
    }

    // Not yet found in the queue -> the commit landed and SyncQueue already
    // removed it (or it was permanently dropped -- this screen doesn't
    // distinguish that from success; the pending-sync badge back on
    // HomeView is where a permanent failure shows up).
    function isSynced() as Boolean {
        return SyncQueue.findItemById(itemId) == null;
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(Theme.COLOR_BACKGROUND, Theme.COLOR_BACKGROUND);
        dc.clear();

        var accent = successColor();
        Theme.drawCheck(dc, centerX, (height * 0.31).toNumber(), (width * 0.16).toNumber(), accent);

        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 0.55).toNumber(), Graphics.FONT_MEDIUM, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 0.67).toNumber(), Graphics.FONT_SMALL, formatClock(recordedMillis), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var synced = isSynced();
        var pillWidth = (width * 0.34).toNumber();
        var pillHeight = (height * 0.095).toNumber();
        var pillY = (height * 0.80).toNumber();
        dc.setColor(synced ? accent : Theme.COLOR_CARD, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(centerX - pillWidth / 2, pillY - pillHeight / 2, pillWidth, pillHeight, pillHeight / 2);
        dc.setColor(synced ? Theme.COLOR_TEXT : Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, pillY, Graphics.FONT_XTINY, synced ? "SYNCED" : "QUEUED", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function successColor() as Number {
        if (label.equals("Wet diaper")) {
            return Theme.COLOR_WET;
        }
        if (label.equals("Dirty diaper")) {
            return Theme.COLOR_DIRTY;
        }
        return Theme.COLOR_BOTTLE;
    }

    // TimeUtil's epoch millis are second-resolution (see TimeUtil.mc); this
    // view only needs hour:minute, so that's not a loss.
    function formatClock(millis as Numeric) as String {
        var info = Gregorian.info(new Time.Moment(millis / 1000), Time.FORMAT_SHORT);
        return formatHourMinute(info.hour, info.min);
    }

    // Split out from formatClock so the 24h -> 12h/AM-PM conversion is
    // testable without depending on Gregorian.info()'s device-timezone
    // conversion.
    function formatHourMinute(hour as Number, min as Number) as String {
        var suffix = (hour >= 12) ? "PM" : "AM";
        var displayHour = hour % 12;
        if (displayHour == 0) {
            displayHour = 12;
        }
        return displayHour.toString() + ":" + min.format("%02d") + " " + suffix;
    }

}

class SuccessDelegate extends WatchUi.BehaviorDelegate {

    var view as SuccessView;

    function initialize(successView as SuccessView) {
        BehaviorDelegate.initialize();
        view = successView;
    }

    function onBack() as Boolean {
        view.dismiss();
        return true;
    }

}
