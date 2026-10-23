.pragma library

// The plugin's FontBuilder in JS: an immutable chain over a font spec that build()
// turns into a font with Qt.font(). Weight and size also set the wght and opsz axes.
function make(spec) {
    const s = Object.assign({}, spec, { variableAxes: Object.assign({}, spec.variableAxes) });
    const next = change => {
        const n = Object.assign({}, s, { variableAxes: Object.assign({}, s.variableAxes) });
        change(n);
        return make(n);
    };
    const axis = (tag, value) => next(n => n.variableAxes[tag] = Number(value));
    return {
        family: family => next(n => n.family = family),
        size: pointSize => next(n => {
            const p = pointSize > 0 ? Math.trunc(pointSize) : 1;
            n.pointSize = p;
            n.variableAxes.opsz = p;
        }),
        weight: weight => next(n => {
            n.weight = weight;
            n.variableAxes.wght = weight;
        }),
        italic: on => next(n => n.italic = on === undefined ? true : on),
        // shortcut: only absolute spacing; the plugin's percentage mode is not used here
        letterSpacing: spacing => next(n => n.letterSpacing = spacing),
        capitalisation: cap => next(n => n.capitalization = cap),
        vaxis: axis,
        vaxes: axes => next(n => Object.assign(n.variableAxes, axes)),
        fill: v => axis("FILL", v),
        grade: v => axis("GRAD", v),
        width: v => axis("wdth", v),
        scale: factor => make(s).size(Math.trunc((s.pointSize || 0) * factor)),
        spec: () => s,
        build: () => Qt.font(s)
    };
}

// FontStyleBase::buildFont: one size of a style from its config node
function specFor(cfg, fallbackFamily, scale) {
    const spec = { variableAxes: {} };
    const family = cfg.family || fallbackFamily;
    if (family)
        spec.family = family;
    const size = Math.trunc(cfg.size * scale);
    spec.pointSize = size > 0 ? size : 1;
    spec.variableAxes.opsz = spec.pointSize;
    spec.weight = cfg.weight;
    spec.variableAxes.wght = cfg.weight;
    spec.italic = cfg.italic;
    for (const k in cfg.vaxes)
        spec.variableAxes[k] = Number(cfg.vaxes[k]);
    return spec;
}
