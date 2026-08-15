import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// The glance is deliberately profile-only. Activity-relative times belong
// exclusively to the event log, where their context is unambiguous.
(:glance)
class GlanceView extends WatchUi.GlanceView {

    const DAY_MILLIS = 86400000L;

    function initialize() {
        WatchUi.GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        drawContent(dc, width, height, 0);
    }

    // Kept separate so the simulator scenario can render the same production
    // layout inside a true glance-height strip instead of stretching it over
    // an entire watch-app canvas.
    function drawContent(dc as Dc, width as Number, height as Number, top as Number) as Void {
        var profile = Store.getBabyProfile();
        var name = profile.get("name");
        var birthdayMillis = profile.get("birthdayMillis");

        // Keep the glance renderer self-contained. Glances execute in a
        // separate, memory-limited context and cannot safely call the app's
        // foreground-only Theme helpers.
        dc.setColor(0x061A22, 0x061A22);
        dc.fillRectangle(0, top, width, height);

        // Garmin renders the app icon alongside the glance content. Do not
        // draw another icon here or the real carousel shows two of them.
        var textX = (width * 0.08).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, top + (height * 0.31).toNumber(), Graphics.FONT_SMALL,
            (name instanceof String && name.length() > 0) ? name : "Baby",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var age = ageLabel((Time.now().value() as Long) * 1000L,
            Store.isEpochMillis(birthdayMillis) ? birthdayMillis as Numeric : null);
        if (age.length() > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(textX, top + (height * 0.71).toNumber(), Graphics.FONT_XTINY, age,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var pending = Store.getPendingCount();
        if (pending > 0) {
            var badgeX = (width * 0.91).toNumber();
            var badgeY = top + (height * 0.69).toNumber();
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(badgeX, badgeY, (height * 0.075).toNumber());
            dc.drawText(badgeX - (height * 0.12).toNumber(), badgeY,
                Graphics.FONT_XTINY, pending.toString(),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Baby-friendly precision: days during the first week, weeks + remaining
    // days through 12 weeks, months through the second birthday, then years
    // plus remaining months. Future birthdays clamp to newborn.
    function ageLabel(nowMillis as Numeric, birthdayMillis as Numeric?) as String {
        if (birthdayMillis == null) { return ""; }
        var elapsed = nowMillis - birthdayMillis;
        if (elapsed < 0) { elapsed = 0; }
        var days = (elapsed / DAY_MILLIS).toNumber();
        if (days == 0) { return "Newborn"; }
        if (days == 1) { return "1 day"; }
        if (days < 7) { return days.toString() + " days"; }
        if (days < 84) {
            var weeks = days / 7;
            var remainingDays = days % 7;
            if (remainingDays == 0) { return weeks.toString() + " w"; }
            return weeks.toString() + " w " + remainingDays.toString() +
                ((remainingDays == 1) ? " day" : " days");
        }
        if (days < 730) {
            var months = (days * 12) / 365;
            if (months < 1) { months = 1; }
            return months.toString() + ((months == 1) ? " month" : " months");
        }
        var years = days / 365;
        var remainingMonths = ((days % 365) * 12) / 365;
        var result = years.toString() + ((years == 1) ? " year" : " years");
        if (remainingMonths > 0) {
            result += " " + remainingMonths.toString() + " mo";
        }
        return result;
    }
}
