/* TransparentWorld.qml — Shigurui Visual Substrate
 * =====================================================
 * Singleton token system for the "Transparent World" aesthetic.
 *
 * 透き通る世界 — Sukitōru Sekai
 * The Transparent World is not blur. It is perfect clarity.
 * The ability to see through surfaces — perceiving internal structure,
 * blood flow, muscle contractions, the hidden truth beneath the visible.
 * Depth is achieved through layered darkness and precise light,
 * not gaussian smear. Every edge is sharp. Every accent is surgical.
 *
 * Design principles:
 *   · Obsidian depth — dark substrates that recede, not obscure
 *   · Bioluminescent precision — accent colors as living light, not decoration
 *   · Sharp borders — 1px crisp lines, not blurred halos
 *   · Shadow glow — depth through shadow, never through blur
 *   · Crystalline text — maximum legibility, zero softening
 *
 * Usage:
 *   import "." as TW
 *   color: TW.TransparentWorld.resolveAccent(obeliskMode, discipline, intelMode, isInferring)
 *   layer.effect: TW.TransparentWorld.glowEffect(morphColor)  // shadow only
 *
 * All components reference this singleton — one change propagates everywhere.
 */
pragma Singleton
import QtQuick

QtObject {
    id: theme

    // ── Glass substrate ───────────────────────────────────────────────
    // Obsidian black — deep but not opaque. Depth through darkness, not blur.
    readonly property color glassBase:        Qt.rgba(0.039, 0.039, 0.039, 0.72)
    readonly property color glassBaseDense:   Qt.rgba(0.039, 0.039, 0.039, 0.88)  // overlays, cards
    readonly property color glassBaseLight:   Qt.rgba(0.039, 0.039, 0.039, 0.45)  // hover states
    readonly property color glassBaseSolid:   Qt.rgba(0.016, 0.016, 0.020, 0.97)  // terminal, void
    readonly property real  glassBorderAlpha: 0.35   // default border opacity
    readonly property real  glassBorderFocus: 0.60   // focused/active border opacity
    readonly property int   glassRadius:      12
    readonly property int   glassRadiusLarge: 16
    readonly property int   glassRadiusSmall: 8

    // ── Shadow depth tokens — depth through shadow, never blur ────────
    // Use these to build MultiEffect shadow configs.
    // Rule: layer.effect on a component = shadow only. No blurEnabled.
    readonly property real  shadowBlur:       0.85   // MultiEffect shadowBlur (0–1)
    readonly property int   shadowOffsetY:    6      // px vertical offset
    readonly property real  shadowAlpha:      0.25   // base shadow opacity
    readonly property real  shadowAlphaFocus: 0.45   // focused/active shadow opacity

    // ── Typography ────────────────────────────────────────────────────
    // Base: 14px. All sizes are semantic — use tokens, never hardcode.
    //
    // Scale (ascending):
    //   fontSizeMicro   9   timestamps, ghost decorations, faint hints
    //   fontSizeHint   10   tooltips, secondary meta, hover-only text
    //   fontSizeBadge  11   status chips, tier labels, badge text
    //   fontSizeLabel  12   field names, section sub-labels, captions
    //   fontSizeBase   14   ← baseline — body text, data readouts, chat
    //   fontSizeTitle  16   panel headers, ROM titles, primary labels
    //   fontSizeGlyph  20   icon glyphs, sigils, decorative symbols
    //
    // Exceptions (do not remap):
    //   Codex editor text stays at 13 (code density requirement)
    //   Display glyphs ≥22 are intentional visual anchors
    readonly property string fontFamily:     "3270 Nerd Font Mono, Fira Code"
    readonly property string fontFamilyMono: "3270 Nerd Font Mono, Fira Code"
    readonly property int    fontSizeMicro:       9   // timestamps, ghost decorations
    readonly property int    fontSizeHint:        10   // tooltips, secondary meta
    readonly property int    fontSizeBadge:       11   // chips, tier labels, badges
    readonly property int    fontSizeLabel:       12   // field names, captions
    readonly property int    fontSizeBase:        14   // ← baseline body text
    readonly property int    fontSizeBody:        14   // alias — body text, data readouts
    readonly property int    fontSizeTelemetry:   14   // telemetry data readouts
    readonly property int    fontSizeTitle:       16   // panel headers, ROM titles
    readonly property int    fontSizeGlyph:       20   // icon glyphs, sigils
    // Legacy aliases — kept for backward compat, map to nearest semantic token
    readonly property int    fontSizeMin:         9    // was 11 — now micro floor
    readonly property int    fontSizeTelemetryOld:14   // unchanged

    // Obsidian outline stroke for readability against bright accents
    readonly property color  fontOutlineColor: Qt.rgba(0.039, 0.039, 0.039, 0.50)

    // ── Animation ─────────────────────────────────────────────────────
    readonly property int colorTransition:  350   // ms, InOutQuad for all color changes
    readonly property int fadeTransition:   200   // ms, opacity fades
    readonly property int springTransition: 400   // ms, layout/size changes
    readonly property int snapTransition:   120   // ms, instant-feel snaps

    // ── Hazard Matrix — the accent color system ───────────────────────
    readonly property color accentCognitive:  "#7B2CBF"   // Deep Purple  — default thinking
    readonly property color accentSovereign:  "#FFB000"   // Amber        — ? prefix
    readonly property color accentSystem:     "#00FF41"   // Emerald      — # prefix
    readonly property color accentWater:      "#00B4D8"   // Sky Cerulean — water breathing
    readonly property color accentForge:      "#FF4E00"   // Blood Orange — ! prefix
    readonly property color accentBreach:     "#f43f5e"   // Arterial Red — security alert
    readonly property color accentInferring:  "#00B4D8"   // Cerulean     — Nemotron active

    // Intel fold accents — the 7 Sibyls
    // EYE     / Delphic       / TRUTH      — electric cerulean, truth cuts clean
    // PHANTOM / Hellespontine / POWER      — creative violet, spectral presence
    // BLADE   / Cimmerian     / WISDOM     — hot magenta, wisdom forged in heat
    // SAGE    / Persian       / JUDGMENT   — sun amber, the light that reveals
    // SHROUD  / Erythraean    / LIFE       — bioluminescent teal, life in the deep
    // FORGE   / Tiburtine     / LOVE       — volcanic orange-red, molten creation
    // MIRROR  / Cumaean       / DISCIPLINE — pale lavender, quiet and reflective
    readonly property color accentEye:      "#00C2FF"
    readonly property color accentBlade:    "#FF3CAC"
    readonly property color accentSage:     "#FFB300"
    readonly property color accentMirror:   "#C8B8FF"
    readonly property color accentPhantom:  "#B44FE8"
    readonly property color accentShroud:   "#00FFC8"
    readonly property color accentForgeFold:"#FF6B35"

    // Semantic status colors — not fold identity, used for ok/warn/error states
    readonly property color accentOk:    "#4ade80"   // generic success / up / healthy
    readonly property color accentWarn:  "#fbbf24"   // warning / degraded
    // accentBreach (#f43f5e) serves as the semantic error/down color

    // Breathing style accents
    readonly property color _accentCelestial: "#ffffff" // placeholder, handled by ArOrchestrator prismatic logic
    readonly property var styleAccents: ({
        "sun":         "#f59e0b",
        "moon":        "#818cf8",
        "celestial":   "#ffffff",
        "concentrate": "#f59e0b"
    })

    // Discipline accents
    readonly property var disciplineAccents: ({
        "shroud":  "#818cf8",
        "obanai":  "#d946ef",
        "tengen":  "#00B4D8",
        "shinobu": "#4ade80"
    })

    // Intel mode accents
    readonly property var modeAccents: ({
        "eye":     "#4ade80",
        "blade":   "#00B4D8",
        "sage":    "#9B1FA0",
        "mirror":  "#6366f1",
        "forge":   "#f59e0b",
        "phantom": "#f43f5e",
        "shroud":  "#818cf8",
        "dormant": "#00B4D8"
    })

    // ── resolvePrismatic — Prismatic Gradient, the single source of truth ──
    // The canonical color resolver for the entire system.
    // All components should call this or read ArOrchestrator.prismaticColor.
    //
    // Priority chain (highest → lowest):
    //   breach > discipline > modality > obeliskMode > anticipatedStyle
    //   > breathingStyle > intelMode > cognitive default
    function resolvePrismatic(obeliskMode, activeDiscipline, intelMode, breathingStyle,
                                isInferring, isBreach, activeModality, anticipatedStyle) {
        if (isBreach)                          return accentBreach
        if (activeDiscipline === "shroud")     return Qt.color(disciplineAccents["shroud"])
        if (activeDiscipline === "obanai")     return Qt.color(disciplineAccents["obanai"])
        if (activeDiscipline === "tengen")     return Qt.color(disciplineAccents["tengen"])
        if (activeDiscipline === "shinobu")    return Qt.color(disciplineAccents["shinobu"])
        if (activeModality === "reflex")       return accentBreach
        if (activeModality === "sovereign")    return accentSovereign
        if (activeModality === "architect")    return Qt.color("#a78bfa")
        if (obeliskMode === "tactical" || obeliskMode === "applet") return accentCognitive
        if (obeliskMode === "forge")           return Qt.color(styleAccents["moon"])
        if (obeliskMode === "system")          return accentSystem
        if (obeliskMode === "sovereign")       return accentSovereign
        if (obeliskMode === "war")             return accentBreach
        if (anticipatedStyle && anticipatedStyle !== "")
            return Qt.color(styleAccents[anticipatedStyle] ?? accentWater)
        if (obeliskMode === "breathing" || (breathingStyle && breathingStyle !== ""))
            return Qt.color(styleAccents[breathingStyle] ?? accentWater)
        if (intelMode && intelMode !== "dormant")
            return Qt.color(modeAccents[intelMode] ?? accentWater)
        if (isInferring) return accentInferring
        return accentCognitive
    }

    // ── resolveAccent — delegates to resolvePrismatic (backward compat) ──
    function resolveAccent(obeliskMode, activeDiscipline, intelMode, breathingStyle, isInferring, isBreach) {
        return resolvePrismatic(obeliskMode, activeDiscipline, intelMode, breathingStyle,
                                isInferring, isBreach, "", "")
    }

    // ── resolveHazardColor — Speculum hazard color priority system ───────
    // Priority: discipline > obelisk mode > breathing style > legacy threat
    // Matches SpeculumCore.qml hazard color logic exactly for consistency
    function resolveHazardColor(activeDiscipline, obeliskMode, breathingStyle, breachAlert, combatMode, isExecuting, armedMode) {
        // Discipline overrides (highest priority)
        if (activeDiscipline === "shroud")  return Qt.color(accentShroud)
        if (activeDiscipline === "obanai")  return Qt.color(disciplineAccents["obanai"] ?? accentWater)
        if (activeDiscipline === "tengen")  return Qt.color(disciplineAccents["tengen"] ?? accentWater)
        if (activeDiscipline === "shinobu") return Qt.color(disciplineAccents["shinobu"] ?? accentWater)

        // Obelisk mode override — live preview while typing
        if (obeliskMode === "sovereign")     return accentSovereign
        if (obeliskMode === "system")        return accentSystem
        if (obeliskMode === "forge")         return accentMirror
        if (obeliskMode === "tactical")      return accentSage

        // Trinity styles
        if (breathingStyle === "sun")        return accentSovereign
        if (breathingStyle === "moon")       return Qt.color(styleAccents["moon"])
        if (breathingStyle === "celestial")  return _accentCelestial

        // Legacy threat-based colors (fallback)
        if (breachAlert || combatMode)      return accentBreach
        if (isExecuting || armedMode)       return accentForge
        return accentWater  // default cyan
    }

    // ── resolveNodeColor — single source of truth for node colors ────
    // Used by SpeculumSigils, SanctumNodeSystem hover overlay, Tier2Arc, EnvironmentRing
    // tier: 1=full, 2=65% sat, 3=30% sat
    readonly property var _nodeBaseColors: ({
        // Existing surface types
        "target":      "#f43f5e",
        "vuln":        "#f59e0b",
        "recon":       "#00B4D8",
        "history":     "#818cf8",
        "local":       "#4ade80",
        "suggested":   "#9B1FA0",
        "curated":     "#FFB000",
        "system":      "#6366f1",
        "wifi":        "#00B4D8",
        "lan":         "#4ade80",
        "egress":      "#FF4E00",
        "service":     "#86efac",
        "bluetooth":   "#a78bfa",
        // Dark web types (new)
        "darkweb":     "#8B0000",   // deep crimson — Rui's blood
        "onion":       "#8B0000",   // .onion nodes
        "market":      "#6B0020",   // blood maroon — dark marketplaces
        "forum":       "#7B1020",   // dark rose — dark forums
        "circuit":     "#9B1FA0",   // onion purple — Tor circuits
        "tor":         "#9B1FA0",   // Tor nodes
        "silk":        "#6B0020",   // Silk Road / Rui spider
        // IPFS / distributed types (new)
        "ipfs":        "#6366f1",   // sage violet — Wisteria's fold
        "wisteria":    "#6366f1",   // Wisteria vault nodes
        "p2p":         "#a78bfa",   // muted lavender — peer mesh
        "distributed": "#a78bfa"    // distributed network nodes
    })

    function resolveNodeColor(category, source, status, tier) {
        // Derive effective category
        var cat = category || ""
        if (!cat) {
            if (source === "curated")        cat = "curated"
            else if (source === "suggested") cat = "suggested"
            else if (source === "wifi")      cat = "wifi"
            else if (source === "lan")       cat = "lan"
            else if (source === "egress")    cat = "egress"
            else if (source === "local")     cat = "local"
            // Dark web sources
            else if (source === "darkweb")   cat = "darkweb"
            else if (source === "onion")     cat = "onion"
            else if (source === "silk")      cat = "silk"
            else if (source === "tor")       cat = "tor"
            // IPFS / distributed sources
            else if (source === "ipfs")      cat = "ipfs"
            else if (source === "wisteria")  cat = "wisteria"
            else if (source === "p2p")       cat = "p2p"
            else {
                if (status === "vuln" || status === "compromised") cat = "vuln"
                else cat = "recon"
            }
        }
        var hex = _nodeBaseColors[cat] || "#00B4D8"
        var c   = Qt.color(hex)

        // Tier brightness/saturation scaling
        var t = tier || 1
        if (t === 2) {
            var grey2 = (c.r + c.g + c.b) / 3
            return Qt.rgba(c.r * 0.65 + grey2 * 0.35,
                           c.g * 0.65 + grey2 * 0.35,
                           c.b * 0.65 + grey2 * 0.35, 1.0)
        }
        if (t === 3) {
            var grey3 = (c.r + c.g + c.b) / 3
            return Qt.rgba(c.r * 0.30 + grey3 * 0.70,
                           c.g * 0.30 + grey3 * 0.70,
                           c.b * 0.30 + grey3 * 0.70, 1.0)
        }
        return c
    }

    // Node category color constants (full saturation, Tier 1)
    readonly property color nodeColorTarget:    Qt.color("#f43f5e")
    readonly property color nodeColorVuln:      Qt.color("#f59e0b")
    readonly property color nodeColorRecon:     Qt.color("#00B4D8")
    readonly property color nodeColorHistory:   Qt.color("#818cf8")
    readonly property color nodeColorLocal:     Qt.color("#4ade80")
    readonly property color nodeColorSuggested: Qt.color("#9B1FA0")
    readonly property color nodeColorCurated:   Qt.color("#FFB000")
    readonly property color nodeColorSystem:    Qt.color("#6366f1")
    readonly property color nodeColorWifi:      Qt.color("#00B4D8")
    readonly property color nodeColorLan:       Qt.color("#4ade80")
    readonly property color nodeColorEgress:    Qt.color("#FF4E00")
    // Dark web node colors (new)
    readonly property color nodeColorDarkweb:   Qt.color("#8B0000")   // deep crimson — Rui's blood
    readonly property color nodeColorOnion:     Qt.color("#8B0000")   // .onion nodes
    readonly property color nodeColorMarket:    Qt.color("#6B0020")   // blood maroon — dark markets
    readonly property color nodeColorTor:       Qt.color("#9B1FA0")   // onion purple — Tor circuits
    // IPFS / distributed node colors (new)
    readonly property color nodeColorIpfs:      Qt.color("#6366f1")   // sage violet — Wisteria's fold
    readonly property color nodeColorWisteria:  Qt.color("#6366f1")   // Wisteria vault
    readonly property color nodeColorP2p:       Qt.color("#a78bfa")   // muted lavender — peer mesh

    // ── glassShadow — shadow-only depth helper ────────────────────────
    // Returns a color for MultiEffect shadowColor at the right intensity.
    // Use with shadowEnabled: true, blurEnabled: false.
    // intensity: 0.0–1.0, defaults to shadowAlpha
    function glassShadow(accentColor, intensity) {
        if (!accentColor || accentColor === "") return Qt.rgba(0, 0, 0, 0)
        var c = Qt.color(accentColor)
        var a = (intensity !== undefined) ? intensity : shadowAlpha
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // ── bloomColor — neon glow helper ─────────────────────────────────
    function bloomColor(accent, intensity) {
        if (!accent || accent === "") return Qt.rgba(0, 0, 0, 0)
        var c = Qt.color(accent)
        var a = intensity !== undefined ? intensity : 0.45
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // ── Surface helpers ───────────────────────────────────────────────
    readonly property color shimmerTop:    Qt.rgba(1, 1, 1, 0.055)
    readonly property color shimmerLeft:   Qt.rgba(1, 1, 1, 0.035)
    readonly property color divider:       Qt.rgba(1, 1, 1, 0.07)
    readonly property color textPrimary:   Qt.rgba(0.90, 0.95, 1.00, 0.88)
    readonly property color textSecondary: Qt.rgba(0.80, 0.88, 0.95, 0.45)
    readonly property color textDim:       Qt.rgba(0.75, 0.85, 0.92, 0.22)
    readonly property color textGhost:     Qt.rgba(0.75, 0.85, 0.92, 0.12)

    // ── Ghost glow base text ──────────────────────────────────────────
    // Near-white with faintest cerulean luminance — alive without competing.
    readonly property color ghostText:      Qt.rgba(0.90, 0.95, 1.00, 0.82)
    readonly property color ghostTextDim:   Qt.rgba(0.80, 0.88, 0.95, 0.45)
    readonly property color ghostTextFaint: Qt.rgba(0.75, 0.85, 0.92, 0.22)

    // Lexical color tokens ──────────────────────────────────────────
    // Single source of truth — all components use these for consistent
    // semantic highlighting across obelisk, terminal, conduit, reticle.
    readonly property var lexColors: ({
        // Vulnerability / CVE
        "cve":        "#F59E0B",   // amber
        "cveCritical":"#F43F5E",   // arterial red — CVSS 9+
        "cveHigh":    "#FB923C",   // orange — CVSS 7–9
        // Network
        "ip":         "#C8E1DC",   // ghost teal-white
        "ipLocked":   "#00B4D8",   // cerulean — locked/active target
        "mac":        "#67E8F9",   // sky cyan — MAC addresses
        "port":       "#67E8F9",   // sky cyan
        "hostname":   "#A78BFA",   // lavender — hostnames distinct from URLs
        "url":        "#C4B5FD",   // lighter lavender — full URLs
        // HTTP status families
        "http2xx":    "#86EFAC",   // green
        "http3xx":    "#FCD34D",   // yellow
        "http4xx":    "#FCA5A5",   // rose
        "http5xx":    "#F87171",   // red
        // Tool sigils
        "sigilPlus":  "#86EFAC",   // [+] green
        "sigilMinus": "#F87171",   // [-] red
        "sigilWarn":  "#FCD34D",   // [!] yellow
        "sigilInfo":  "#67E8F9",   // [*] cyan
        "sigilMisc":  "#C4B5FD",   // [~] violet
        "sigilINF":   "#67E8F9",
        "sigilWRN":   "#FCD34D",
        "sigilERR":   "#F87171",
        "sigilCRIT":  "#F43F5E",
        // Severity levels
        "sevCritical":"#F43F5E",   // CRITICAL — arterial red
        "sevHigh":    "#FB923C",   // HIGH — orange
        "sevMedium":  "#FCD34D",   // MEDIUM — yellow
        "sevLow":     "#86EFAC",   // LOW — ghost green
        "sevInfo":    "#67E8F9",   // INFO — cyan
        // Crypto
        "hash":       "#A78BFA",   // dim purple
        "memAddr":    "#9B1FA0",   // blood violet — 0x hex addresses
        // JSON
        "jsonKey":    "#67E8F9",   // cerulean — "key": patterns
        // Filesystem
        "path":       "#D7CDE1",   // ghost lavender italic
        // Timestamps
        "timestamp":  "#ffffff30", // ghost dim — [HH:MM:SS]
        // Outcome keywords
        "success":    "#BED7C3",   // ghost green-white
        "error":      "#8B0000",   // arterial red
        // Structural
        "bracket":    "#ffffff20", // ghost dim white (bracket chars)
        "bracketInner": "#ffffff45",
        // Sigil chars
        "sigil":      "#6B0020",   // blood maroon (◈ ⟡ ∿)
        // Numbers
        "number":     "#C8C3D7",   // ghost grey-white
        // Prompt
        "prompt":     "#6B0020"    // ∿ prompt glyph
    })

    // ── Theme change signal — hook for future runtime theme switching ──
    signal themeChanged(string themeName)
    // Design contract: when daemonState === "dead", all prediction
    // consumers MUST fall back to prefix/fuzzy matching only.
    // No Nemotron calls, no usage weighting, no semantic ranking.
    //
    // Canonical offline pill sets — keyed by query context.
    // Obelisk._staticFallbackPills() delegates here.
    // Any component needing offline suggestions calls this function.
    //
    // Tiers (in priority order when daemon is dead):
    //   1. Prefix match against availableMacros (< 1ms, always available)
    //   2. Context-aware static pills from this function
    //   3. Generic status/help fallback
    function offlinePills(query, detectedIp) {
        var q = (query || "").toLowerCase()
        var ip = detectedIp || ""
        if (q.includes("scan") || q.includes("recon"))
            return [{ label: "DEEP SCAN", cmd: "/recon " + ip },
                    { label: "NUCLEI",    cmd: "/strike:nuclei " + ip }]
        if (q.includes("exploit") || q.includes("strike"))
            return [{ label: "SYNDICATE", cmd: "/strike:syndicate " + ip },
                    { label: "MONITOR",   cmd: "/strike:monitor " + ip }]
        if (q.includes("shroud") || q.includes("vpn"))
            return [{ label: "SHROUD ON",  cmd: "/shroud toggle" },
                    { label: "THE SHROUD", cmd: "/intel:shroud" }]
        if (q.includes("forge") || q.includes("playbook"))
            return [{ label: "FORGE",     cmd: "/forge:playbook" },
                    { label: "TRAINING",  cmd: "/forge:forge" }]
        if (q.startsWith("@"))
            return [{ label: "CONDUIT",   cmd: "@conduit" },
                    { label: "HUB",       cmd: "@hub" }]
        return [{ label: "STATUS", cmd: "/status" },
                { label: "HELP",   cmd: "/help" }]
    }
    // Returns HTML-rich text. Call from any component that renders
    // terminal / command output. Strips ANSI before processing.
    function lexHighlight(raw, lockedTarget) {
        var s = _stripAnsi(raw)
        s = s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")

        // Timestamps [HH:MM:SS] or [YYYY-MM-DD HH:MM:SS]
        s = s.replace(/\[(\d{2}:\d{2}:\d{2}(?:\.\d+)?)\]/g,
            '<font color="' + lexColors["timestamp"] + '">[$1]</font>')
        s = s.replace(/\[(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}[^\]]*)\]/g,
            '<font color="' + lexColors["timestamp"] + '">[$1]</font>')

        // CVE IDs — severity-weighted by CVSS if present
        s = s.replace(/\b(CVE-\d{4}-\d{4,7})\b/g,
            '<font color="' + lexColors["cve"] + '"><b>$1</b></font>')

        // Severity levels — graduated color
        s = s.replace(/\b(CRITICAL)\b/g,
            '<font color="' + lexColors["sevCritical"] + '"><b>$1</b></font>')
        s = s.replace(/\b(HIGH)\b/g,
            '<font color="' + lexColors["sevHigh"] + '"><b>$1</b></font>')
        s = s.replace(/\b(MEDIUM)\b/g,
            '<font color="' + lexColors["sevMedium"] + '"><b>$1</b></font>')
        s = s.replace(/\b(LOW)\b/g,
            '<font color="' + lexColors["sevLow"] + '">$1</font>')
        s = s.replace(/\b(INFO)\b/g,
            '<font color="' + lexColors["sevInfo"] + '">$1</font>')

        // Hex memory addresses — 0x prefix
        s = s.replace(/\b(0x[0-9a-fA-F]{4,16})\b/g,
            '<font color="' + lexColors["memAddr"] + '">$1</font>')

        // Hashes (32–64 hex chars) — before URLs to avoid double-match
        s = s.replace(/\b([0-9a-fA-F]{32,64})\b/g,
            '<font color="' + lexColors["hash"] + '">$1</font>')

        // URLs / domains (before IP to avoid double-match)
        s = s.replace(/(https?:\/\/[^\s&lt;&gt;"]+)/g,
            '<font color="' + lexColors["url"] + '"><u>$1</u></font>')

        // Hostnames — word.word or word.word.tld (not full URLs, not IPs)
        s = s.replace(/\b([a-zA-Z][a-zA-Z0-9\-]*\.[a-zA-Z]{2,}(?:\.[a-zA-Z]{2,})?)\b/g,
            function(m) {
                // Skip if already inside a URL tag
                return '<font color="' + lexColors["hostname"] + '">' + m + '</font>'
            })

        // MAC addresses
        s = s.replace(/\b([0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5})\b/g,
            '<font color="' + lexColors["mac"] + '"><b>$1</b></font>')

        // IPs — locked target gets cerulean, others get ghost teal
        s = s.replace(/\b(\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?)\b/g,
            function(m) {
                var col = (lockedTarget && m.startsWith(lockedTarget))
                    ? lexColors["ipLocked"]
                    : lexColors["ip"]
                return '<font color="' + col + '"><b>' + m + '</b></font>'
            })

        // Port/protocol combos
        s = s.replace(/\b(\d{1,5})\/(tcp|udp|open|closed|filtered)\b/gi,
            '<font color="' + lexColors["port"] + '"><b>$1/$2</b></font>')

        // HTTP status codes
        s = s.replace(/\b(200|201|204)\b/g,
            '<font color="' + lexColors["http2xx"] + '"><b>$1</b></font>')
        s = s.replace(/\b(301|302|307|308)\b/g,
            '<font color="' + lexColors["http3xx"] + '"><b>$1</b></font>')
        s = s.replace(/\b(400|401|403|404|405|429)\b/g,
            '<font color="' + lexColors["http4xx"] + '"><b>$1</b></font>')
        s = s.replace(/\b(500|502|503|504)\b/g,
            '<font color="' + lexColors["http5xx"] + '"><b>$1</b></font>')

        // JSON keys — "key": pattern
        s = s.replace(/"([a-zA-Z_][a-zA-Z0-9_]*)"\s*:/g,
            '<font color="' + lexColors["jsonKey"] + '">"$1"</font>:')

        // Tool sigils
        s = s.replace(/\[(\+)\]/g,
            '<font color="' + lexColors["sigilPlus"]  + '"><b>[+]</b></font>')
        s = s.replace(/\[(-)\]/g,
            '<font color="' + lexColors["sigilMinus"] + '"><b>[-]</b></font>')
        s = s.replace(/\[(!)\]/g,
            '<font color="' + lexColors["sigilWarn"]  + '"><b>[!]</b></font>')
        s = s.replace(/\[(\*)\]/g,
            '<font color="' + lexColors["sigilInfo"]  + '"><b>[*]</b></font>')
        s = s.replace(/\[(~)\]/g,
            '<font color="' + lexColors["sigilMisc"]  + '"><b>[~]</b></font>')
        s = s.replace(/\[(INF)\]/g,
            '<font color="' + lexColors["sigilINF"]   + '">[INF]</font>')
        s = s.replace(/\[(WRN)\]/g,
            '<font color="' + lexColors["sigilWRN"]   + '">[WRN]</font>')
        s = s.replace(/\[(ERR)\]/g,
            '<font color="' + lexColors["sigilERR"]   + '">[ERR]</font>')
        s = s.replace(/\[(CRITICAL)\]/g,
            '<font color="' + lexColors["sigilCRIT"]  + '"><b>[CRITICAL]</b></font>')

        // Filesystem paths
        s = s.replace(/((?:\/|~)[a-zA-Z0-9_.~\-]+(?:\/[a-zA-Z0-9_.~\-]+)*(?::\d+)*)/g,
            '<font color="' + lexColors["path"] + '"><i>$1</i></font>')

        // Success keywords
        s = s.replace(/\b(SUCCESS|OK|ACTIVE|STABLE|DONE|UP|PASS|FOUND|OPEN)\b/g,
            '<font color="' + lexColors["success"] + '"><b>$1</b></font>')

        // Error keywords
        s = s.replace(/\b(ERROR|FAIL|DENIED|FATAL|DOWN|WARNING|WARN|KILLED|CLOSED|FILTERED)\b/gi,
            '<font color="' + lexColors["error"] + '"><b>$1</b></font>')

        // Brackets
        s = s.replace(/\[([^\]]*)\]/g,
            '<font color="' + lexColors["bracket"] + '">[</font>' +
            '<font color="' + lexColors["bracketInner"] + '">$1</font>' +
            '<font color="' + lexColors["bracket"] + '">]</font>')

        // Sigil chars
        s = s.replace(/(◈|⟡|∿)/g,
            '<font color="' + lexColors["sigil"] + '">$1</font>')

        // Numbers (not already colored)
        s = s.replace(/(?<![#\w])(\d+)(?!\w)/g,
            '<font color="' + lexColors["number"] + '">$1</font>')

        return s
    }

    // ── colorToHue — extract HSV hue (0.0–1.0) from a color ──────────
    // Used by ShiguruiSanctum shader uniforms which expect normalized hue.
    function colorToHue(c) {
        var col = Qt.color(c)
        var r = col.r, g = col.g, b = col.b
        var mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn
        if (d < 0.001) return 0.0
        var h
        if      (mx === r) h = ((g - b) / d + (g < b ? 6 : 0))
        else if (mx === g) h = ((b - r) / d + 2)
        else               h = ((r - g) / d + 4)
        return h / 6.0
    }

    // Precomputed fold hues for sanctum shader uniforms
    readonly property real hueEye:     colorToHue(accentEye)
    readonly property real hueBlade:   colorToHue(accentBlade)
    readonly property real hueSage:    colorToHue(accentSage)
    readonly property real hueMirror:  colorToHue(accentMirror)
    readonly property real hueForge:   colorToHue(accentForgeFold)
    readonly property real huePhantom: colorToHue(accentPhantom)
    readonly property real hueShroud:  colorToHue(accentShroud)
    readonly property real hueWater:   colorToHue(accentWater)
    readonly property real hueSovereign: colorToHue(accentSovereign)
    function _stripAnsi(s) {
        return s.replace(/\x1b\[[0-9;]*[mGKHFABCDJsu]/g, "")
                .replace(/\x1b\][^\x07]*\x07/g, "")
                .replace(/\x1b[()][AB012]/g, "")
                .replace(/\r/g, "")
    }
}
