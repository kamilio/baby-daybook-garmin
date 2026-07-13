import Toybox.Graphics;
import Toybox.Lang;

// Shared visual language for the round-screen app. Colors are deliberately
// high-contrast and map cleanly onto the limited MIP palette used by the
// fēnix 7 family.
module Theme {
    const COLOR_BACKGROUND = 0x061A22;
    const COLOR_CARD = 0x12313B;
    const COLOR_CARD_ACTIVE = 0x1B4650;
    const COLOR_TEXT = 0xFFFFFF;
    const COLOR_MUTED = 0xAAAAAA;
    const COLOR_BOTTLE = 0x00BFA5;
    const COLOR_WET = 0x00A8E8;
    const COLOR_DIRTY = 0xFF6B6B;
    const COLOR_WARNING = 0xFFAA00;

    function actionColor(action as String) as Number {
        if (action.equals(Store.ACTION_WET)) {
            return COLOR_WET;
        }
        if (action.equals(Store.ACTION_DIRTY)) {
            return COLOR_DIRTY;
        }
        return COLOR_BOTTLE;
    }

    function drawActionIcon(dc as Graphics.Dc, action as String, cx as Number, cy as Number, size as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, size / 2);
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        var glyphSize = (size * 0.44).toNumber();
        if (action.equals(Store.ACTION_WET)) {
            drawDroplet(dc, cx, cy, glyphSize);
        } else if (action.equals(Store.ACTION_DIRTY)) {
            drawPoo(dc, cx, cy, glyphSize);
        } else {
            drawBottle(dc, cx, cy, glyphSize);
        }
    }

    function drawBottle(dc as Graphics.Dc, cx as Number, cy as Number, size as Number) as Void {
        var bodyWidth = (size * 0.72).toNumber();
        var bodyHeight = (size * 1.05).toNumber();
        var neckWidth = (size * 0.36).toNumber();
        var neckHeight = (size * 0.26).toNumber();
        var capHeight = (size * 0.16).toNumber();
        var bodyTop = cy - bodyHeight / 2 + neckHeight / 2;
        var neckTop = bodyTop - neckHeight;

        dc.fillRoundedRectangle(cx - bodyWidth / 2, bodyTop, bodyWidth, bodyHeight, (size * 0.14).toNumber());
        dc.fillRectangle(cx - neckWidth / 2, neckTop, neckWidth, neckHeight + 2);
        dc.fillRoundedRectangle(cx - neckWidth / 2 - 1, neckTop - capHeight, neckWidth + 2, capHeight, 2);

        dc.setColor(COLOR_BACKGROUND, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - bodyWidth / 4, bodyTop + bodyHeight / 2, bodyWidth / 2, 2);
    }

    function drawDroplet(dc as Graphics.Dc, cx as Number, cy as Number, size as Number) as Void {
        var r = size / 2;
        dc.fillCircle(cx, cy + r / 3, r);
        dc.fillPolygon([
            [cx, cy - r],
            [cx - r, cy + r / 3],
            [cx + r, cy + r / 3]
        ]);
    }

    function drawPoo(dc as Graphics.Dc, cx as Number, cy as Number, size as Number) as Void {
        var r1 = (size * 0.46).toNumber();
        var r2 = (size * 0.36).toNumber();
        var r3 = (size * 0.26).toNumber();
        dc.fillCircle(cx, cy + (r1 * 0.45).toNumber(), r1);
        dc.fillCircle(cx, cy - (r1 * 0.35).toNumber(), r2);
        dc.fillCircle(cx, cy - (r1 * 0.95).toNumber(), r3);
    }

    function drawCheck(dc as Graphics.Dc, cx as Number, cy as Number, radius as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, radius);
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((radius * 0.18).toNumber() + 1);
        dc.drawLine(cx - (radius * 0.48).toNumber(), cy, cx - (radius * 0.12).toNumber(), cy + (radius * 0.36).toNumber());
        dc.drawLine(cx - (radius * 0.12).toNumber(), cy + (radius * 0.36).toNumber(), cx + (radius * 0.55).toNumber(), cy - (radius * 0.38).toNumber());
        dc.setPenWidth(1);
    }
}
