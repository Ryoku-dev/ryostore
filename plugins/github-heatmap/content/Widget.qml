pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Ryoku.PluginKit.Singletons

// The desktop card: a toolbar (edit user, user, year stepper, total, the hovered
// day, settings, refresh) over a GitHub-style grid, one column per week, with
// optional month and weekday labels, a stats line and a legend. Months can sit
// in separate blocks. The gear opens an in-card settings panel; every option
// there is also in the desktop's right-click menu (manifest metadata.settings),
// both persisted by the service.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    function cfg(k, d) { return service ? service.cfg(k, d) : d; }
    function set(k, v) { if (service) service.setSetting(k, v); }
    function num(k, d, lo, hi) { return Math.max(lo, Math.min(hi, Number(cfg(k, d)))); }

    // ── settings in use ──
    readonly property string range: cfg("range", "year")
    readonly property int months: Math.round(num("months", 12, 1, 12))
    readonly property string palette: cfg("palette", "accent")
    readonly property string colorScale: cfg("colorScale", "github")
    readonly property string shape: cfg("cellShape", "rounded")
    readonly property bool mondayFirst: cfg("weekStart", "sun") === "mon"
    readonly property string monthFormat: cfg("monthFormat", "short")
    readonly property string weekdayStyle: cfg("weekdayStyle", "alt")
    // Future days: dim | hide | show (older installs had a dimFuture toggle).
    readonly property string futureMode: cfg("futureDays", cfg("dimFuture", true) === false ? "show" : "dim")
    readonly property bool showMonths: cfg("showMonths", true) === true
    readonly property bool showWeekdays: cfg("showWeekdays", true) === true
    readonly property bool showToolbar: cfg("showToolbar", true) === true
    readonly property bool showStats: cfg("showStats", true) === true
    readonly property bool showLegend: cfg("showLegend", true) === true
    readonly property bool markToday: cfg("highlightToday", true) === true
    readonly property bool showEmpty: cfg("showEmpty", true) === true
    // Hovered day: a floating tip (default), in the toolbar, or nowhere.
    readonly property string hoverStyle: cfg("hoverStyle", cfg("hoverInfo", true) === false ? "off" : "tooltip")
    readonly property bool showTodayCount: cfg("showTodayCount", true) === true
    readonly property bool showBorder: cfg("showBorder", true) === true
    readonly property bool clickOpens: cfg("clickOpens", false) === true
    readonly property real bgAlpha: num("bgOpacity", 100, 0, 100) / 100
    // glass: the frosted wallpaper plate the calendar uses, when the host hands
    // over its wallpaper mirror; otherwise (or by choice) a solid card.
    readonly property var wpSource: pluginApi && pluginApi.wallpaperSource ? pluginApi.wallpaperSource : null
    readonly property bool glass: cfg("bgStyle", "glass") === "glass" && wpSource !== null

    readonly property int year: service ? service.year : new Date().getFullYear()
    readonly property string user: service ? service.username : ""
    readonly property var days: service ? service.days : ({})

    readonly property real cell: num("cellSize", 11, 6, 20) * s
    readonly property real gap: num("cellGap", 3, 0, 8) * s
    readonly property real monthGap: num("monthGap", 0, 0, 24) * s
    readonly property real cardRadius: num("cardRadius", 14, 0, 24) * s
    readonly property real fs: s * num("textScale", 100, 70, 160) / 100
    readonly property real pad: 12 * s
    readonly property real dayCol: showWeekdays ? (weekdayStyle === "initial" ? 14 : 28) * fs : 0
    // the corner icons show on hover over the start of the months row
    readonly property bool cornerShown: cornerGear && (cardHover.hovered || settingsOpen)
    // With the toolbar hidden the gear sits in the empty corner above the
    // weekday labels; with no corner it gets a strip on the left instead.
    readonly property bool cornerGear: !showToolbar && showMonths && showWeekdays
    readonly property real gearSpace: !showToolbar && !cornerGear ? 30 * s : 0

    // ── range ──
    readonly property string todayIso: _iso(new Date())
    readonly property date startDate: {
        if (range === "last") {
            var t = new Date();
            return new Date(t.getFullYear(), t.getMonth() - months, t.getDate() + 1);
        }
        return new Date(year, 0, 1);
    }
    // In "last" mode the grid ends today; in a year it runs to Dec 31, or to
    // today when future days are hidden.
    readonly property int dayCount: {
        var t = new Date();
        var today = new Date(t.getFullYear(), t.getMonth(), t.getDate());
        var upToToday = Math.round((today - startDate) / 86400000) + 1;
        if (range === "last") return upToToday;
        var full = ((year % 4 === 0 && year % 100 !== 0) || year % 400 === 0) ? 366 : 365;
        return futureMode === "hide" && year === t.getFullYear() ? Math.max(1, upToToday) : full;
    }

    function wd(d) { return mondayFirst ? (d.getDay() + 6) % 7 : d.getDay(); }

    // ── layout: every day's cell position and the month marks ──
    // monthGap 0 is GitHub's continuous grid; above 0 each month is its own
    // block of week columns, set apart by the gap.
    readonly property var layout: {
        var unit = cell + gap;
        var pos = [], marks = [];
        var bx = 0, curKey = -1, li = 0, off = 0, lastCol = -1, lastMarkCol = -99;
        for (var i = 0; i < dayCount; i++) {
            var d = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate() + i);
            var x, colAbs;
            if (monthGap > 0) {
                var key = d.getFullYear() * 12 + d.getMonth();
                if (key !== curKey) {
                    if (curKey !== -1) bx += (lastCol + 1) * unit - gap + monthGap;
                    curKey = key;
                    li = 0;
                    off = wd(d);
                    marks.push({ x: bx, t: monthName(d.getMonth()), first: i === 0, day: d.getDate() });
                }
                var c = Math.floor((li + off) / 7);
                lastCol = c;
                li += 1;
                x = bx + c * unit;
            } else {
                var slot = i + wd(startDate);
                colAbs = Math.floor(slot / 7);
                lastCol = colAbs;
                x = colAbs * unit;
                if (d.getDate() === 1 && colAbs - lastMarkCol >= 3) {
                    marks.push({ x: x, t: monthName(d.getMonth()) });
                    lastMarkCol = colAbs;
                }
            }
            pos.push({ x: x, y: wd(d) * unit, iso: _iso(d) });
        }
        // a first block that starts late in its month is too short to label
        if (monthGap > 0 && marks.length > 1 && marks[0].first && marks[0].day > 21) marks.shift();
        var w = (monthGap > 0 ? bx : 0) + (lastCol + 1) * unit - gap;
        return { pos: pos, marks: marks, w: Math.max(w, 0) };
    }
    readonly property real gridW: layout.w
    // the grid block sits centred when the card is wider than it
    readonly property real gridOffset: Math.max(0, (col.width - dayCol - gridW) / 2)

    // ── stats over the days on show ──
    readonly property var st: {
        var tot = 0, run = 0, best = 0, top = 0, topDate = "", act = 0;
        var p = layout.pos;
        for (var i = 0; i < p.length; i++) {
            var di = days[p[i].iso];
            var c = di ? di.count : 0;
            tot += c;
            if (c > 0) { run += 1; act += 1; } else if (p[i].iso <= todayIso) run = 0;
            if (run > best) best = run;
            if (c > top) { top = c; topDate = p[i].iso; }
        }
        return { total: tot, best: best, top: top, topDate: topDate, active: act };
    }

    property string hoverText: ""
    property real hoverX: 0
    property real hoverY: 0
    readonly property bool barHover: hoverStyle === "bar" && hoverText.length > 0
    property bool editing: field.activeFocus
    property bool settingsOpen: false
    // Which settings sections are unfolded; only the presets start open.
    property var openSections: ({ presets: true })
    function toggleSection(t) {
        var o = JSON.parse(JSON.stringify(openSections));
        o[t] = !o[t];
        openSections = o;
    }

    // ── language: English is the source; Spanish ships alongside. "auto"
    // follows the system locale (LANG), anything else falls back to English.
    readonly property string lang: {
        var l = cfg("language", "auto");
        if (l === "auto") l = Qt.locale().name.slice(0, 2);
        return l === "es" ? "es" : "en";
    }
    readonly property var _es: ({
        "Month blocks": "Bloques por mes",
        "Minimal": "Mínimo",
        "Full": "Completo",
        "Quick styles": "Estilos rápidos",
        "Apply": "Aplicar",
        "Data": "Datos",
        "Period": "Periodo",
        "Year": "Año",
        "Last months": "Últimos meses",
        "Months to show": "Meses a mostrar",
        "Future days": "Días futuros",
        "Dim": "Atenuar",
        "Hide": "Ocultar",
        "Color scale": "Escala de color",
        "Relative to your best": "Relativa a tu máximo",
        "Refresh every": "Actualizar cada",
        "Click opens the day on GitHub": "Clic abre el día en GitHub",
        "Info on hover": "Info al pasar el cursor",
        "In the bar": "En la barra",
        "Floating": "Flotante",
        "Don't show": "No mostrar",
        "Show today's contributions": "Mostrar contribuciones de hoy",
        "Colors and shape": "Colores y forma",
        "Colors": "Colores",
        "Theme": "Tema",
        "Green": "Verde",
        "Blue": "Azul",
        "Purple": "Morado",
        "Pink": "Rosa",
        "Orange": "Naranja",
        "Ice": "Hielo",
        "Shape": "Forma",
        "Rounded": "Redondeado",
        "Square": "Cuadrado",
        "Circle": "Círculo",
        "Empty days": "Días sin actividad",
        "Mark today": "Marcar hoy",
        "Grid": "Cuadrícula",
        "Cell size": "Tamaño de cuadro",
        "Cell spacing": "Espacio entre cuadros",
        "Month spacing": "Separación entre meses",
        "Week starts": "Semana empieza",
        "Sunday": "Domingo",
        "Monday": "Lunes",
        "Labels": "Etiquetas",
        "Months": "Meses",
        "Month format": "Formato de meses",
        "Weekdays": "Días de la semana",
        "Weekday style": "Estilo de días",
        "All": "Todos",
        "Text size": "Tamaño de texto",
        "Card": "Tarjeta",
        "Top bar": "Barra superior",
        "Streaks and record": "Rachas y récord",
        "Legend": "Leyenda",
        "Card border": "Borde del fondo",
        "Background": "Fondo",
        "Glass (like the calendar)": "Cristal (como el calendario)",
        "Solid": "Sólido",
        "Background opacity": "Opacidad del fondo",
        "Card corners": "Esquinas del fondo",
        "Language": "Idioma", "Auto": "Automático",
        "contribution": "contribución", "contributions": "contribuciones",
        "month": "mes", "months": "meses", "today": "hoy",
        "set your username ✎": "pon tu usuario ✎",
        "streak": "racha", "best streak": "mejor racha", "record": "récord",
        "day": "día", "days": "días", "active days": "días activos",
        "less": "menos", "more": "más",
        "bad response": "respuesta inválida", "user not found": "usuario no encontrado",
        "invalid username": "usuario inválido", "network": "sin red"
    })
    function tr(k) { return lang === "es" && _es[k] !== undefined ? _es[k] : k; }
    function trError(e) { return e.indexOf("network:") === 0 ? tr("network") + e.slice(8) : tr(e); }
    readonly property var _months: lang === "es"
        ? ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
        : ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
    function dayNames() {
        return lang === "es" ? ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
                             : ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
    }
    function dayInitials() {
        return lang === "es" ? ["D", "L", "M", "X", "J", "V", "S"] : ["S", "M", "T", "W", "T", "F", "S"];
    }
    readonly property var _palettes: ({
        github: ["#0e4429", "#006d32", "#26a641", "#39d353"],
        blue: ["#0a3069", "#0969da", "#54aeff", "#b6e3ff"],
        purple: ["#3b2370", "#6e40c9", "#a371f7", "#d2a8ff"],
        halloween: ["#631c03", "#bd561d", "#fa7a18", "#fddf68"],
        pink: ["#5c1a3b", "#a8336b", "#e05a9a", "#ffa3cf"],
        ice: ["#0c3b4a", "#11708a", "#2fb3d3", "#a5ecff"]
    })

    function monthName(m, fmt) {
        var f = fmt || monthFormat;
        var n = _months[m];
        if (f === "cap") return n.charAt(0).toUpperCase() + n.slice(1);
        if (f === "initial") return n.charAt(0).toUpperCase();
        if (f === "number") return String(m + 1);
        return n;
    }
    function _iso(d) {
        var m = d.getMonth() + 1, dd = d.getDate();
        return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (dd < 10 ? "0" : "") + dd;
    }
    function _fmt(iso) {
        if (!iso) return "";
        var p = iso.split("-");
        var m = _months[Number(p[1]) - 1];
        return lang === "es" ? Number(p[2]) + " " + m : m.charAt(0).toUpperCase() + m.slice(1) + " " + Number(p[2]);
    }
    function _label(iso, count) {
        return count + " " + tr(count === 1 ? "contribution" : "contributions") + " • " + _fmt(iso);
    }
    function levelOf(di) {
        if (!di || di.count <= 0) return 0;
        if (colorScale === "relative" && st.top > 0) return Math.max(1, Math.ceil(di.count / st.top * 4));
        return di.level;
    }
    function tint(level) {
        if (level <= 0) return showEmpty ? Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.07) : "transparent";
        var l = Math.min(level, 4);
        var p = _palettes[palette];
        if (p) return p[l - 1];
        var base = palette === "mono" ? Theme.bright : Theme.accent;
        return Qt.rgba(base.r, base.g, base.b, [0, 0.42, 0.62, 0.82, 1.0][l]);
    }
    readonly property real cellRadius: shape === "square" ? 0 : shape === "circle" ? cell / 2 : cell * 0.23

    readonly property string idleText: {
        if (!service) return "";
        if (service.error.length > 0) return trError(service.error);
        if (user.length === 0) return tr("set your username ✎");
        if (!showTodayCount) return "";
        var t = days[todayIso];
        return t ? tr("today") + ": " + t.count : "";
    }

    // The settings the gear panel lists, by section; the same keys and
    // defaults as the manifest schema the right-click menu renders. `only`
    // shows a row just for that period.
    // One-click looks: each sets several settings at once.
    readonly property var presets: [
        { l: root.tr("Month blocks"), v: { monthGap: 6, cellSize: 13, cellGap: 3, cellShape: "rounded", palette: "mono",
            showMonths: false, showWeekdays: false, showStats: false, showLegend: false, showToolbar: true,
            colorScale: "github", showEmpty: true, bgOpacity: 88 } },
        { l: "GitHub", v: { monthGap: 0, cellSize: 11, cellGap: 3, cellShape: "rounded", palette: "github",
            showMonths: true, showWeekdays: true, showStats: false, showLegend: true, showToolbar: true,
            weekdayStyle: "alt", monthFormat: "short" } },
        { l: root.tr("Minimal"), v: { monthGap: 4, cellSize: 10, cellGap: 2, cellShape: "circle", palette: "accent",
            showMonths: false, showWeekdays: false, showStats: false, showLegend: false, showToolbar: false,
            showBorder: false, bgOpacity: 0 } },
        { l: root.tr("Full"), v: { monthGap: 8, cellSize: 12, cellGap: 3, cellShape: "rounded",
            showMonths: true, showWeekdays: true, showStats: true, showLegend: true, showToolbar: true,
            monthFormat: "cap", weekdayStyle: "alt" } }
    ]
    function applyPreset(v) { for (var k in v) set(k, v[k]); }

    readonly property var sections: [
        { id: "presets", title: root.tr("Quick styles"), items: [{ key: "_preset", label: root.tr("Apply"), type: "preset" }] },
        { id: "data", title: root.tr("Data"), items: [
            { key: "language", label: root.tr("Language"), type: "choice", def: "auto",
              options: [{ v: "auto", l: root.tr("Auto") }, { v: "es", l: "Español" }, { v: "en", l: "English" }] },
            { key: "range", label: root.tr("Period"), type: "choice", def: "year",
              options: [{ v: "year", l: root.tr("Year") }, { v: "last", l: root.tr("Last months") }] },
            { key: "months", label: root.tr("Months to show"), type: "step", def: 12, min: 1, max: 12, step: 1, unit: "", only: "last" },
            { key: "futureDays", label: root.tr("Future days"), type: "choice", def: "dim", only: "year",
              options: [{ v: "dim", l: root.tr("Dim") }, { v: "hide", l: root.tr("Hide") }, { v: "show", l: root.tr("Normal") }] },
            { key: "colorScale", label: root.tr("Color scale"), type: "choice", def: "github",
              options: [{ v: "github", l: "GitHub" }, { v: "relative", l: root.tr("Relative to your best") }] },
            { key: "refreshMin", label: root.tr("Refresh every"), type: "step", def: 30, min: 10, max: 240, step: 10, unit: " min" },
            { key: "clickOpens", label: root.tr("Click opens the day on GitHub"), type: "toggle", def: false },
            { key: "hoverStyle", label: root.tr("Info on hover"), type: "choice", def: "tooltip",
              options: [{ v: "bar", l: root.tr("In the bar") }, { v: "tooltip", l: root.tr("Floating") }, { v: "off", l: root.tr("Don't show") }] },
            { key: "showTodayCount", label: root.tr("Show today's contributions"), type: "toggle", def: true }
        ] },
        { id: "look", title: root.tr("Colors and shape"), items: [
            { key: "palette", label: root.tr("Colors"), type: "choice", def: "accent",
              options: [{ v: "accent", l: root.tr("Theme") }, { v: "github", l: root.tr("Green") }, { v: "blue", l: root.tr("Blue") },
                        { v: "purple", l: root.tr("Purple") }, { v: "pink", l: root.tr("Pink") }, { v: "halloween", l: root.tr("Orange") },
                        { v: "ice", l: root.tr("Ice") }, { v: "mono", l: root.tr("Mono") }] },
            { key: "cellShape", label: root.tr("Shape"), type: "choice", def: "rounded",
              options: [{ v: "rounded", l: root.tr("Rounded") }, { v: "square", l: root.tr("Square") }, { v: "circle", l: root.tr("Circle") }] },
            { key: "showEmpty", label: root.tr("Empty days"), type: "toggle", def: true },
            { key: "highlightToday", label: root.tr("Mark today"), type: "toggle", def: true }
        ] },
        { id: "grid", title: root.tr("Grid"), items: [
            { key: "cellSize", label: root.tr("Cell size"), type: "step", def: 11, min: 6, max: 20, step: 1, unit: " px" },
            { key: "cellGap", label: root.tr("Cell spacing"), type: "step", def: 3, min: 0, max: 8, step: 1, unit: " px" },
            { key: "monthGap", label: root.tr("Month spacing"), type: "step", def: 0, min: 0, max: 24, step: 2, unit: " px" },
            { key: "weekStart", label: root.tr("Week starts"), type: "choice", def: "sun",
              options: [{ v: "sun", l: root.tr("Sunday") }, { v: "mon", l: root.tr("Monday") }] }
        ] },
        { id: "labels", title: root.tr("Labels"), items: [
            { key: "showMonths", label: root.tr("Months"), type: "toggle", def: true },
            { key: "monthFormat", label: root.tr("Month format"), type: "choice", def: "short",
              options: [{ v: "short", l: root.monthName(0, "short") }, { v: "cap", l: root.monthName(0, "cap") },
                        { v: "initial", l: root.monthName(0, "initial") }, { v: "number", l: "1" }] },
            { key: "showWeekdays", label: root.tr("Weekdays"), type: "toggle", def: true },
            { key: "weekdayStyle", label: root.tr("Weekday style"), type: "choice", def: "alt",
              options: [{ v: "alt", l: [1, 3, 5].map(function (d) { return root.dayNames()[d]; }).join(" ") },
                        { v: "all", l: root.tr("All") },
                        { v: "initial", l: [1, 2, 3].map(function (d) { return root.dayInitials()[d]; }).join(" ") }] },
            { key: "textScale", label: root.tr("Text size"), type: "step", def: 100, min: 70, max: 160, step: 10, unit: "%" }
        ] },
        { id: "card", title: root.tr("Card"), items: [
            { key: "showToolbar", label: root.tr("Top bar"), type: "toggle", def: true },
            { key: "showStats", label: root.tr("Streaks and record"), type: "toggle", def: true },
            { key: "showLegend", label: root.tr("Legend"), type: "toggle", def: true },
            { key: "showBorder", label: root.tr("Card border"), type: "toggle", def: true },
            { key: "bgStyle", label: root.tr("Background"), type: "choice", def: "glass",
              options: [{ v: "glass", l: root.tr("Glass (like the calendar)") }, { v: "solid", l: root.tr("Solid") }] },
            { key: "bgOpacity", label: root.tr("Background opacity"), type: "step", def: 100, min: 0, max: 100, step: 10, unit: "%" },
            { key: "cardRadius", label: root.tr("Card corners"), type: "step", def: 14, min: 0, max: 24, step: 2, unit: " px" }
        ] }
    ]

    implicitWidth: Math.max(dayCol + gridW, toolbar.visible ? toolLeft.implicitWidth + toolRight.implicitWidth + 16 * s : 0,
                            settingsOpen ? 640 * s : 0) + 2 * pad + gearSpace
    implicitHeight: bg.implicitHeight

    // ── building blocks ──
    component Pill: Rectangle {
        id: pill
        property real s: 1
        default property alias content: inner.data
        height: 26 * s
        width: inner.implicitWidth + 20 * s
        radius: 7 * s
        color: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.07)
        Row {
            id: inner
            anchors.centerIn: parent
            spacing: 6 * pill.s
        }
    }
    component Label: Text {
        property real s: 1
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: Theme.bright
        font.family: Theme.font
        font.pixelSize: 12 * s
        font.weight: Font.DemiBold
    }
    component Small: Text {
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 10 * root.fs
    }
    component IconButton: Rectangle {
        id: btn
        property real s: 1
        property string icon: ""
        property bool usable: true
        property bool lit: false
        signal clicked()
        width: 26 * s
        height: 26 * s
        radius: 7 * s
        color: btn.lit ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
            : ma.containsMouse && btn.usable
            ? Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.14)
            : Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.07)
        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.family: "Material Symbols Rounded"
            font.pixelSize: 16 * btn.s
            renderType: Text.QtRendering
            color: btn.usable ? Theme.bright : Theme.faint
            opacity: btn.usable ? 1 : 0.4
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (btn.usable) btn.clicked()
        }
    }

    component CornerIcon: Text {
        id: ci
        property bool lit: false
        signal clicked()
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.family: "Material Symbols Rounded"
        font.pixelSize: 15 * root.s
        renderType: Text.QtRendering
        color: ci.lit || ciMa.containsMouse ? Theme.accent : Theme.dim
        MouseArea {
            id: ciMa
            anchors.fill: parent
            anchors.margins: -3 * root.s
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ci.clicked()
        }
    }

    HoverHandler { id: cardHover }

    Rectangle {
        id: bg
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 2 * root.pad
        radius: root.cardRadius
        color: root.glass ? "transparent" : Qt.rgba(Theme.cardBot.r, Theme.cardBot.g, Theme.cardBot.b, root.bgAlpha)
        border.width: root.showBorder && root.bgAlpha > 0 ? 1 : 0
        border.color: cardHover.hovered ? Theme.lineStrong : Theme.border

        // the frosted plate, as the shell's WidgetGlass draws it: the patch of
        // wallpaper behind the card (with a bleed so the blur has no dark rim),
        // blurred and washed in the palette. Opacity scales the whole plate.
        ClippingRectangle {
            id: glassPlate
            visible: root.glass
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            opacity: root.bgAlpha
            z: -1

            readonly property rect wr: root.pluginApi && root.pluginApi.wallpaperRect ? root.pluginApi.wallpaperRect : Qt.rect(0, 0, 1, 1)
            // wallpaper px per card px (the host scales the tile)
            readonly property real k: width > 0 ? wr.width / width : 1
            readonly property real bleed: 36 * k
            readonly property real cx: Math.max(0, wr.x - bleed)
            readonly property real cy: Math.max(0, wr.y - bleed)
            readonly property real cr: root.wpSource ? Math.min(root.wpSource.width, wr.x + wr.width + bleed) : 0
            readonly property real cb: root.wpSource ? Math.min(root.wpSource.height, wr.y + wr.height + bleed) : 0

            ShaderEffectSource {
                id: crop
                x: (glassPlate.cx - glassPlate.wr.x) / glassPlate.k
                y: (glassPlate.cy - glassPlate.wr.y) / glassPlate.k
                width: Math.max(1, (glassPlate.cr - glassPlate.cx) / glassPlate.k)
                height: Math.max(1, (glassPlate.cb - glassPlate.cy) / glassPlate.k)
                sourceItem: root.glass ? root.wpSource : null
                sourceRect: Qt.rect(glassPlate.cx, glassPlate.cy, glassPlate.cr - glassPlate.cx, glassPlate.cb - glassPlate.cy)
                live: glassPlate.visible
                hideSource: true
                recursive: false
                smooth: true
                visible: false
            }
            MultiEffect {
                x: crop.x
                y: crop.y
                width: crop.width
                height: crop.height
                source: crop
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
                blurMultiplier: 1.7
                saturation: -0.24
                contrast: 0.08
                brightness: -0.10
            }
            Rectangle {
                anchors.fill: parent
                radius: glassPlate.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, cardHover.hovered ? 0.08 : 0.05) }
                    GradientStop { position: 0.42; color: Qt.rgba(Theme.cardTop.r, Theme.cardTop.g, Theme.cardTop.b, 0.18) }
                    GradientStop { position: 1; color: Qt.rgba(Theme.cardBot.r, Theme.cardBot.g, Theme.cardBot.b, 0.32) }
                }
            }
        }

        // With the toolbar hidden, a gear still shows on hover.
        IconButton {
            z: 2
            anchors.top: stripGear.bottom
            anchors.left: stripGear.left
            anchors.topMargin: 4 * root.s
            visible: stripGear.visible
            s: root.s * 0.85
            icon: "refresh"
            onClicked: root.user.length > 0 ? root.service.refresh() : root.service.detectUser()
        }
        IconButton {
            id: stripGear
            z: 2
            visible: !root.showToolbar && !root.cornerGear && (cardHover.hovered || root.settingsOpen)
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: root.pad - 2 * root.s
            anchors.leftMargin: root.pad - 4 * root.s
            s: root.s * 0.85
            icon: "settings"
            lit: root.settingsOpen
            onClicked: root.settingsOpen = !root.settingsOpen
        }

        Column {
            id: col
            x: root.pad + root.gearSpace
            y: root.pad
            width: parent.width - 2 * root.pad - root.gearSpace
            spacing: 10 * root.s

            // ── toolbar ──
            Item {
                id: toolbar
                visible: root.showToolbar
                width: parent.width
                height: 26 * root.s

                Row {
                    id: toolLeft
                    spacing: 6 * root.s

                    IconButton {
                        s: root.s
                        icon: root.editing ? "check" : "edit"
                        onClicked: {
                            if (root.editing) {
                                root.service.setUsername(field.text);
                                field.focus = false;
                            } else {
                                field.text = root.user;
                                field.forceActiveFocus();
                                field.selectAll();
                            }
                        }
                    }
                    Pill {
                        s: root.s
                        width: root.editing ? 150 * root.s : userText.implicitWidth + 20 * root.s
                        Label {
                            id: userText
                            s: root.s
                            visible: !root.editing
                            text: root.user.length > 0 ? root.user : "—"
                        }
                        TextInput {
                            id: field
                            visible: root.editing
                            width: 130 * root.s
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            color: Theme.bright
                            selectionColor: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.DemiBold
                            maximumLength: 39
                            validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9-]*/ }
                            onAccepted: {
                                root.service.setUsername(text);
                                focus = false;
                            }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Pill {
                        s: root.s
                        visible: root.range !== "last"
                        width: yearRow.implicitWidth + 8 * root.s
                        Row {
                            id: yearRow
                            spacing: 2 * root.s
                            IconButton {
                                s: root.s * 0.85
                                icon: "chevron_left"
                                color: "transparent"
                                usable: root.year > 2008
                                onClicked: root.service.prevYear()
                            }
                            Label { s: root.s; text: root.year }
                            IconButton {
                                s: root.s * 0.85
                                icon: "chevron_right"
                                color: "transparent"
                                usable: root.service ? root.year < root.service.thisYear : false
                                onClicked: root.service.nextYear()
                            }
                        }
                    }
                    Pill {
                        s: root.s
                        visible: root.range === "last"
                        Label { s: root.s; text: root.months + " " + root.tr(root.months === 1 ? "month" : "months") }
                    }
                    Pill {
                        s: root.s
                        Label { s: root.s; text: root.st.total + " " + root.tr("contributions") }
                    }
                }

                Row {
                    id: toolRight
                    anchors.right: parent.right
                    spacing: 6 * root.s

                    TextMetrics {
                        id: widest
                        font.family: Theme.font
                        font.pixelSize: 12 * root.s
                        font.weight: Font.DemiBold
                        text: "99 " + root.tr("contributions") + " • " + root._fmt("2026-09-30")
                    }
                    // plain text, right-aligned in a reserved slot: hovering swaps
                    // the words but never resizes the card
                    Item {
                        visible: root.hoverStyle === "bar" || infoLabel.text.length > 0
                        width: (root.hoverStyle === "bar" ? Math.max(widest.advanceWidth, infoLabel.implicitWidth)
                                                          : infoLabel.implicitWidth) + 4 * root.s
                        height: 26 * root.s
                        Label {
                            id: infoLabel
                            s: root.s
                            anchors.right: parent.right
                            text: root.barHover ? root.hoverText : root.idleText
                            color: root.service && root.service.error.length > 0 && !root.barHover ? Theme.sun
                                : root.barHover ? Theme.bright : Theme.dim
                        }
                    }
                    IconButton {
                        s: root.s
                        icon: "settings"
                        lit: root.settingsOpen
                        onClicked: root.settingsOpen = !root.settingsOpen
                    }
                    IconButton {
                        id: reload
                        s: root.s
                        icon: "refresh"
                        onClicked: root.user.length > 0 ? root.service.refresh() : root.service.detectUser()
                        RotationAnimation on rotation {
                            running: root.service ? root.service.loading : false
                            from: 0; to: 360; duration: 900
                            loops: Animation.Infinite
                            onStopped: reload.rotation = 0
                        }
                    }
                }
            }

            // ── month labels ──
            Item {
                visible: root.showMonths
                x: root.gridOffset
                width: root.dayCol + root.gridW
                height: 12 * root.fs
                // the gear and refresh, in the corner above the weekday labels
                Row {
                    id: cornerIcons
                    z: 1
                    visible: root.cornerShown
                    height: parent.height
                    spacing: 5 * root.s
                    CornerIcon {
                        text: "settings"
                        lit: root.settingsOpen
                        onClicked: root.settingsOpen = !root.settingsOpen
                    }
                    CornerIcon {
                        id: cornerReload
                        text: "refresh"
                        lit: root.service ? root.service.loading : false
                        onClicked: root.user.length > 0 ? root.service.refresh() : root.service.detectUser()
                        RotationAnimation on rotation {
                            running: root.service ? root.service.loading : false
                            from: 0; to: 360; duration: 900
                            loops: Animation.Infinite
                            onStopped: cornerReload.rotation = 0
                        }
                    }
                }
                Repeater {
                    model: root.layout.marks
                    delegate: Small {
                        required property var modelData
                        x: root.dayCol + modelData.x
                        text: modelData.t
                        // a month name under the corner icons steps aside while they show
                        opacity: root.cornerShown && x < cornerIcons.width + 4 * root.s ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }
            }

            // ── weekday labels + the grid ──
            Item {
                x: root.gridOffset
                width: root.dayCol + root.gridW
                height: 7 * (root.cell + root.gap) - root.gap

                Repeater {
                    model: root.showWeekdays ? 7 : 0
                    delegate: Small {
                        required property int index
                        // index is the row; the weekday it holds depends on the week start
                        readonly property int dow: root.mondayFirst ? (index + 1) % 7 : index
                        visible: root.weekdayStyle !== "alt" || dow === 1 || dow === 3 || dow === 5
                        width: Math.max(0, root.dayCol - 5 * root.s)
                        horizontalAlignment: Text.AlignRight
                        y: index * (root.cell + root.gap) + (root.cell - height) / 2
                        text: root.weekdayStyle === "initial"
                            ? root.dayInitials()[dow]
                            : root.dayNames()[dow]
                        font.pixelSize: Math.min(10 * root.fs, root.cell + root.gap)
                    }
                }

                Item {
                    x: root.dayCol
                    width: root.gridW
                    height: parent.height

                    Repeater {
                        model: root.layout.pos.length
                        delegate: Rectangle {
                            id: day
                            required property int index
                            readonly property var p: root.layout.pos[index] || ({ x: 0, y: 0, iso: "" })
                            readonly property string iso: p.iso
                            readonly property var dayInfo: root.days[iso]
                            readonly property bool future: iso > root.todayIso

                            x: p.x
                            y: p.y
                            width: root.cell
                            height: root.cell
                            radius: root.cellRadius
                            color: root.tint(root.levelOf(dayInfo))
                            opacity: !future || root.futureMode === "show" ? 1 : root.futureMode === "dim" ? 0.35 : 0
                            border.width: root.markToday && iso === root.todayIso ? 1 : 0
                            border.color: Theme.bright

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root.clickOpens ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onEntered: {
                                    if (root.hoverStyle === "off") return;
                                    root.hoverX = day.x;
                                    root.hoverY = day.y;
                                    root.hoverText = root._label(day.iso, day.dayInfo ? day.dayInfo.count : 0);
                                }
                                onExited: if (root.hoverText === root._label(day.iso, day.dayInfo ? day.dayInfo.count : 0)) root.hoverText = ""
                                onClicked: if (root.clickOpens && root.user.length > 0)
                                    Qt.openUrlExternally("https://github.com/" + root.user + "?tab=overview&from=" + day.iso + "&to=" + day.iso)
                            }
                        }
                    }

                    // floating tip over the hovered cell; above it, or below on the top rows
                    Rectangle {
                        z: 10
                        visible: root.hoverStyle === "tooltip" && root.hoverText.length > 0
                        width: tipText.implicitWidth + 14 * root.s
                        height: tipText.implicitHeight + 8 * root.s
                        radius: 6 * root.s
                        color: Theme.cardTop
                        border.width: 1
                        border.color: Theme.border
                        x: Math.max(-root.dayCol, Math.min(parent.width - width, root.hoverX + root.cell / 2 - width / 2))
                        y: root.hoverY - height - 4 * root.s >= 0 ? root.hoverY - height - 4 * root.s : root.hoverY + root.cell + 4 * root.s
                        Text {
                            id: tipText
                            anchors.centerIn: parent
                            text: root.hoverText
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            // ── stats + legend ──
            Item {
                visible: root.showStats || root.showLegend || (!root.showToolbar && root.hoverStyle === "bar")
                width: parent.width
                height: 16 * root.fs

                Small {
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.gridOffset + root.dayCol
                    width: (legend.visible ? legend.x - 12 * root.s : parent.width) - x
                    elide: Text.ElideRight
                    font.pixelSize: 10.5 * root.fs
                    text: {
                        if (!root.showToolbar && root.barHover) return root.hoverText;
                        if (!root.showStats || !root.service) return "";
                        var sv = root.service;
                        var parts = [root.tr("streak") + ": " + sv.streak + " " + root.tr(sv.streak === 1 ? "day" : "days"),
                                     root.tr("best streak") + ": " + root.st.best,
                                     root.st.active + " " + root.tr("active days")];
                        if (root.st.top > 0) parts.push(root.tr("record") + ": " + root.st.top + " (" + root._fmt(root.st.topDate) + ")");
                        if (!root.showToolbar) parts.unshift(root.st.total + " " + root.tr("contributions"));
                        return parts.join("  ·  ");
                    }
                }

                Row {
                    id: legend
                    visible: root.showLegend
                    x: root.gridOffset + root.dayCol + root.gridW - width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3 * root.s
                    Small {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.tr("less")
                        rightPadding: 2 * root.s
                    }
                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(root.cell, 11 * root.s)
                            height: width
                            radius: root.shape === "square" ? 0 : root.shape === "circle" ? width / 2 : width * 0.23
                            color: index === 0 ? Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.07) : root.tint(index)
                        }
                    }
                    Small {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.tr("more")
                        leftPadding: 2 * root.s
                    }
                }
            }

            // ── settings panel ──
            Rectangle {
                visible: root.settingsOpen
                x: -root.gearSpace
                width: parent.width + root.gearSpace
                height: visible ? sectionsCol.implicitHeight + 20 * root.s : 0
                radius: 9 * root.s
                color: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.05)
                border.width: 1
                border.color: Theme.hair

                Column {
                    id: sectionsCol
                    x: 10 * root.s
                    y: 10 * root.s
                    width: parent.width - 20 * root.s
                    spacing: 4 * root.s

                    Repeater {
                        model: root.sections
                        delegate: Column {
                            id: sect
                            required property var modelData
                            width: sectionsCol.width
                            spacing: 6 * root.s

                            readonly property bool unfolded: root.openSections[modelData.id] === true

                            Item {
                                width: parent.width
                                height: 20 * root.s
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4 * root.s
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "chevron_right"
                                        rotation: sect.unfolded ? 90 : 0
                                        Behavior on rotation { NumberAnimation { duration: 120 } }
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 16 * root.s
                                        renderType: Text.QtRendering
                                        color: Theme.accent
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: sect.modelData.title
                                        color: headMa.containsMouse ? Theme.bright : Theme.accent
                                        font.family: Theme.font
                                        font.pixelSize: 10 * root.s
                                        font.weight: Font.DemiBold
                                        font.capitalization: Font.AllUppercase
                                        font.letterSpacing: 1.2 * root.s
                                    }
                                }
                                MouseArea {
                                    id: headMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleSection(sect.modelData.id)
                                }
                            }

                            Grid {
                                id: settingsGrid
                                visible: sect.unfolded
                                width: parent.width
                                columns: width > 640 * root.s ? 2 : 1
                                columnSpacing: 18 * root.s
                                rowSpacing: 6 * root.s

                                Repeater {
                                    model: sect.modelData.items
                                    delegate: Item {
                                        id: fieldRow
                                        required property var modelData
                                        readonly property var f: modelData
                                        readonly property var cur: root.cfg(f.key, f.def)
                                        visible: !f.only || f.only === root.range
                                        width: (settingsGrid.width - (settingsGrid.columns - 1) * settingsGrid.columnSpacing) / settingsGrid.columns
                                        height: Math.max(22 * root.s, controls.implicitHeight)

                                        Text {
                                            id: rowLabel
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: fieldRow.f.label
                                            color: Theme.bright
                                            font.family: Theme.font
                                            font.pixelSize: 11.5 * root.s
                                        }

                                        Item {
                                            id: controls
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - rowLabel.implicitWidth - 12 * root.s
                                            implicitHeight: choiceFlow.visible ? choiceFlow.implicitHeight
                                                : presetFlow.visible ? presetFlow.implicitHeight : 22 * root.s
                                            height: implicitHeight

                                            // choice: a row of chips, the current one lit
                                            Flow {
                                                id: choiceFlow
                                                visible: fieldRow.f.type === "choice"
                                                width: parent.width
                                                                                                spacing: 4 * root.s
                                                Repeater {
                                                    model: fieldRow.f.type === "choice" ? fieldRow.f.options : []
                                                    delegate: Rectangle {
                                                        id: chip
                                                        required property var modelData
                                                        readonly property bool on: fieldRow.cur === modelData.v
                                                        height: 22 * root.s
                                                        width: chipText.implicitWidth + 14 * root.s
                                                        radius: 6 * root.s
                                                        color: on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
                                                            : chipMa.containsMouse ? Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.12)
                                                            : Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.06)
                                                        Text {
                                                            id: chipText
                                                            anchors.centerIn: parent
                                                            text: chip.modelData.l
                                                            color: chip.on ? Theme.bright : Theme.dim
                                                            font.family: Theme.font
                                                            font.pixelSize: 11 * root.s
                                                            font.weight: chip.on ? Font.DemiBold : Font.Normal
                                                        }
                                                        MouseArea {
                                                            id: chipMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.set(fieldRow.f.key, chip.modelData.v)
                                                        }
                                                    }
                                                }
                                            }

                                            // preset: chips that each apply a whole look
                                            Flow {
                                                id: presetFlow
                                                visible: fieldRow.f.type === "preset"
                                                width: parent.width
                                                                                                spacing: 4 * root.s
                                                Repeater {
                                                    model: fieldRow.f.type === "preset" ? root.presets : []
                                                    delegate: Rectangle {
                                                        id: pchip
                                                        required property var modelData
                                                        height: 22 * root.s
                                                        width: pText.implicitWidth + 14 * root.s
                                                        radius: 6 * root.s
                                                        color: pMa.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
                                                            : Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.06)
                                                        Text {
                                                            id: pText
                                                            anchors.centerIn: parent
                                                            text: pchip.modelData.l
                                                            color: Theme.bright
                                                            font.family: Theme.font
                                                            font.pixelSize: 11 * root.s
                                                        }
                                                        MouseArea {
                                                            id: pMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.applyPreset(pchip.modelData.v)
                                                        }
                                                    }
                                                }
                                            }

                                            // toggle: a switch
                                            Rectangle {
                                                id: sw
                                                visible: fieldRow.f.type === "toggle"
                                                readonly property bool on: fieldRow.cur === true
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 34 * root.s
                                                height: 18 * root.s
                                                radius: height / 2
                                                color: on ? Theme.accent : Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.15)
                                                Behavior on color { ColorAnimation { duration: 120 } }
                                                Rectangle {
                                                    width: 14 * root.s
                                                    height: width
                                                    radius: width / 2
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: sw.on ? parent.width - width - 2 * root.s : 2 * root.s
                                                    color: sw.on ? Theme.cardBot : Theme.bright
                                                    Behavior on x { NumberAnimation { duration: 120 } }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.set(fieldRow.f.key, !sw.on)
                                                }
                                            }

                                            // step: − value +
                                            Row {
                                                visible: fieldRow.f.type === "step"
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4 * root.s
                                                IconButton {
                                                    s: root.s * 0.85
                                                    icon: "remove"
                                                    usable: Number(fieldRow.cur) > fieldRow.f.min
                                                    onClicked: root.set(fieldRow.f.key, Math.max(fieldRow.f.min, Number(fieldRow.cur) - fieldRow.f.step))
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 52 * root.s
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: Math.round(Number(fieldRow.cur)) + (fieldRow.f.unit || "")
                                                    color: Theme.bright
                                                    font.family: Theme.font
                                                    font.pixelSize: 11.5 * root.s
                                                    font.weight: Font.DemiBold
                                                }
                                                IconButton {
                                                    s: root.s * 0.85
                                                    icon: "add"
                                                    usable: Number(fieldRow.cur) < fieldRow.f.max
                                                    onClicked: root.set(fieldRow.f.key, Math.min(fieldRow.f.max, Number(fieldRow.cur) + fieldRow.f.step))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
