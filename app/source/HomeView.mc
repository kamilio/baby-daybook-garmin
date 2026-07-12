import Toybox.Graphics;
import Toybox.Lang;
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

    var zoneTop as Array<Number> = [0, 0, 0];
    var zoneBottom as Array<Number> = [0, 0, 0];

    function initialize() {
        View.initialize();
        highlightZone = zoneForAction(Store.getLastAction());
    }

    function onShow() as Void {
        SyncQueue.setOnChanged(new Lang.Method(self, :onQueueChanged));
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        computeZoneBounds(height);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
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
        var centerX = width / 2;
        var centerY = (zoneTop[zone] + zoneBottom[zone]) / 2;

        // The middle zone sits at the display's widest point and can use a
        // full-size icon/label; top/bottom zones are drawn smaller so they
        // stay clear of the round bezel's clipped corners.
        var isMiddle = (zone == ZONE_WET);
        var iconSize = isMiddle ? (width * 0.20).toNumber() : (width * 0.14).toNumber();
        var font = isMiddle ? Graphics.FONT_MEDIUM : Graphics.FONT_TINY;
        var iconY = centerY - (iconSize * 0.55).toNumber();
        var textY = centerY + (iconSize * 0.55).toNumber();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (zone == ZONE_BOTTLE) {
            drawBottleIcon(dc, centerX, iconY, iconSize);
        } else if (zone == ZONE_WET) {
            drawDropletIcon(dc, centerX, iconY, iconSize);
        } else {
            drawPooIcon(dc, centerX, iconY, iconSize);
        }

        dc.drawText(centerX, textY, font, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawBottleIcon(dc as Dc, cx as Number, cy as Number, size as Number) as Void {
        var bodyWidth = size;
        var bodyHeight = (size * 1.1).toNumber();
        var neckWidth = (size * 0.45).toNumber();
        var neckHeight = (size * 0.30).toNumber();
        var capHeight = (size * 0.18).toNumber();

        var bodyTop = cy - bodyHeight / 2 + neckHeight / 2;
        var neckTop = bodyTop - neckHeight;
        var capTop = neckTop - capHeight;

        dc.fillRectangle(cx - neckWidth / 2 - 1, capTop, neckWidth + 2, capHeight);
        dc.fillRectangle(cx - neckWidth / 2, neckTop, neckWidth, neckHeight + 2);
        dc.fillRoundedRectangle(cx - bodyWidth / 2, bodyTop, bodyWidth, bodyHeight, (size * 0.18).toNumber());
    }

    function drawDropletIcon(dc as Dc, cx as Number, cy as Number, size as Number) as Void {
        var r = (size * 0.5).toNumber();
        dc.fillCircle(cx, cy + r / 2, r);
        dc.fillPolygon([
            [cx, cy - r],
            [cx - r, cy + r / 3],
            [cx + r, cy + r / 3]
        ]);
    }

    function drawPooIcon(dc as Dc, cx as Number, cy as Number, size as Number) as Void {
        var r1 = (size * 0.30).toNumber();
        var r2 = (size * 0.24).toNumber();
        var r3 = (size * 0.18).toNumber();
        dc.fillCircle(cx, cy + (r1 * 0.5).toNumber(), r1);
        dc.fillCircle(cx, cy - (r1 * 0.5).toNumber(), r2);
        dc.fillCircle(cx, cy - (r1 * 1.1 + r3 * 0.3).toNumber(), r3);
    }

    function drawHighlight(dc as Dc, width as Number) as Void {
        var top = zoneTop[highlightZone];
        var bottom = zoneBottom[highlightZone];
        var margin = (width * 0.02).toNumber() + 2;

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawRoundedRectangle(margin, top + margin, width - margin * 2, bottom - top - margin * 2, (width * 0.05).toNumber());
        dc.setPenWidth(1);
    }

    // Pending-sync badge / check-token state, drawn near the bottom edge.
    function drawSyncStatus(dc as Dc, width as Number, height as Number) as Void {
        var y = height - (height * 0.045).toNumber();

        if (SyncQueue.needsToken()) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y, Graphics.FONT_XTINY, "check token", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var pending = SyncQueue.pendingCount();
        if (pending <= 0) {
            return;
        }

        var glyphR = (width * 0.03).toNumber();
        var glyphX = width / 2 - glyphR * 2;
        var textX = width / 2 + glyphR;

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(glyphX, y, glyphR, Graphics.ARC_CLOCKWISE, 30, 300);
        dc.setPenWidth(1);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, y, Graphics.FONT_XTINY, pending.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
