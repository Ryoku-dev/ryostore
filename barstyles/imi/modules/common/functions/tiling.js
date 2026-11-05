// Geometry engine for the window tiling assistant.
//
// Everything here is pure: no Quickshell, no Hyprland, no side effects. Callers
// hand in plain numbers and get plain numbers back, which keeps the tricky part
// of the feature (coordinate spaces) testable and out of the QML layer.
//
// Coordinate spaces
//   - Monitor rects are Hyprland *logical* coordinates: the global desktop space
//     that window positions and `reserved` are already expressed in. Physical
//     pixels only show up when dividing by scale.
//   - Zones are fractions (0..1) of the usable area, never pixels, so a saved
//     layout survives a resolution, scale or bar-height change.
//
// Gap model mirrors Hyprland's own: a zone edge sitting on the boundary of the
// usable area is inset by `outer` (gaps_out), an edge shared with another zone
// is inset by `inner` (gaps_in), so the visible gutter between two zones ends up
// 2 * inner, exactly like two dwindle-tiled windows.

.pragma library

// Fraction tolerance. About 2 px on a 1440 px axis - loose enough to absorb the
// rounding of a hand-drawn zone, tight enough not to merge real neighbours.
var EPS = 0.0015;

var SIDES = ["left", "top", "right", "bottom"];
var OPPOSITE = {
    left: "right",
    right: "left",
    top: "bottom",
    bottom: "top"
};

// ---------------------------------------------------------------- rect helpers

function makeRect(x, y, w, h) {
    return {
        x: x,
        y: y,
        width: w,
        height: h
    };
}

function rectContains(r, px, py) {
    if (!r) return false;
    return px >= r.x && px < r.x + r.width && py >= r.y && py < r.y + r.height;
}

function rectCenter(r) {
    return {
        x: r.x + r.width / 2,
        y: r.y + r.height / 2
    };
}

function rectsEqual(a, b, tolerance) {
    var t = tolerance === undefined ? 1 : tolerance;
    if (!a || !b) return false;
    return Math.abs(a.x - b.x) <= t && Math.abs(a.y - b.y) <= t && Math.abs(a.width - b.width) <= t && Math.abs(a.height - b.height) <= t;
}

// Distance from a point to the nearest point of a rect. 0 when inside.
function rectDistance(r, px, py) {
    var dx = Math.max(r.x - px, 0, px - (r.x + r.width));
    var dy = Math.max(r.y - py, 0, py - (r.y + r.height));
    return Math.sqrt(dx * dx + dy * dy);
}

// Shrinks a rect on every side. Hyprland reports and accepts window geometry
// without its border, so the border width has to come off a zone rect before it
// becomes a window, and go back on before a window is matched to a zone. A
// negative amount grows the rect, which is that reverse direction.
function insetRect(r, amount) {
    if (!r) return makeRect(0, 0, 0, 0);
    return makeRect(r.x + amount, r.y + amount, Math.max(0, r.width - 2 * amount), Math.max(0, r.height - 2 * amount));
}

