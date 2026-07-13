import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Home screen: three full-width horizontal tap zones (Bottle / Wet / Dirty).
// Geometry (zoneTop/zoneBottom) is recomputed every onUpdate() from the
// current dc dimensions -- no hardcoded pixels, since the layout must work
// across the 240/260/280 px round Fenix 7 variants -- and exposed to
// HomeDelegate so tap hit-testing and button-highlight movement always
// agree with what's actually on screen.
class HomeView extends WatchUi.View {

    const ZONE_BOTTLE = 0;
    const ZONE_WET = 1;
    const ZONE_DIRTY = 2;

    var highlightZone as Number;

    // "Shown once" per SyncQueue.consumeLastError()'s contract: re-read on
    // every onShow() (including a return trip from SuccessView, since this
    // same HomeView instance stays on the stack) so a permanent-failure
    // banner surfaces exactly once, then clears itself on the next visit.
    var hadLastError as Boolean = false;

    var zoneTop as Array<Number> = [0, 0, 0];
    var zoneBottom as Array<Number> = [0, 0, 0];

    function initialize() {
        View.initialize();
        highlightZone = zoneForAction(Store.getLastAction());
    }

    function onShow() as Void {
        SyncQueue.setOnChanged(new Lang.Method(self, :onQueueChanged));
        hadLastError = SyncQueue.consumeLastError();
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        computeZoneBounds(height);

        dc.setColor(Theme.COLOR_BACKGROUND, Theme.COLOR_BACKGROUND);
        dc.clear();

        drawZone(dc, ZONE_BOTTLE, width, "BOTTLE");
        drawZone(dc, ZONE_WET, width, "WET");
        drawZone(dc, ZONE_DIRTY, width, "DIRTY");

        drawHighlight(dc, width);
        drawSyncStatus(dc, width, height);
    }

    function onHide() as Void {
        SyncQueue.setOnChanged(null);
    }

    function onQueueChanged() as Void {
        WatchUi.requestUpdate();
    }

    // --- geometry ---

    // The middle (Wet) zone gets the widest vertical band; top/bottom zones
    // are narrower since they sit under the round display's clipped
    // corners.
    function computeZoneBounds(height as Number) as Void {
        var topHeight = (height * 0.30).toNumber();
        var bottomHeight = (height * 0.30).toNumber();

        zoneTop[ZONE_BOTTLE] = 0;
        zoneBottom[ZONE_BOTTLE] = topHeight;
        zoneTop[ZONE_WET] = topHeight;
        zoneBottom[ZONE_WET] = height - bottomHeight;
        zoneTop[ZONE_DIRTY] = height - bottomHeight;
        zoneBottom[ZONE_DIRTY] = height;
    }

    // Zone index a screen y-coordinate falls into, or -1 if none (geometry
    // is only computed once onUpdate() has run at least once).
    function zoneAt(y as Number) as Number {
        for (var i = 0; i < 3; i++) {
            if (y >= zoneTop[i] && y < zoneBottom[i]) {
                return i;
            }
        }
        return -1;
    }

    function zoneForAction(action as String?) as Number {
        if (action != null && action.equals(Store.ACTION_BOTTLE)) {
            return ZONE_BOTTLE;
        }
        if (action != null && action.equals(Store.ACTION_DIRTY)) {
            return ZONE_DIRTY;
        }
        return ZONE_WET;
    }

    function actionForZone(zone as Number) as String {
        if (zone == ZONE_BOTTLE) {
            return Store.ACTION_BOTTLE;
        }
        if (zone == ZONE_DIRTY) {
            return Store.ACTION_DIRTY;
        }
        return Store.ACTION_WET;
    }

    // --- highlight (button navigation) ---

    function moveHighlight(delta as Number) as Void {
        highlightZone = (highlightZone + delta + 3) % 3;
        WatchUi.requestUpdate();
    }

    function getHighlightZone() as Number {
        return highlightZone;
    }

    // --- drawing ---

