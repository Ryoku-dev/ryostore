pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// content/Card.qml — the collectible face: the system card as a trading
// card, a faithful port of the hub's TradingCard classic face, drawn at
// 630 x 880 (a playing card's 63 x 88 mm) and scaled by the tile. The
// border's colour says the tier, the figure stands in the holo window, the
// parts are the moves with their numbers, the machine's power is its
// number, the motto is the flavour text, and the card code rules its face
// as three tick rulers. Rarity and power come from lib/rarity.js, exactly
// as the hub grades them; the card code comes from `ryoku-hub profile
// code`. The foil is painted on a Canvas (see Foil.qml) instead of the
// hub's compiled shader.
Item {
    id: card

    required property var svc
    required property var st
    required property bool live
    // the cursor over the tile, normalized -0.5..0.5; fed by the widget,
    // forwarded to every foil so the sheen tracks the mouse
    property bool touched: false
    property real hx: 0
    property real hy: 0

    readonly property int level: svc ? svc.level : 0
    readonly property var tier: svc ? svc.tier : null
    readonly property real windowFoil: [0, 0.2, 0.42, 0.62, 0.7, 0.8][Math.min(5, level)]
    readonly property real faceFoil: [0, 0, 0.06, 0.12, 0.16, 0.2][Math.min(5, level)]
    readonly property bool secret: level >= 5

    // the printed colours: the theme's, graded by tier, like the hub's
    function mix(a, b, t) {
        return Qt.rgba(a.r * (1 - t) + b.r * t, a.g * (1 - t) + b.g * t,
            a.b * (1 - t) + b.b * t, a.a * (1 - t) + b.a * t);
    }
    readonly property color ink: Theme.bright
    readonly property color mutedInk: Theme.dim
    readonly property color quietInk: Theme.faint
    readonly property color accent: Theme.accent
    readonly property color plate: Theme.cardTop
    readonly property color rim: level >= 4 ? Theme.gold : level >= 2 ? Theme.accent
                                                                       : mix(Theme.cardTop, Theme.bright, 0.55)
    readonly property color shine: level >= 4 ? Theme.gold : Theme.bright

    // the same hub-first resolution as the poster: the card store wins,
    // then the tile's own settings, then the default
    function storeGet(path) {
        var node = card.svc ? card.svc.cardStore : null;
        if (!node)
            return undefined;
        const parts = path.split(".");
        for (var i = 0; i < parts.length; i++) {
            if (node === null || node === undefined || typeof node !== "object")
                return undefined;
            node = node[parts[i]];
        }
        return node;
    }
    function f(key, hubPath, def) {
        const h = storeGet(hubPath);
        if (h !== undefined && h !== null && String(h).length > 0)
            return h;
        const v = card.st ? card.st[key] : undefined;
        return v === undefined || v === "" ? def : v;
    }

    readonly property string name: String(f("name", "text.name",
        svc ? svc.sysUser : ""))
    readonly property string stockTagline: qsTr("For the sake of power and beauty.")
    readonly property string tagline: String(f("tagline", "text.tagline", stockTagline))
    readonly property bool stockWords: tagline === stockTagline
    readonly property bool gloss: !(st && st.gloss === false)
    readonly property string epithet: {
        const raw = f("epithets", "text.epithets",
            "Power,Beauty,Grace,Ruin,Demise,Void")
        const w = Array.isArray(raw) ? raw : String(raw).split(",")
        return w.length > 0 ? String(w[0]).trim().toUpperCase() : "RYOKU"
    }
    readonly property string art: st && st.art !== undefined ? String(st.art) : ""
    readonly property string artStyle: st && st.artStyle !== undefined ? String(st.artStyle) : "photo"
    readonly property bool artFills: art !== "" || (svc && svc.heroKind === "custom")
    readonly property string illustrator: art !== "" || (svc && svc.heroKind === "custom")
        ? qsTr("Figure by %1").arg(name)
        : qsTr("Caracalla Farnese, Naples. Photo Marie-Lan Nguyen, CC BY 2.5")
    readonly property string typeLine: {
        if (!svc)
            return "";
        var parts = [svc.sysDistro !== "Linux" ? svc.sysDistro : "", svc.sysWM,
                     svc.sysGpu && svc.sysGpu !== "-" ? svc.sysGpu : ""];
        return parts.filter(s => s.length > 0).join("  ·  ");
    }
    // the moves, as a system monitor: processor, memory and the primary
    // GPU read live through the service's poll. A machine whose graphics
    // report nothing live (no sensor, asleep discrete card) keeps the
    // Display row instead, so the card never prints a lie.
    readonly property var moves: !svc ? [] : [
        { glyph: "cpu", name: qsTr("Processor"), detail: svc.sysCpu + " · " + svc.sysCpuCores
            + (svc.cpuTemp > 0 ? " · " + svc.cpuTemp + "°C" : ""),
          value: svc.cpu, unit: "%" },
        svc.gpuOk
            ? { glyph: "lens", name: qsTr("Graphics"),
                detail: svc.sysGpu + (svc.gpuTemp > 0 ? " · " + svc.gpuTemp + "°C" : "")
                    + (svc.gpuVramTotal > 1 ? " · " + (svc.gpuVramUsed / 1024).toFixed(1) + "/" + Math.round(svc.gpuVramTotal / 1024) + " GB" : ""),
                value: svc.gpuUtil, unit: "%" }
            : { glyph: "monitor", name: qsTr("Display"), detail: svc.sysResolution
                + (svc.sysRefresh.length > 0 ? " @ " + svc.sysRefresh : ""),
                value: svc.refresh, unit: "Hz" },
        { glyph: "archive", name: qsTr("Memory"), detail: qsTr("%1% of %2 GB").arg(svc.ram).arg(svc.ramGb),
          value: Math.round(svc.ramGb * svc.ram / 100), unit: "GB" }
    ]
    readonly property var traits: !svc ? [] : [
        { name: qsTr("Up for"), value: svc.sysUptime },
        { name: qsTr("Packages"), value: svc.sysPackages },
        { name: qsTr("Kernel"), value: String(svc.sysKernel).replace(/-.*/, "") }
    ]
    readonly property var code: svc ? svc.code : null
    readonly property string serial: svc ? svc.serial : ""
    readonly property int power: svc ? svc.power : 0
    readonly property int points: svc && svc.rarity ? svc.rarity.points : 0
    readonly property string release: svc && svc.releaseName.length > 0 ? svc.releaseName : "Ryoku"
    readonly property string markText: svc && svc.markText.length > 0 ? svc.markText : "力"

    // the card's border
    CutRect {
        anchors.fill: parent
        cut: 22
        fill: card.rim
    }

    // the face
    CutRect {
        id: face
        anchors.fill: parent
        anchors.margins: card.secret ? 20 : 14
        cut: 14
        fill: card.plate
        strokeWidth: card.level >= 3 ? 2 : 1
        strokeColor: card.level >= 3 ? Theme.gold : Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.2)
        clip: true
        Foil {
            anchors.fill: parent
            cut: 14
            strength: card.faceFoil
            live: card.live
            touched: card.touched
            hx: card.hx
            hy: card.hy
        }
    }

    // the head: its stage, its name, its power
    Label {
        x: 34
        y: 26
        text: qsTr("Ryoku machine") + "  ·  " + (card.tier ? qsTr(card.tier.name) : "")
            + (card.gloss ? "  ·  力の機械" : "")
        typeRole: "monoSm"
        font.pixelSize: 12
        font.letterSpacing: 1.6
        font.capitalization: Font.AllUppercase
        ink: card.mutedInk
    }
    Label {
        id: nameLabel
        x: 32
        y: 42
        width: 400
        text: card.name
        ink: card.secret ? card.shine : card.ink
        typeRole: "name"
        font.pixelSize: 42
        lineHeight: 50
    }
    Label {
        id: powerLabel
        anchors.right: parent.right
        anchors.rightMargin: 34
        y: 40
        text: String(card.power)
        numeric: true
        typeRole: "name"
        font.pixelSize: 44
        font.weight: Font.Black
        ink: card.shine
    }
    Label {
        anchors.right: powerLabel.left
        anchors.rightMargin: 6
        anchors.baseline: powerLabel.baseline
        text: "力"
        typeRole: "title"
        font.pixelSize: 22
        ink: card.accent
    }

    // the figure in its holo window
    CutRect {
        id: window
        x: 30
        y: 104
        width: 570
        height: 400
        cut: 8
        fill: card.plate
        strokeWidth: 3
        strokeColor: card.level >= 4 ? Theme.gold : card.mix(card.rim, card.ink, 0.35)
        clip: true
        Foil {
            anchors.fill: parent
            anchors.margins: 3
            cut: 6
            strength: card.windowFoil
            live: card.live
            touched: card.touched
            hx: card.hx
            hy: card.hy
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 24
            text: card.epithet
            color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.1)
            font.family: Theme.font
            font.weight: Font.Black
            font.capitalization: Font.AllUppercase
            font.pixelSize: 120
        }
        Figure {
            id: cardFigure
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            config: card.svc ? card.svc.heroConfig : ({})
            configDir: card.svc ? card.svc.configDir : ""
            overrideFile: card.art
            overrideStyle: card.artStyle
            ink: card.ink
            readonly property bool fills: card.artFills
            height: fills ? parent.height - 6 : card.level >= 4 ? parent.height + 20 : parent.height - 18
            width: fills ? parent.width - 6
                : Math.round(height * (card.artFills ? 900 / 1157 : stockAspect))
            soft: true
        }
    }

    // the type line and the illustrator, as a card prints them
    CutRect {
        x: 54
        y: window.y + window.height - 6
        width: 522
        height: 30
        cut: 6
        fill: card.mix(card.plate, Theme.gold, 0.22)
        strokeWidth: 1
        strokeColor: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.5)
        Label {
            anchors.centerIn: parent
            width: parent.width - 24
            horizontalAlignment: Text.AlignHCenter
            text: "No. " + card.serial + "    " + card.typeLine
            typeRole: "monoSm"
            font.pixelSize: 11
            ink: card.ink
        }
    }
    Label {
        x: 40
        y: window.y + window.height + 30
        width: 550
        horizontalAlignment: Text.AlignRight
        text: "Illus. " + card.illustrator
        typeRole: "monoSm"
        font.pixelSize: 9
        ink: card.quietInk
    }

    // the moves: each part, what it is, and its number, under its ruler
    Item {
        id: moveList
        x: 40
        width: 550
        readonly property var bands: card.code ? card.code.ys : [550, 608, 666]

        Repeater {
            model: card.moves
            delegate: Item {
                required property var modelData
                required property int index
                y: moveList.bands[Math.min(index, moveList.bands.length - 1)] + 12
                width: moveList.width
                height: 44

                CutRect {
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    cut: 6
                    fill: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.18)
                    GlyphIcon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        name: modelData.glyph
                        color: card.accent
                    }
                }
                Column {
                    x: 44
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 44 - 120
                    Label {
                        text: modelData.name
                        ink: card.ink
                        typeRole: "label"
                        font.pixelSize: 19
                        font.weight: Font.Bold
                    }
                    Label {
                        width: parent.width
                        text: modelData.detail
                        typeRole: "detail"
                        font.pixelSize: 13
                        ink: card.mutedInk
                    }
                }
                Label {
                    id: amount
                    anchors.right: unit.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    // the live values glide to their new number on every poll
                    property real shown: modelData.value
                    Behavior on shown {
                        NumberAnimation {
                            duration: Motion.standard
                            easing.type: Motion.easeStandard
                        }
                    }
                    text: String(Math.round(shown))
                    numeric: true
                    typeRole: "name"
                    font.pixelSize: 30
                    font.weight: Font.Black
                    ink: card.shine
                }
                Label {
                    id: unit
                    anchors.right: parent.right
                    anchors.baseline: amount.baseline
                    text: modelData.unit
                    typeRole: "monoSm"
                    font.pixelSize: 11
                    ink: card.mutedInk
                }
            }
        }
    }

    // its traits, as a card's weakness, resistance and retreat
    Row {
        x: 40
        y: 734
        width: 550
        Repeater {
            model: card.traits
            delegate: Column {
                required property var modelData
                width: 550 / 3
                spacing: 2
                Label {
                    text: modelData.name
                    typeRole: "monoSm"
                    font.pixelSize: 10
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    ink: card.quietInk
                }
                Label {
                    width: parent.width - 8
                    text: modelData.value && modelData.value !== "-" ? modelData.value : "-"
                    ink: card.ink
                    typeRole: "mono"
                    font.pixelSize: 13
                }
            }
        }
    }

    // the flavour text: the reader's line, and its gloss
    CutRect {
        x: 40
        y: 780
        width: 550
        height: 46
        cut: 6
        fill: "transparent"
        strokeWidth: 1
        strokeColor: Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.6)
        Label {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: gloss.visible ? gloss.left : parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: card.tagline
            typeRole: "proof"
            font.pixelSize: 14
            font.italic: true
            ink: card.mutedInk
        }
        Label {
            id: gloss
            visible: card.stockWords && card.gloss
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "力と美のために"
            typeRole: "caption"
            font.pixelSize: 12
            ink: card.quietInk
        }
    }

    // the set's mark, its release and serial
    Row {
        x: 40
        y: 838
        spacing: 8
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: card.markText
            font.family: Theme.fontJp
            font.pixelSize: 15
            font.weight: Font.Black
            ink: card.accent
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: card.release + "  ·  " + card.serial
            width: 255
            typeRole: "monoSm"
            font.pixelSize: 10
            ink: card.mutedInk
        }
    }
    // its rarity, as a card prints it in its corner
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 40
        y: 836
        spacing: 8
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: (card.tier ? qsTr(card.tier.name).toUpperCase() : "") + "  ·  "
                + qsTr("%1 pts").arg(card.points)
            typeRole: "monoSm"
            font.pixelSize: 10
            font.letterSpacing: 1.2
            ink: card.level >= 3 ? Theme.gold : card.mutedInk
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: card.tier ? card.tier.mark : ""
            typeRole: "label"
            font.pixelSize: 15
            ink: card.level >= 2 ? Theme.gold : card.mutedInk
            property real beat: 1
            scale: card.secret && card.live ? beat : 1
            SequentialAnimation on beat {
                running: card.secret && card.live
                loops: Animation.Infinite
                NumberAnimation { to: 1.25; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { to: 1; duration: 520; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 1400 }
            }
        }
    }

    // from Ultra rare up, sparkles over the figure
    Repeater {
        model: card.level < 4 ? []
            : [[0.12, 0.2, 18], [0.86, 0.14, 24], [0.78, 0.52, 14],
               [0.18, 0.62, 20], [0.52, 0.08, 12], [0.92, 0.78, 16]]
        delegate: Text {
            id: spark
            required property var modelData
            required property int index
            x: window.x + window.width * modelData[0] - width / 2
            y: window.y + window.height * modelData[1] - height / 2
            text: "✦"
            font.pixelSize: modelData[2]
            color: index % 2 ? Theme.gold : card.ink
            property real glimmer: 0.85
            opacity: card.live ? glimmer : 0.85
            SequentialAnimation on glimmer {
                running: card.live
                loops: Animation.Infinite
                PauseAnimation { duration: 400 * index }
                NumberAnimation { to: 0.15; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.95; duration: 700; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 1200 }
            }
        }
    }

    // the card's code: three tick rulers that rule off the parts and carry
    // the machine's design in their tick heights
    Repeater {
        model: card.code ? card.code.ys.length : 0
        delegate: Item {
            id: ruler
            required property int index
            readonly property var levels: card.code.levels[ruler.index]
            x: card.code.x
            y: card.code.ys[ruler.index]
            Rectangle {
                x: -4; y: -2
                width: 558; height: 14
                color: card.plate
            }
            Repeater {
                model: ruler.levels.length
                delegate: Rectangle {
                    required property int index
                    x: index * card.code.pitch
                    width: card.code.tick
                    height: (ruler.levels[index] + 1) * card.code.unit
                    color: card.level >= 4 ? Theme.gold : card.mutedInk
                    antialiasing: true
                }
            }
        }
    }
}
