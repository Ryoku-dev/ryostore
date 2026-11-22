pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

// content/Foil.qml — the holo shine over the card's window and face. The
// hub draws it with a compiled foil shader; a plugin ships no compiled
// binaries, so this is the same idea painted on a Canvas: a diagonal five-
// mineral gradient at `strength` alpha, plus a soft highlight band that
// travels while `live`. Two rules keep it honest: gradient stops must be
// strings (a QColor serializes to #aarrggbb and corrupts the render), and
// the paint is clipped to the card's cut-corner octagon, so it never spills
// over the rim.
Item {
    id: foil

    property real strength: 0
    property bool live: false
    // the cursor over the card, normalized -0.5..0.5 on each axis. While
    // `touched` the sheen parks under the cursor and a hot spot blooms
    // there, the way a real holo card flashes when you tilt it under a lamp.
    property bool touched: false
    property real hx: 0
    property real hy: 0
    property real cut: 14
    property color c1: Theme.accent
    property color c2: Theme.gold
    property color c3: "#3fae6b"
    property color c4: "#4a7bd0"
    property color c5: Theme.sun

    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
            + Math.round(c.b * 255) + "," + a.toFixed(3) + ")";
    }

    // the five-mineral ramp sampled by the cursor's horizontal position:
    // tilt one way, the band shines through jade; the other, through gold.
    function mineralAt(t) {
        const xs = [foil.c1, foil.c2, foil.c3, foil.c4, foil.c5];
        const u = Math.max(0, Math.min(0.999, t + 0.5));
        return xs[Math.floor(u * 5)];
    }

    property real phase: 0
    NumberAnimation on phase {
        running: foil.live && foil.strength > 0
        from: 0
        to: 1
        duration: 9000
        loops: Animation.Infinite
    }

    Canvas {
        anchors.fill: parent
        property real strength: foil.strength
        property real phase: foil.phase
        property real cut: foil.cut
        property bool touched: foil.touched
        property real hx: foil.hx
        property real hy: foil.hy
        onStrengthChanged: requestPaint()
        onPhaseChanged: requestPaint()
        onWidthChanged: requestPaint()
        onCutChanged: requestPaint()
        onTouchedChanged: requestPaint()
        onHxChanged: requestPaint()
        onHyChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (strength <= 0)
                return;
            // clip to the octagon so the shine never paints the cut corners
            var k = Math.max(0, Math.min(cut, Math.min(width, height) / 2));
            ctx.beginPath();
            ctx.moveTo(k, 0);
            ctx.lineTo(width - k, 0);
            ctx.lineTo(width, k);
            ctx.lineTo(width, height - k);
            ctx.lineTo(width - k, height);
            ctx.lineTo(k, height);
            ctx.lineTo(0, height - k);
            ctx.lineTo(0, k);
            ctx.closePath();
            ctx.clip();
            var a = strength * 0.22;
            var g = ctx.createLinearGradient(0, height, width, 0);
            g.addColorStop(0.0, rgba(c1, a));
            g.addColorStop(0.25, rgba(c2, a));
            g.addColorStop(0.5, rgba(c3, a));
            g.addColorStop(0.75, rgba(c4, a));
            g.addColorStop(1.0, rgba(c5, a));
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, width, height);
            // the travelling sheen: phase-swept while idle, cursor-locked
            // while touched. The tilt direction picks the mineral the band
            // shines through, the way a real foil splits the light.
            var x = (touched ? (0.5 + hx) : (phase * 1.6 - 0.3)) * width;
            var band = width * 0.28;
            var s = ctx.createLinearGradient(x - band, 0, x + band, 0);
            s.addColorStop(0, rgba(c5, 0));
            s.addColorStop(0.5, rgba(touched ? foil.mineralAt(hx) : c5, 0.10 + strength * 0.16));
            s.addColorStop(1, rgba(c5, 0));
            ctx.fillStyle = s;
            ctx.fillRect(0, 0, width, height);
            if (touched) {
                var cxp = (0.5 + hx) * width;
                var cyp = (0.5 + hy) * height;
                var r = ctx.createRadialGradient(cxp, cyp, 0, cxp, cyp,
                    Math.max(width, height) * 0.5);
                r.addColorStop(0, rgba(foil.mineralAt(hx), strength * 0.34));
                r.addColorStop(0.4, rgba(foil.mineralAt(hx + 0.34), strength * 0.12));
                r.addColorStop(1, rgba(c5, 0));
                ctx.fillStyle = r;
                ctx.fillRect(0, 0, width, height);
            }
        }
    }
}