    function drawZone(dc as Dc, zone as Number, width as Number, label as String) as Void {
        var action = actionForZone(zone);
        var active = zone == highlightZone;
        var sideMargin = (zone == ZONE_WET) ? (width * 0.055).toNumber() : (width * 0.14).toNumber();
        var verticalMargin = (width * 0.018).toNumber() + 2;
        var cardTop = zoneTop[zone] + verticalMargin;
        var cardBottom = zoneBottom[zone] - verticalMargin;
        var cardHeight = cardBottom - cardTop;
        var centerX = width / 2;
        var centerY = (zoneTop[zone] + zoneBottom[zone]) / 2;

        dc.setColor(active ? Theme.COLOR_CARD_ACTIVE : Theme.COLOR_CARD, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(sideMargin, cardTop, width - sideMargin * 2, cardHeight, (width * 0.065).toNumber());

        var iconSize = (cardHeight * 0.62).toNumber();
        if (iconSize > (width * 0.17).toNumber()) {
            iconSize = (width * 0.17).toNumber();
        }
        var iconX = sideMargin + (width * 0.105).toNumber();
        Theme.drawActionIcon(dc, action, iconX, centerY, iconSize, Theme.actionColor(action));

        var labelX = iconX + iconSize / 2 + (width * 0.045).toNumber();
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(labelX, centerY - (cardHeight * 0.12).toNumber(), Graphics.FONT_SMALL, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(labelX, centerY + (cardHeight * 0.20).toNumber(), Graphics.FONT_XTINY, lastEventLabel(action),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (active) {
            dc.setColor(Theme.actionColor(action), Graphics.COLOR_TRANSPARENT);
            var dotX = width - sideMargin - (width * 0.075).toNumber();
            dc.fillCircle(dotX, centerY, (width * 0.018).toNumber() + 1);
        }
    }

    function drawHighlight(dc as Dc, width as Number) as Void {
        var top = zoneTop[highlightZone];
        var bottom = zoneBottom[highlightZone];
        var margin = (highlightZone == ZONE_WET) ? (width * 0.055).toNumber() : (width * 0.14).toNumber();
        var verticalMargin = (width * 0.018).toNumber() + 2;

        dc.setColor(Theme.actionColor(actionForZone(highlightZone)), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(margin, top + verticalMargin, width - margin * 2, bottom - top - verticalMargin * 2, (width * 0.065).toNumber());
        dc.setPenWidth(1);
    }

    function lastEventLabel(action as String) as String {
        var last = Store.getLastEventMillis(action);
        if (last == null) {
            return "Not logged yet";
        }
        var now = (Time.now().value() as Long) * 1000L;
        var diff = now - last;
        if (diff < 0) {
            diff = 0;
        }
        var minutes = (diff / 60000).toNumber();
        if (minutes < 1) {
            return "Just now";
        }
        if (minutes < 60) {
            return "Last " + minutes.toString() + "m ago";
        }
        var hours = minutes / 60;
        if (hours < 24) {
            return "Last " + hours.toString() + "h ago";
        }
        return "Last " + (hours / 24).toString() + "d ago";
    }

    // Pending-sync badge / check-token / queue-full / last-error state, drawn
    // near the bottom edge. needsToken (blocks every future flush until
    // fixed) takes priority over the foreground-only queue-full warning,
    // which takes priority over the one-shot permanent-failure banner --
    // each condition replaces the plain pending-count badge rather than
    // stacking with it.
    function drawSyncStatus(dc as Dc, width as Number, height as Number) as Void {
        var y = (height * 0.92).toNumber();

        if (SyncQueue.needsToken()) {
            dc.setColor(Theme.COLOR_WARNING, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y, Graphics.FONT_XTINY, "SET UP ON PHONE", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (SyncQueue.isQueueOverflowed()) {
            dc.setColor(Theme.COLOR_WARNING, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y, Graphics.FONT_XTINY, "queue full", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (hadLastError) {
            dc.setColor(Theme.COLOR_WARNING, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y, Graphics.FONT_XTINY, "sync error", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var pending = SyncQueue.pendingCount();
        if (pending <= 0) {
            return;
        }

        var glyphR = (width * 0.03).toNumber();
        var glyphX = width / 2 - glyphR * 2;
        var textX = width / 2 + glyphR;

        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(glyphX, y, glyphR, Graphics.ARC_CLOCKWISE, 30, 300);
        dc.setPenWidth(1);

        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, y, Graphics.FONT_XTINY, pending.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