function clamp(v, lo, hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

// -------------------------------------------------------------- monitor / area

// Logical size of a monitor. `width`/`height` from hyprctl are the mode
// resolution in physical pixels; a 90 or 270 degree transform (odd values, and
// the flipped variants 5 and 7) swaps the two before scaling.
function monitorLogicalRect(monitor) {
    if (!monitor) return makeRect(0, 0, 0, 0);
    var scale = monitor.scale > 0 ? monitor.scale : 1;
    var rotated = (monitor.transform % 2) === 1;
    var w = (rotated ? monitor.height : monitor.width) / scale;
    var h = (rotated ? monitor.width : monitor.height) / scale;
    return makeRect(monitor.x ?? 0, monitor.y ?? 0, w, h);
}

// Monitor area minus whatever layer-shell surfaces reserved (bar, docks...).
// `reserved` is [left, top, right, bottom] in logical pixels.
function usableArea(monitor) {
    var full = monitorLogicalRect(monitor);
    var res = monitor?.reserved ?? [0, 0, 0, 0];
    var left = res[0] ?? 0;
    var top = res[1] ?? 0;
    var right = res[2] ?? 0;
    var bottom = res[3] ?? 0;
    return makeRect(full.x + left, full.y + top, Math.max(0, full.width - left - right), Math.max(0, full.height - top - bottom));
}

// Hyprland reports gap options as a css-style string ("5 5 5 5"). We only ever
// use one number, so take the first and fall back to the given default.
function firstCssValue(css, fallback) {
    if (typeof css !== "string") return fallback;
    var first = parseFloat(css.trim().split(/\s+/)[0]);
    return isNaN(first) ? fallback : first;
}

function normalizeGaps(gaps) {
    return {
        outer: Math.max(0, gaps?.outer ?? 0),
        inner: Math.max(0, gaps?.inner ?? 0)
    };
}

// ------------------------------------------------------------------ zone rects

function normalizeZone(zone) {
    var x = clamp(Number(zone?.x ?? 0), 0, 1);
    var y = clamp(Number(zone?.y ?? 0), 0, 1);
    var w = clamp(Number(zone?.w ?? 0), 0, 1 - x);
    var h = clamp(Number(zone?.h ?? 0), 0, 1 - y);
    var out = {
        x: x,
        y: y,
        w: w,
        h: h
    };
    if (zone?.label) out.label = String(zone.label);
    return out;
}

// Drops anything degenerate so a half-finished zone from the editor can never
// produce a zero-width window.
function sanitizeZones(zones, minSize) {
    var min = minSize === undefined ? 0.02 : minSize;
    var list = zones ? Array.from(zones) : [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var z = normalizeZone(list[i]);
        if (z.w < min || z.h < min) continue;
        out.push(z);
    }
    return out;
}

function zoneEdge(zone, side) {
    switch (side) {
    case "left":
        return zone.x;
    case "right":
        return zone.x + zone.w;
    case "top":
        return zone.y;
    case "bottom":
        return zone.y + zone.h;
    }
    return NaN;
}

// Pixel rect of a zone, gaps applied. Outer gap on edges that touch the usable
// area, inner gap on edges shared with a neighbour.
function zoneRect(zone, usable, gaps) {
    var z = normalizeZone(zone);
    var g = normalizeGaps(gaps);

    var left = usable.x + z.x * usable.width;
    var top = usable.y + z.y * usable.height;
    var right = usable.x + (z.x + z.w) * usable.width;
    var bottom = usable.y + (z.y + z.h) * usable.height;

    left += (z.x <= EPS) ? g.outer : g.inner;
    top += (z.y <= EPS) ? g.outer : g.inner;
    right -= (z.x + z.w >= 1 - EPS) ? g.outer : g.inner;
    bottom -= (z.y + z.h >= 1 - EPS) ? g.outer : g.inner;

    return makeRect(Math.round(left), Math.round(top), Math.max(0, Math.round(right - left)), Math.max(0, Math.round(bottom - top)));
}

function zoneRects(zones, usable, gaps) {
    var list = zones ? Array.from(zones) : [];
    var out = [];
    for (var i = 0; i < list.length; i++) out.push(zoneRect(list[i], usable, gaps));
    return out;
}

// ---------------------------------------------------------------- hit testing

// Point (logical pixels, global) to zone fraction space.
function pointToFraction(usable, px, py) {
    if (!usable || usable.width <= 0 || usable.height <= 0) return null;
    return {
        x: (px - usable.x) / usable.width,
        y: (py - usable.y) / usable.height
    };
}

// Hit tests against the ungapped zone, so the gutter between two zones still
// resolves to one of them instead of being a dead strip.
function zoneIndexAt(zones, usable, px, py) {
    var f = pointToFraction(usable, px, py);
    if (!f) return -1;
    var list = zones ? Array.from(zones) : [];
    for (var i = 0; i < list.length; i++) {
        var z = normalizeZone(list[i]);
        if (f.x >= z.x && f.x < z.x + z.w && f.y >= z.y && f.y < z.y + z.h) return i;
    }
    return -1;
}

// Falls back to the closest zone when the cursor sits outside every zone, which
// happens with layouts that do not cover the whole screen.
function nearestZoneIndex(zones, usable, px, py) {
    var hit = zoneIndexAt(zones, usable, px, py);
    if (hit >= 0) return hit;
    var f = pointToFraction(usable, px, py);
    if (!f) return -1;
    var list = zones ? Array.from(zones) : [];
    var best = -1;
    var bestDist = Infinity;
    for (var i = 0; i < list.length; i++) {
        var z = normalizeZone(list[i]);
        var d = rectDistance(makeRect(z.x, z.y, z.w, z.h), f.x, f.y);
        if (d < bestDist) {
            bestDist = d;
            best = i;
        }
    }
    return best;
}

// Which zone, if any, a window is currently sitting in. Used to decide whether a
// drag is leaving a zone (untile) or moving between zones.
function zoneIndexForRect(zones, usable, gaps, rect, tolerance) {
    var t = tolerance === undefined ? 4 : tolerance;
    var rects = zoneRects(zones, usable, gaps);
    for (var i = 0; i < rects.length; i++) {
        if (rectsEqual(rects[i], rect, t)) return i;
    }
    return -1;
}

// ---------------------------------------------------------- direction resolution

function normalizeDirection(direction) {
    switch (direction) {
    case "l":
    case "left":
        return "left";
    case "r":
    case "right":
        return "right";
    case "u":
    case "up":
    case "top":
        return "up";
    case "d":
    case "down":
    case "bottom":
        return "down";
    }
    return "";
}

// Entry zone for a direction when the window is not tiled yet: the one furthest
// towards that edge, preferring whichever straddles the middle of the screen.
function edgeZoneIndex(zones, direction) {
    var dir = normalizeDirection(direction);
    var list = zones ? Array.from(zones) : [];
    if (!dir || list.length === 0) return -1;

    var horizontal = (dir === "left" || dir === "right");
    var best = -1;
    var bestEdge = Infinity;
    var bestOffset = Infinity;
    for (var i = 0; i < list.length; i++) {
        var z = normalizeZone(list[i]);
        var edge = (dir === "left") ? z.x : (dir === "right") ? 1 - (z.x + z.w) : (dir === "up") ? z.y : 1 - (z.y + z.h);
        var center = horizontal ? z.y + z.h / 2 : z.x + z.w / 2;
        var offset = Math.abs(center - 0.5);
        if (edge < bestEdge - EPS || (Math.abs(edge - bestEdge) <= EPS && offset < bestOffset)) {
            best = i;
            bestEdge = edge;
            bestOffset = offset;
        }
    }
    return best;
}

// Nearest zone in a direction that still overlaps on the perpendicular axis, so
// arrowing right from a tall left zone lands on the neighbour it actually
// touches rather than a far corner. Returns `fromIndex` when there is nothing
// that way, which makes repeated presses idle instead of wrapping around.
function resolveDirection(zones, fromIndex, direction) {
    var dir = normalizeDirection(direction);
    var list = zones ? Array.from(zones) : [];
    if (!dir || list.length === 0) return -1;
    if (fromIndex < 0 || fromIndex >= list.length) return edgeZoneIndex(list, dir);

    var from = normalizeZone(list[fromIndex]);
    var horizontal = (dir === "left" || dir === "right");
    var forward = (dir === "right" || dir === "down");

    var a0 = horizontal ? from.y : from.x;
    var a1 = a0 + (horizontal ? from.h : from.w);
    var fromEdge = forward ? zoneEdge(from, horizontal ? "right" : "bottom") : zoneEdge(from, horizontal ? "left" : "top");

    var best = -1;
    var bestGap = Infinity;
    var bestOffset = Infinity;
    for (var i = 0; i < list.length; i++) {
        if (i === fromIndex) continue;
        var z = normalizeZone(list[i]);
        var b0 = horizontal ? z.y : z.x;
        var b1 = b0 + (horizontal ? z.h : z.w);
        if (Math.min(a1, b1) - Math.max(a0, b0) <= EPS) continue;

        var near = forward ? zoneEdge(z, horizontal ? "left" : "top") : zoneEdge(z, horizontal ? "right" : "bottom");
        var gap = forward ? (near - fromEdge) : (fromEdge - near);
        if (gap < -EPS) continue;

        var offset = Math.abs((a0 + a1) / 2 - (b0 + b1) / 2);
        if (gap < bestGap - EPS || (Math.abs(gap - bestGap) <= EPS && offset < bestOffset)) {
            best = i;
            bestGap = gap;
            bestOffset = offset;
        }
    }
    return best >= 0 ? best : fromIndex;
}

// ----------------------------------------------------------------- shared edges

// Zones whose opposite edge butts against `side` of the given zone, restricted
// to those that actually overlap it. These are the neighbours a resize pushes.
function sharedEdgeNeighbours(zones, index, side, tolerance) {
    var t = tolerance === undefined ? EPS : tolerance;
    var list = zones ? Array.from(zones) : [];
    if (index < 0 || index >= list.length || !OPPOSITE[side]) return [];

    var self = normalizeZone(list[index]);
    var line = zoneEdge(self, side);
    var horizontal = (side === "left" || side === "right");
    var a0 = horizontal ? self.y : self.x;
    var a1 = a0 + (horizontal ? self.h : self.w);

    var out = [];
    for (var i = 0; i < list.length; i++) {
        if (i === index) continue;
        var z = normalizeZone(list[i]);
        if (Math.abs(zoneEdge(z, OPPOSITE[side]) - line) > t) continue;
        var b0 = horizontal ? z.y : z.x;
        var b1 = b0 + (horizontal ? z.h : z.w);
        if (Math.min(a1, b1) - Math.max(a0, b0) <= EPS) continue;
        out.push(i);
    }
    return out;
}

// Everything sitting on the same divider line, whether it is the zone's own side
// or the facing side of a neighbour. Dragging the divider has to move both sets
// together or the layout tears open a hole. Overlap is deliberately not required
// here: a full-height column divider should move as one piece even where the
// zones on either side are split differently.
function edgeGroup(zones, index, side, tolerance) {
    var t = tolerance === undefined ? EPS : tolerance;
    var list = zones ? Array.from(zones) : [];
    var group = {
        line: NaN,
        side: side,
        leading: [],
        trailing: []
    };
    if (index < 0 || index >= list.length || !OPPOSITE[side]) return group;

    group.line = zoneEdge(normalizeZone(list[index]), side);
    for (var i = 0; i < list.length; i++) {
        var z = normalizeZone(list[i]);
        if (Math.abs(zoneEdge(z, side) - group.line) <= t) group.leading.push(i);
        else if (Math.abs(zoneEdge(z, OPPOSITE[side]) - group.line) <= t) group.trailing.push(i);
    }
    return group;
}

// Which side of a zone rect a pixel position is grabbing, or "" when the point
// is not near any edge. Lets the resize path tell a divider drag from a plain
// corner-stretch that no neighbour should follow.
function edgeAt(rect, px, py, tolerancePx) {
    var t = tolerancePx === undefined ? 8 : tolerancePx;
    if (!rect) return "";
    var withinY = py >= rect.y - t && py <= rect.y + rect.height + t;
    var withinX = px >= rect.x - t && px <= rect.x + rect.width + t;
    if (withinY && Math.abs(px - rect.x) <= t) return "left";
    if (withinY && Math.abs(px - (rect.x + rect.width)) <= t) return "right";
    if (withinX && Math.abs(py - rect.y) <= t) return "top";
    if (withinX && Math.abs(py - (rect.y + rect.height)) <= t) return "bottom";
    return "";
}

// Inverse of zoneRect for one edge: the fraction a divider sits at, given the
// pixel a window ends at. The gutter is drawn inside the zone, so the divider
// itself is half a gutter further out than the window edge.
function edgeFraction(usable, gaps, side, pixel) {
    var g = normalizeGaps(gaps);
    var horizontal = (side === "left" || side === "right");
    var origin = horizontal ? usable.x : usable.y;
    var span = horizontal ? usable.width : usable.height;
    if (!(span > 0)) return NaN;
    var near = (side === "left" || side === "top");
    return (pixel + (near ? -g.inner : g.inner) - origin) / span;
}

// How far an edge may travel before the zone behind it collapses.
function edgeBounds(zone, side, min) {
    var z = normalizeZone(zone);
    switch (side) {
    case "left":
        return {
            lo: 0,
            hi: z.x + z.w - min
        };
    case "right":
        return {
            lo: z.x + min,
            hi: 1
        };
    case "top":
        return {
            lo: 0,
            hi: z.y + z.h - min
        };
    case "bottom":
        return {
            lo: z.y + min,
            hi: 1
        };
    }
    return {
        lo: 0,
        hi: 1
    };
}

// The same zone with one edge moved and the opposite one pinned.
function zoneWithEdge(zone, side, value) {
    var z = normalizeZone(zone);
    var out = {
        x: z.x,
        y: z.y,
        w: z.w,
        h: z.h
    };
    switch (side) {
    case "left":
        out.x = value;
        out.w = (z.x + z.w) - value;
        break;
    case "right":
        out.w = value - z.x;
        break;
    case "top":
        out.y = value;
        out.h = (z.y + z.h) - value;
        break;
    case "bottom":
        out.h = value - z.y;
        break;
    }
    if (z.label) out.label = z.label;
    return normalizeZone(out);
}

// Moves a divider to a new fraction, taking every zone attached to it along:
// zones sharing that edge follow with theirs, zones facing it across the line
// follow with their opposite edge, so the layout never tears open a hole. The
// move is clamped so nothing on either side collapses. A line with nothing on
// the far side is the monitor boundary rather than a divider and does not move
// at all - that resize is a window growing on its own. Returns a new list, or
// null when nothing moved.
function moveEdge(zones, index, side, fraction, minSize) {
    var min = minSize === undefined ? 0.05 : minSize;
    var list = zones ? Array.from(zones) : [];
    var group = edgeGroup(list, index, side);
    if (isNaN(group.line) || group.trailing.length === 0) return null;

    var facing = OPPOSITE[side];
    var lo = 0;
    var hi = 1;
    var i;
    var bounds;
    for (i = 0; i < group.leading.length; i++) {
        bounds = edgeBounds(list[group.leading[i]], side, min);
        lo = Math.max(lo, bounds.lo);
        hi = Math.min(hi, bounds.hi);
    }
    for (i = 0; i < group.trailing.length; i++) {
        bounds = edgeBounds(list[group.trailing[i]], facing, min);
        lo = Math.max(lo, bounds.lo);
        hi = Math.min(hi, bounds.hi);
    }
    if (lo > hi) return null;

    var target = clamp(fraction, lo, hi);
    if (isNaN(target) || Math.abs(target - group.line) <= EPS) return null;

    var out = list.slice();
    for (i = 0; i < group.leading.length; i++) out[group.leading[i]] = zoneWithEdge(list[group.leading[i]], side, target);
    for (i = 0; i < group.trailing.length; i++) out[group.trailing[i]] = zoneWithEdge(list[group.trailing[i]], facing, target);
    return out;
}

// ---------------------------------------------------------------------- presets

// Derived from where the zone sits rather than stored, so hand-drawn zones from
// the editor get a sensible name for free.
function positionLabel(zone) {
    var z = normalizeZone(zone);
    var cx = z.x + z.w / 2;
    var cy = z.y + z.h / 2;
    var vertical = cy < 1 / 3 ? "Top" : (cy > 2 / 3 ? "Bottom" : "");
    var horizontal = cx < 1 / 3 ? "left" : (cx > 2 / 3 ? "right" : "");
    if (vertical && horizontal) return vertical + " " + horizontal;
    if (vertical) return vertical;
    if (horizontal) return horizontal.charAt(0).toUpperCase() + horizontal.slice(1);
    return "Center";
}

function labelFor(zone) {
    return zone?.label ? String(zone.label) : positionLabel(zone);
}

function gridZones(cols, rows) {
    var c = Math.max(1, Math.round(cols));
    var r = Math.max(1, Math.round(rows));
    var out = [];
    for (var row = 0; row < r; row++) {
        for (var col = 0; col < c; col++) {
            out.push({
                x: col / c,
                y: row / r,
                w: 1 / c,
                h: 1 / r
            });
        }
    }
    return out;
}

function columnZones(fractions) {
    var out = [];
    var x = 0;
    for (var i = 0; i < fractions.length; i++) {
        out.push({
            x: x,
            y: 0,
            w: fractions[i],
            h: 1
        });
        x += fractions[i];
    }
    return out;
}

var PRESETS = {
    // Left half plus a stacked right column - the master/stack layout KDE's
    // tiling popup ships with.
    kde: [
        {
            x: 0,
            y: 0,
            w: 0.5,
            h: 1
        },
        {
            x: 0.5,
            y: 0,
            w: 0.5,
            h: 0.5
        },
        {
            x: 0.5,
            y: 0.5,
            w: 0.5,
            h: 0.5
        }
    ],
    halves: columnZones([0.5, 0.5]),
    thirds: columnZones([1 / 3, 1 / 3, 1 / 3]),
    sidebars: columnZones([0.25, 0.5, 0.25]),
    quarters: gridZones(2, 2),
    sixths: gridZones(3, 2)
};

var PRESET_IDS = ["kde", "halves", "thirds", "sidebars", "quarters", "sixths"];

var PRESET_NAMES = {
    kde: "Master and stack",
    halves: "Halves",
    thirds: "Thirds",
    sidebars: "Wide centre",
    quarters: "Quarters",
    sixths: "Six tiles"
};

var PRESET_ICONS = {
    kde: "dashboard",
    halves: "vertical_split",
    thirds: "view_column",
    sidebars: "view_week",
    quarters: "grid_view",
    sixths: "view_module",
    custom: "draw"
};

// A hand-drawn layout has no entry above and is the only thing an unknown id
// can be, since the settings page writes "custom" for exactly that.
function presetName(id) {
    return PRESET_NAMES[id] ?? "Custom";
}

function presetIcon(id) {
    return PRESET_ICONS[id] ?? "grid_view";
}

// Custom layouts carry their own zones, so an unknown id has to resolve to
// something rather than leaving the overlay empty.
function presetZones(id) {
    var zones = PRESETS[id] ?? PRESETS.kde;
    return sanitizeZones(zones);
}

// Zones for a monitor, honouring its per-monitor entry and falling back to the
// global default preset. `monitors` is the raw config list.
function zonesForMonitor(monitors, name, defaultPreset) {
    var list = monitors ? Array.from(monitors) : [];
    for (var i = 0; i < list.length; i++) {
        var entry = list[i];
        if (!entry || entry.name !== name) continue;
        if (entry.preset === "custom") return sanitizeZones(entry.zones);
        return presetZones(entry.preset ?? defaultPreset);
    }
    return presetZones(defaultPreset);
}

function gapsForMonitor(monitors, name, fallback) {
    var list = monitors ? Array.from(monitors) : [];
    for (var i = 0; i < list.length; i++) {
        var entry = list[i];
        if (entry && entry.name === name && entry.gapsOverride) return normalizeGaps(entry.gapsOverride);
    }
    return normalizeGaps(fallback);
}
