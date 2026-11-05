.pragma library

// The menu's and result cards' looks. "transparent" is the original liquid glass
// that adapts to whatever is behind it (and is the default). The coloured themes
// lay a strong tint over the same glass: `tint` is the body colour, `accent` the
// hovered slice and the hub ring, `ink` the label colour. "matugen" takes all
// three from Ryoku's live colour scheme (Theme), so it follows the wallpaper.

const THEMES = [
    { id: "transparent", name: "Transparent" },
    { id: "matugen", name: "Matugen" },
    { id: "midnight", name: "Midnight", tint: "#1a1630", accent: "#8b7cf6", ink: "#ffffff" },
    { id: "ocean", name: "Ocean", tint: "#0b2536", accent: "#38bdf8", ink: "#ffffff" },
    { id: "forest", name: "Forest", tint: "#10261b", accent: "#4ade80", ink: "#ffffff" },
    { id: "rose", name: "Rose", tint: "#331422", accent: "#fb7185", ink: "#ffffff" },
    { id: "ember", name: "Ember", tint: "#2e170c", accent: "#fb923c", ink: "#ffffff" },
    { id: "graphite", name: "Graphite", tint: "#1d1e22", accent: "#d4d4d8", ink: "#ffffff" },
    { id: "snow", name: "Snow", tint: "#eef0f5", accent: "#4f46e5", ink: "#1c1430" }
];

// How much of the coloured themes' tint covers the refracted backdrop, and how
// much accent lights the hovered slice (glass.frag: mix(col, accent, hv * 0.55)).
const TINT_AMOUNT = 0.8;
const HOVER_ACCENT = 0.55;
const DARK_INK = "#1c1430";

function byId(id) {
    return THEMES.find(t => t.id === id) || THEMES[0];
}

// -> { id, themed, tint, accent, ink, amount }. `scheme` is Ryoku's Theme
// singleton (only read for "matugen"). Colours stay strings or QML colors.
function resolve(id, scheme) {
    const t = byId(id);
    if (t.id === "transparent")
        return { id: t.id, themed: false, tint: "#000000", accent: "#ffffff", ink: "#ffffff", amount: 0 };
    if (t.id === "matugen") {
        if (!scheme)
            return resolve("midnight", null);
        return { id: t.id, themed: true, tint: scheme.cardTop, accent: scheme.accent, ink: scheme.bright,
                 amount: TINT_AMOUNT };
    }
    return { id: t.id, themed: true, tint: t.tint, accent: t.accent, ink: t.ink, amount: TINT_AMOUNT };
}

// ---- contrast -------------------------------------------------------------------
function _rgb(c) {
    if (typeof c === "string") {
        const h = c.replace("#", "");
        const v = h.length === 8 ? h.slice(2) : h;   // #aarrggbb from QML colors
        return [parseInt(v.slice(0, 2), 16) / 255, parseInt(v.slice(2, 4), 16) / 255, parseInt(v.slice(4, 6), 16) / 255];
    }
    return [c.r, c.g, c.b];
}

// WCAG relative luminance and contrast ratio.
function luminance(c) {
    const lin = x => x <= 0.04045 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
    const [r, g, b] = _rgb(c).map(lin);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
function contrast(a, b) {
    const la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

// The hovered slice's colour, roughly as glass.frag paints it.
function hoverColor(look) {
    const t = _rgb(look.tint), a = _rgb(look.accent);
    const m = t.map((x, i) => x + (a[i] - x) * HOVER_ACCENT);
    const hex = v => ("0" + Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16)).slice(-2);
    return "#" + m.map(hex).join("");
}

// Label colour for the hovered slice: white, or dark ink when the lit slice is light
// (a light Matugen scheme, Snow, a pale accent). Transparent keeps white.
function hoverInk(look) {
    if (!look || !look.themed)
        return "#ffffff";
    const bg = hoverColor(look);
    return contrast("#ffffff", bg) >= contrast(DARK_INK, bg) ? "#ffffff" : DARK_INK;
}
