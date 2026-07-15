import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// The app's one glance (platform limit -- see AppBase.getGlanceView()).
// Selecting it opens the normal home view; it can't perform actions itself.
// (:glance)-tagged, and only ever touches Store.mc's (:glance)-tagged
// accessors, so the glance's ~32 KB memory budget never pulls in the
// Fly transport (RelaySync).
(:glance)
class GlanceView extends WatchUi.GlanceView {

    function initialize() {
        // Fully qualified -- this class's own name shadows the superclass's
        // simple name "GlanceView".
        WatchUi.GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Glances may reuse their drawing surface. Clear it explicitly to
        // prevent stale pixels/flicker between carousel frames.
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        dc.drawText(width / 2, (height * 0.32).toNumber(), Graphics.FONT_XTINY, "Baby Daybook",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.drawText(width / 2, (height * 0.68).toNumber(), Graphics.FONT_TINY, summaryLine(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawSyncBadge(dc, width, height);
    }

    // "B 2h · W 45m · D 3h" -- one letter + age per action, never recorded
    // shown as "—".
    function summaryLine() as String {
        var now = (Time.now().value() as Long) * 1000L;
        var lastMillis = Store.getAllLastEventMillis();
        return "B " + ageLabel(now, lastMillis.get(Store.ACTION_BOTTLE))
            + " · W " + ageLabel(now, lastMillis.get(Store.ACTION_WET))
            + " · D " + ageLabel(now, lastMillis.get(Store.ACTION_DIRTY));
    }

    // Same compact age format as ComplicationsPublisher.formatAge(), kept
    // as its own small copy rather than a shared dependency -- that module
    // is (:background)-only and pulling it into (:glance) too would be one
    // more thing to keep network-stack-free as it evolves.
    function ageLabel(nowMillis as Numeric, lastEventMillis as Numeric?) as String {
        if (lastEventMillis == null) {
            return "—";
        }
        var diffMillis = nowMillis - lastEventMillis;
        if (diffMillis < 0) {
            diffMillis = 0;
        }
        var minutes = (diffMillis / 60000).toNumber();
        if (minutes < 60) {
            return minutes.toString() + "m";
        }
        var hours = minutes / 60;
        if (hours < 24) {
            return hours.toString() + "h";
        }
        var days = hours / 24;
        return days.toString() + "d";
    }

    // Small drawn arc + count, bottom-right corner -- mirrors HomeView's
    // pending-sync badge. Drawn rather than a text glyph since Fenix MIP
    // fonts don't reliably cover symbol glyphs (see HomeView's own note on
    // emoji fonts).
    function drawSyncBadge(dc as Dc, width as Number, height as Number) as Void {
        var pending = Store.getPendingCount();
        if (pending <= 0) {
            return;
        }

        var y = height - (height * 0.12).toNumber();
        var glyphR = (height * 0.10).toNumber();
        var glyphX = width - (height * 0.30).toNumber();
        var textX = width - (height * 0.12).toNumber();

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(glyphX, y, glyphR, Graphics.ARC_CLOCKWISE, 30, 300);
        dc.setPenWidth(1);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, y, Graphics.FONT_XTINY, pending.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
