// .pragma library
//
// Dock geometry, derived once.
//
// Every dock surface (the strip, its buttons, the preview popup, Edit Mode's
// inset reservation) needs to know which screen edge the dock is on and what
// that means for margins, insets, anchors and motion vectors. The answers
// used to be spelled out per widget as top/bottom/left/right literals, which
// was correct at whichever edge the author was looking at and silently wrong
// at the other three - a `Layout.topMargin` is a depth margin at a horizontal
// dock and a stride along a vertical one. The mapping from the configured
// edge to directional amounts lives here, once, named by DIRECTION relative
// to the dock (inward = toward screen centre, outward = toward the screen
// edge), so a widget says what it means instead of where it guessed.
//
// test_dock_position_contract.py polices the dock's tree against re-deriving
// these; keep new derivations here so the contract keeps holding.

const EDGES = ["top", "bottom", "left", "right"];

// Accepts the stored config key (any case, trimmed) and hands back one of
// "top" | "bottom" | "left" | "right". Unknown values fall to "bottom" - the
// dock's default - rather than leaking a garbage edge into every consumer.
function normalizedEdge(edge) {
    const value = String(edge === undefined || edge === null ? "bottom" : edge)
        .trim()
        .toLowerCase();
    return EDGES.indexOf(value) !== -1 ? value : "bottom";
}

// A vertical dock is a column: its strip runs up the screen and its
// thickness runs across it. Everything else branches on this.
function isVertical(edge) {
    return normalizedEdge(edge) === "left" || normalizedEdge(edge) === "right";
}

// Insets/margins named by DIRECTION. `inward` is the amount that eats into
// the dock's depth from the screen-centre side, `outward` the amount from
// the screen-edge side; the other two directions get nothing. At a
// horizontal edge the thickness runs through top/bottom, at a vertical one
// through left/right - which is exactly the swap bare literals kept missing.
function directedSides(edge, inward, outward) {
    const e = normalizedEdge(edge);
    switch (e) {
    case "top":
        return { top: outward, bottom: inward, left: 0, right: 0 };
    case "left":
        return { top: 0, bottom: 0, left: outward, right: inward };
    case "right":
        return { top: 0, bottom: 0, left: inward, right: outward };
    case "bottom":
    default:
        return { top: inward, bottom: outward, left: 0, right: 0 };
    }
}

// Margins along the strip's LONG axis, plus one amount applied across the
// thickness on both sides. `start`/`end` are the two along-axis ends (in
// reading order along the strip), `cross` the thickness direction. Used by
// the separators: they trim along the row and keep the full depth.
function axisMargins(edge, start, end, cross) {
    const e = normalizedEdge(edge);
    if (isVertical(e))
        return { top: start, bottom: end, left: cross, right: cross };
    return { top: cross, bottom: cross, left: start, right: end };
}

// Unit vector pointing from the dock INTO the screen. Lift/bounce offsets
// are magnitudes multiplied by this, so an icon rises out of a bottom dock,
// slides right out of a left one, and never dives into the screen edge.
function inwardVector(edge) {
    switch (normalizedEdge(edge)) {
    case "top":
        return { x: 0, y: 1 };
    case "left":
        return { x: 1, y: 0 };
    case "right":
        return { x: -1, y: 0 };
    case "bottom":
    default:
        return { x: 0, y: -1 };
    }
}

// The side of the dock that faces the screen edge IS its edge. Consumers
// hang running dots and pin popup cards off this side; the name exists so a
// reader can tell "the outward side" from "whatever edge string came in".
function outwardSide(edge) {
    return normalizedEdge(edge);
}

// Which way a popup anchored to the dock should OPEN: away from the dock,
// into the screen. A menu that opens upward from a top dock is drawn off
// the screen; this is the one flip that fixes all four edges.
function popupGravity(edge) {
    switch (normalizedEdge(edge)) {
    case "top":
        return "bottom";
    case "left":
        return "right";
    case "right":
        return "left";
    case "bottom":
    default:
        return "top";
    }
}

// Where the dock's own preview popup hangs off its surface, and the way it
// grows from there: BOTH toward the screen centre, or it opens into the
// screen edge and the compositor clips it. `edges` names the edge(s) of the
// anchor rect to attach to, `gravity` the side(s) of the popup that sit on
// it; a .pragma library has no QML enums in scope, so the names go back for
// the caller to map onto Quickshell's Edges flags.
function popupAnchorSides(edge) {
    switch (normalizedEdge(edge)) {
    case "top":
        return { edges: ["bottom"], gravity: ["top"] };
    case "left":
        return { edges: ["right"], gravity: ["left"] };
    case "right":
        return { edges: ["left"], gravity: ["right"] };
    case "bottom":
    default:
        return { edges: ["top"], gravity: ["bottom"] };
    }
}

// Which screen edge the BAR occupies. `vertical` says the bar is a column;
// for a vertical bar the config's `bar.bottom` flag means the RIGHT edge
// (the bar keeps the same "secondary means right" reading it has
// horizontally). One derivation, because Edit Mode's insets and the bar
// itself must never disagree about where the bar is.
function barEdge(vertical, bottom) {
    if (vertical)
        return bottom ? "right" : "left";
    return bottom ? "bottom" : "top";
}

// The dock layer surface's total thickness across its depth: the body
// height plus the elevation margin (drawn inward, where the shadow lives)
// plus the compositor gap (held outward). Edit Mode reserves this much so
// the reservation matches what `hyprctl layers` reports.
function thickness(bodyHeight, elevationMargin, gapsOut) {
    return (bodyHeight || 0) + (elevationMargin || 0) + (gapsOut || 0);
}
