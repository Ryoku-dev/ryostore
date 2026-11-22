pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

// content/Widget.qml — the System Card as a desktop tile: a poster of this
// computer drawn at 1280 by 800 and scaled to the tile width the host gives
// us. A figure over the ground, the owner's name, the machine's dossier and
// live readings pinned to the figure. It is a faithful port of the Ryoku Hub
// About page's System Card (hyperion): the same blocks, the same leader
// lines, the same edition number. Lithic becomes the themed PluginKit
// palette, the hub's SysInfo + LiveStats become our own service, and the
// card editor's ProfileStore becomes the plugin's settings schema.
// Everything animates and polls only while `active` and `motion` is on.
Item {
    id: root

    // host-set: read, never assign
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0

    // a tile narrower than ~720 px would render the 1280-wide poster at
    // half scale and its 9-11 px type at unreadable 4-5 px. Below that
    // width the poster switches to a tall, tight layout: a smaller design
    // box so every font lands at a readable size on screen.
    readonly property bool tight: !root.isCard && root.widthBudget > 0 && root.widthBudget < 720
    readonly property real designWidth: root.tight ? 720 : 1280
    readonly property real designHeight: root.tight ? 960 : 800
    function fs(small, big) {
        return root.tight ? big : small;
    }

    readonly property var svc: pluginApi ? pluginApi.mainInstance : null
    readonly property var st: pluginApi ? pluginApi.pluginSettings : null

    property var now: new Date()

    // dotted path into the hub's card store (profile.json, the file
    // Settings > About > Customise writes)
    function storeGet(path) {
        var node = root.svc ? root.svc.cardStore : null;
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
    // the plugin's setting keys as the hub spells them in its store
    readonly property var hubKeys: ({
        name: "text.name", tagline: "text.tagline", watermarkGlyph: "text.watermarkGlyph",
        epithets: "text.epithets", marginalia: "text.marginalia", heroSide: "heroSide",
        vitals: "vitals",
        blockWatermark: "blocks.watermark", blockEpithets: "blocks.epithets",
        blockMarginalia: "blocks.marginalia", blockSpecs: "blocks.specs",
        blockPackages: "blocks.packages", blockPalette: "blocks.palette",
        blockBarcode: "blocks.barcode", blockTelemetry: "blocks.telemetry",
        blockSignal: "blocks.signal"
    })
    // resolution order: the hub's card store first, so anything saved in
    // Settings appears here live; then this plugin's own settings; then the
    // default
    function f(key, def) {
        const hubPath = root.hubKeys[key];
        if (hubPath !== undefined) {
            const h = storeGet(hubPath);
            if (h !== undefined && h !== null && String(h).length > 0)
                return h;
        }
        if (!root.st)
            return def;
        const v = root.st[key];
        return v === undefined || v === "" ? def : v;
    }
    function fv(x) {
        return x && x !== "-" && String(x).length > 0 ? String(x) : qsTr("unknown");
    }
    function blockOn(id) {
        return root.f("block" + id, true) === true;
    }
    readonly property bool heroLeft: root.f("heroSide", "right") === "left"
    readonly property int heroDir: heroLeft ? -1 : 1
    readonly property bool live: root.active && root.f("motion", true) === true

    function editionNo() {
        var basis = (svc ? svc.machineId : "") + (svc ? svc.installDate : "");
        var h = 2166136261;
        for (var i = 0; i < basis.length; i++)
            h = ((h ^ basis.charCodeAt(i)) * 16777619) >>> 0;
        return ("000" + (h % 10000)).slice(-4);
    }
    function rate(b) {
        if (b < 1024)
            return b + " B/s";
        if (b < 1048576)
            return (b / 1024).toFixed(b < 10240 ? 1 : 0) + " KB/s";
        return (b / 1048576).toFixed(1) + " MB/s";
    }
    function statBig(key) {
        if (!svc)
            return "";
        if (key === "core")
            return svc.cpuTemp > 0 ? svc.cpuTemp + "°C" : svc.cpu + "%";
        if (key === "gpu")
            return svc.gpuOk ? svc.gpuTemp + "°C" : svc.gpuUtil + "%";
        if (key === "mem")
            return svc.ram + "%";
        if (key === "net")
            return "↓ " + rate(svc.netDown);
        if (key === "frac")
            return svc.ryokuVersion.length > 0 ? "Ryoku " + svc.ryokuVersion : fv("");
        return "";
    }
    function statSub(key) {
        if (!svc)
            return "";
        if (key === "core")
            return qsTr("Processor %1%").arg(svc.cpu);
        if (key === "gpu")
            return svc.gpuOk ? qsTr("Graphics %1%").arg(svc.gpuUtil) : qsTr("Graphics");
        if (key === "mem")
            return fv(svc.sysRam);
        if (key === "net")
            return "↑ " + rate(svc.netUp);
        if (key === "frac")
            return fv(svc.sysDistro);
        return "";
    }

    readonly property var palette: svc && svc.sysPalette.length > 0
        ? svc.sysPalette.split(",") : []
    // the wallpaper's own colours drive the poster: a tinted ground, an
    // accent glow, brackets and rules in the accent, and a heat ramp for
    // the live bars (accent -> pink -> warm as temperatures climb)
    readonly property color wallBase: root.palette.length > 0 ? root.palette[0] : Theme.cardTop
    readonly property color wallAccent: root.palette.length > 2 ? root.palette[2] : Theme.accent
    readonly property color wallPink: root.palette.length > 3 ? root.palette[3] : Theme.sun
    readonly property color wallWarm: root.palette.length > 1 ? root.palette[1] : "#ff8a70"
    function mixc(a, b, t) {
        return Qt.rgba(a.r * (1 - t) + b.r * t, a.g * (1 - t) + b.g * t,
            a.b * (1 - t) + b.b * t, a.a * (1 - t) + b.a * t);
    }
    function heat(c) {
        return c >= 75 ? root.wallWarm : c >= 60 ? mixc(root.wallPink, root.wallWarm, 0.5) : root.wallAccent;
    }
    readonly property string barcodeText: ("RYOKU-"
        + (svc ? svc.codename : "-") + "-" + (svc && svc.installDate.length > 0 ? svc.installDate : "0")).toUpperCase()
    readonly property var words: String(root.f("epithets",
        "Power,Beauty,Grace,Ruin,Demise,Void")).split(",").map(w => w.trim()).filter(w => w.length > 0)

    implicitWidth: root.widthBudget > 0 ? root.widthBudget : 480
    implicitHeight: implicitWidth * (root.isCard ? root.cardHeight / root.cardWidth
                                                 : root.designHeight / root.designWidth)
    readonly property bool isCard: root.f("face", "poster") === "card"
    readonly property real cardWidth: 630
    readonly property real cardHeight: 880

    // the service polls only while this tile is mounted
    Binding {
        target: root.svc
        property: "active"
        value: root.active
        when: root.svc !== null
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.live
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // the ground: the poster's own surface, tinted from the wallpaper's
    // palette — a lit top falling to a deep bottom, not a flat black slab.
    // The card face paints its own silhouette; this rectangle must not show
    // under it, or its square corners leak black wedges past the octagon.
    Rectangle {
        visible: !root.isCard
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: root.mixc(root.wallBase, root.wallAccent, 0.16) }
            GradientStop { position: 1; color: root.mixc(root.wallBase, Qt.rgba(0, 0, 0, 1), 0.45) }
        }
        border.width: 1
        border.color: Theme.border
    }

    Item {
        id: poster
        visible: !root.isCard
        width: root.designWidth
        height: root.designHeight
        // the hero bleeds past the design box on purpose; the poster is the
        // window that crops it, so nothing spills onto the wallpaper
        clip: true
        transform: Scale {
            origin.x: 0
            origin.y: 0
            xScale: root.widthBudget > 0 ? root.widthBudget / root.designWidth : 480 / root.designWidth
            yScale: xScale
        }

        // the accent glow: a soft bloom of the wallpaper's own colour
        // centred behind the figure, so the poster breathes its palette
        Canvas {
            anchors.fill: parent
            readonly property color accent: root.wallAccent
            property real heroX: hero.x + hero.width / 2
            property real heroY: hero.height / 2
            onAccentChanged: requestPaint()
            onHeroXChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var rad = width * 0.34;
                var g = ctx.createRadialGradient(heroX, heroY, 0, heroX, heroY, rad);
                g.addColorStop(0, Qt.rgba(accent.r, accent.g, accent.b, 0.17));
                g.addColorStop(0.6, Qt.rgba(accent.r, accent.g, accent.b, 0.06));
                g.addColorStop(1, Qt.rgba(accent.r, accent.g, accent.b, 0));
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, width, height);
            }
        }

        // corner brackets: thin accent ticks that frame the poster like a
        // collector's mat
        Item {
            id: brackets
            anchors.fill: parent
            readonly property real len: 30
            readonly property real inset: 16
            Repeater {
                model: [
                    { x: brackets.inset, y: brackets.inset, sx: 1, sy: 1 },
                    { x: poster.width - brackets.inset, y: brackets.inset, sx: -1, sy: 1 },
                    { x: brackets.inset, y: poster.height - brackets.inset, sx: 1, sy: -1 },
                    { x: poster.width - brackets.inset, y: poster.height - brackets.inset, sx: -1, sy: -1 }
                ]
                delegate: Item {
                    required property var modelData
                    x: modelData.x
                    y: modelData.y
                    width: 0
                    height: 0
                    Rectangle {
                        width: brackets.len
                        height: 2
                        color: Qt.rgba(root.wallAccent.r, root.wallAccent.g, root.wallAccent.b, 0.55)
                        x: modelData.sx === 1 ? 0 : -width
                    }
                    Rectangle {
                        height: brackets.len
                        width: 2
                        color: Qt.rgba(root.wallAccent.r, root.wallAccent.g, root.wallAccent.b, 0.55)
                        y: modelData.sy === 1 ? 0 : -height
                    }
                }
            }
        }

        // the watermark glyph behind everything
        Text {
            visible: root.blockOn("Watermark")
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -170
            text: root.f("watermarkGlyph", "顔")
            color: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.055)
            font.pixelSize: root.fs(540, 380)
        }

        // the epithets: big faint words that dissolve one into the next
        Item {
            id: kinetic
            visible: root.blockOn("Epithets") && !root.tight
            x: 100
            y: 4
            width: 800
            height: 180
            property int idx: 0
            property real mix: 0
            readonly property real fit: Math.min(1, width / Math.max(1, epithet.implicitWidth))

            Text {
                id: epithet
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: String(root.words[kinetic.idx % Math.max(1, root.words.length)] || "").toUpperCase()
                color: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.2)
                font.family: Theme.font
                font.pixelSize: 210
                font.weight: Font.Medium
                opacity: 1 - kinetic.mix
                transform: Scale {
                    origin.x: 0
                    origin.y: epithet.height / 2
                    xScale: kinetic.fit * (1 + 0.1 * Math.sin(kinetic.mix * Math.PI))
                    yScale: 1 - 0.07 * Math.sin(kinetic.mix * Math.PI)
                }
            }

            // a 1-bit stipple covers the word at the swap
            Canvas {
                anchors.left: epithet.left
                anchors.verticalCenter: epithet.verticalCenter
                anchors.verticalCenterOffset: -epithet.font.pixelSize * 0.11
                width: Math.ceil(epithet.implicitWidth * kinetic.fit) + 6
                height: Math.ceil(epithet.font.pixelSize * 0.82)
                property real m: kinetic.mix
                readonly property color ink: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.24)
                onMChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    if (m < 0.02)
                        return;
                    var cell = 10;
                    var cols = Math.ceil(width / cell), rows = Math.ceil(height / cell);
                    var bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
                    ctx.fillStyle = ink;
                    for (var gy = 0; gy < rows; gy++) {
                        var thr = m * (0.3 + 0.7 * Math.sin((gy + 0.5) / rows * Math.PI));
                        for (var gx = 0; gx < cols; gx++)
                            if ((bayer[gy % 4][gx % 4] + 0.5) / 16 < thr)
                                ctx.fillRect(gx * cell, gy * cell, cell - 1, cell - 1);
                    }
                }
            }

            SequentialAnimation {
                running: root.live && kinetic.visible
                loops: Animation.Infinite
                PauseAnimation { duration: 1300 }
                NumberAnimation { target: kinetic; property: "mix"; from: 0; to: 1; duration: 240; easing.type: Easing.InQuad }
                ScriptAction { script: kinetic.idx = (kinetic.idx + 1) % Math.max(1, root.words.length) }
                NumberAnimation { target: kinetic; property: "mix"; from: 1; to: 0; duration: 240; easing.type: Easing.OutQuad }
                onRunningChanged: if (!running) kinetic.mix = 0
            }
        }

        // the same epithets as a still verse
        Column {
            visible: root.blockOn("Epithets") && !root.tight
            x: root.heroLeft ? 210 : 1030
            y: 400
            spacing: 13
            Repeater {
                model: ["Power", "Beauty", "Decay", "Void"]
                delegate: Text {
                    required property var modelData
                    text: String(modelData).toUpperCase()
                    color: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.2)
                    font.family: Theme.font
                    font.pixelSize: 22
                }
            }
        }

        // the figure, stock or the owner's own picture
        Figure {
            id: hero
            config: root.svc ? root.svc.heroConfig : ({})
            configDir: root.svc ? root.svc.configDir : ""
            overrideFile: String(root.f("art", ""))
            overrideStyle: String(root.f("artStyle", "photo"))
            ink: Theme.bright
            height: root.tight ? 400 : parent.height + 96
            width: height * 900 / 1157
            x: root.tight ? (root.heroLeft ? 40 : poster.width - width - 40)
                          : (poster.width - width) / 2 + 240 * root.heroDir
            y: root.tight ? 30 : (poster.height - height) / 2
        }

        // a slow scan down the figure
        Item {
            visible: root.live
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: hero.x + hero.width * 0.55
            width: hero.width * 0.32
            clip: true
            Rectangle {
                width: parent.width
                height: 62
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0) }
                    GradientStop { position: 0.5; color: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.22) }
                    GradientStop { position: 1; color: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0) }
                }
                SequentialAnimation on y {
                    running: root.live
                    loops: Animation.Infinite
                    NumberAnimation { from: -80; to: root.designHeight + 40; duration: 4600; easing.type: Easing.InOutSine }
                    PauseAnimation { duration: 2600 }
                }
            }
        }

        // the spine along the outer edge
        Text {
            visible: root.blockOn("Marginalia")
            x: root.heroLeft ? poster.width - 21 - width / 2 - height / 2 : 21 - width / 2 + height / 2
            y: poster.height / 2 - height / 2
            rotation: -90
            text: root.f("marginalia", "RYOKU · " + fv(svc ? svc.codename : "-").toUpperCase()
                + " · KERNEL " + fv(svc ? svc.sysKernel : "-"))
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: root.fs(10, 14)
            font.letterSpacing: 2
        }

        // the identity and the small print
        Item {
            id: dossier
            x: root.tight ? (root.heroLeft ? hero.x + hero.width + 40 : 40)
                          : (root.heroLeft ? poster.width - 55 - width : 55)
            y: root.tight ? 40 : 68
            width: root.fs(330, 289)
            height: root.tight ? poster.height - 70 : poster.height - 136

            Column {
                id: head
                width: parent.width
                spacing: 13

                Text {
                    text: qsTr("System card")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: root.fs(12, 18)
                    font.letterSpacing: 1
                }
                Text {
                    id: nameText
                    // with the figure on the left the column sits at the right
                    // edge, so the name stays inside the card
                    width: root.heroLeft ? dossier.width + 20 : 560
                    height: 120
                    text: root.f("name", fv(svc ? svc.sysUser : ""))
                    color: Theme.bright
                    font.family: Theme.font
                    font.weight: Font.Medium
                    font.pixelSize: root.fs(104, 84)
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 30
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                Text {
                    text: "@" + fv(svc ? svc.sysHost : "") + "   ·   "
                        + (root.live
                            ? Qt.formatTime(root.now, Qt.locale().timeFormat(Locale.ShortFormat))
                            : Qt.formatDate(root.now, Qt.locale().dateFormat(Locale.ShortFormat)))
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: root.fs(13, 20)
                }
                Text {
                    width: parent.width
                    text: root.f("tagline", qsTr("For the sake of power and beauty."))
                    color: Theme.dim
                    font.family: Theme.font
                    font.italic: true
                    font.pixelSize: root.fs(16, 22)
                    wrapMode: Text.Wrap
                }
            }

            // the accent rule: a collector's plate mark beside the name
            Rectangle {
                x: head.x + nameText.x - 18
                y: head.y + nameText.y + 14
                width: 3
                height: nameText.height - 28
                radius: 1.5
                color: root.wallAccent
            }

            Column {
                id: foot
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: root.fs(10, 14)

                Column {
                    width: parent.width
                    visible: root.blockOn("Specs")
                    Repeater {
                        model: [
                            { k: qsTr("Processor"), v: fv(svc ? svc.sysCpu : "") },
                            { k: qsTr("Graphics"), v: svc ? svc.gpuShort : "-" },
                            { k: qsTr("RAM"), v: fv(svc ? svc.sysRam : "") },
                            { k: qsTr("Storage"), v: fv(svc ? svc.sysDisk : "") },
                            { k: qsTr("Resolution"), v: fv(svc ? svc.sysResolution : "") + (svc && svc.sysRefresh.length > 0 ? " @ " + svc.sysRefresh : "") },
                            { k: qsTr("Window manager"), v: (svc ? svc.sysWm : "-") + (svc && svc.sysWmVer && svc.sysWmVer !== "-" ? " " + svc.sysWmVer.replace(/^v+/, "v") : "") },
                            { k: qsTr("Up for"), v: fv(svc ? svc.sysUptime : "") }
                        ]
                        delegate: Item {
                            required property var modelData
                            width: foot.width
                            height: root.fs(18, 26)
                            Text {
                                id: specKey
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.k
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: root.fs(9, 16)
                            }
                            Text {
                                id: specValue
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, parent.width * 0.66)
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                text: modelData.v
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: root.fs(10, 17)
                            }
                            Rectangle {
                                anchors.left: specKey.right
                                anchors.right: specValue.left
                                anchors.leftMargin: 13
                                anchors.rightMargin: 13
                                anchors.verticalCenter: parent.verticalCenter
                                height: 1
                                color: Theme.hair
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.blockOn("Packages") && svc && !root.tight
                    readonly property real share: {
                        var total = Math.max(1, parseInt(svc ? svc.sysPackages : "-") || 1);
                        var mine = (parseInt(svc ? svc.sysPkgExplicit : 0) || 0) + (parseInt(svc ? svc.sysPkgAur : 0) || 0);
                        return Math.max(0, Math.min(1, mine / total));
                    }
                    Canvas {
                        width: parent.width
                        height: 21
                        property real share: parent.share
                        readonly property color track: Theme.border
                        readonly property color ink: Theme.bright
                        onShareChanged: requestPaint()
                        onTrackChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var mid = height / 2;
                            ctx.lineWidth = 2;
                            var wave = function (to) {
                                ctx.beginPath();
                                for (var x = 0; x <= to; x += 1.5) {
                                    var y = mid + 3 * Math.sin(x * 0.45);
                                    if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                                }
                                ctx.stroke();
                            };
                            ctx.strokeStyle = track;
                            wave(width);
                            if (share * width > 1) {
                                ctx.strokeStyle = ink;
                                wave(share * width);
                            }
                        }
                    }
                    Text {
                        text: svc && /^\d+$/.test(svc.sysPkgAur)
                            ? qsTr("%1 chosen · %2 from the AUR · %3 in all").arg(svc.sysPkgExplicit).arg(svc.sysPkgAur).arg(svc.sysPackages)
                            : qsTr("%1 chosen · %2 in all").arg(svc ? svc.sysPkgExplicit : "-").arg(svc ? svc.sysPackages : "-")
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
                }

                Row {
                    width: parent.width
                    height: root.fs(18, 22)
                    visible: root.blockOn("Palette") && root.palette.length > 0
                    Repeater {
                        model: root.palette
                        delegate: Rectangle {
                            required property var modelData
                            width: foot.width / Math.max(1, root.palette.length)
                            height: 18
                            color: String(modelData)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: barcode.implicitHeight
                    visible: root.blockOn("Barcode")
                    Barcode {
                        id: barcode
                        text: root.barcodeText
                        ink: Theme.bright
                        unit: Math.max(1, Math.min(2, (foot.width * 0.62) / (Math.max(1, String(root.barcodeText).length + 2) * 16)))
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        text: qsTr("No. %1").arg(root.editionNo())
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: root.fs(11, 14)
                    }
                }
            }
        }

        // live readings pinned to the figure by thin leaders
        Item {
            id: telemetry
            anchors.fill: parent
            visible: root.blockOn("Telemetry")
            readonly property real cx: root.tight ? 40 : root.heroLeft ? poster.width - 55 - 172 : 55
            readonly property real leadFrom: root.tight ? 40 : root.heroLeft ? poster.width - 55 - 172 : 55 + 172
            readonly property var shown: root.f("vitals", ["core", "gpu", "mem", "net", "frac"])
            // the readings share the room between the name and the small print
            readonly property real footTop: dossier.y + foot.y - 13
            readonly property real span: telemetry.footTop - root.fs(338, 470)
            readonly property bool full: telemetry.span >= 3 * 64 + 64
            readonly property bool micro: !telemetry.full && (telemetry.span - 50) / 3 < 50
            readonly property real gap: telemetry.full ? 64 : telemetry.micro ? Math.min(64, Math.max(40, Math.floor((telemetry.span - 40) / 3)))
                                                                             : Math.min(64, Math.max(50, Math.floor((telemetry.span - 50) / 3)))
            readonly property real rowH: telemetry.full ? 64 : telemetry.micro ? 38 : 50
            readonly property real firstY: root.tight
                ? Math.max(445, Math.min(470, telemetry.footTop - (3 * telemetry.gap + telemetry.rowH)))
                : Math.max(316, Math.min(338, telemetry.footTop - (3 * telemetry.gap + telemetry.rowH)))
            readonly property var pins: [
                { x: cx, sx: leadFrom, cy: firstY, fx: 0.36, fy: 0.26, k: "core", name: qsTr("Core"), big: true },
                { x: cx, sx: leadFrom, cy: firstY + gap, fx: 0.30, fy: 0.40, k: "gpu", name: qsTr("Graphics"), big: true },
                { x: cx, sx: leadFrom, cy: firstY + 2 * gap, fx: 0.28, fy: 0.54, k: "mem", name: qsTr("Memory"), big: true },
                { x: cx, sx: leadFrom, cy: firstY + 3 * gap, fx: 0.40, fy: 0.70, k: "net", name: qsTr("Network"), big: true },
                { x: root.tight ? 400 : root.heroLeft ? poster.width - 372 - 120 : 372, sx: root.tight ? 400 : root.heroLeft ? poster.width - 372 : 372, cy: root.tight ? firstY : firstY + Math.round(gap * 0.94), fx: 0.47, fy: 0.44, k: "frac", name: qsTr("Release"), big: false }
            ].filter(p => shown.indexOf(p.k) >= 0)

            Text {
                x: telemetry.cx
                y: root.fs(296, 440)
                text: qsTr("Live readings")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: root.fs(11, 18)
                font.letterSpacing: 1
            }

            Canvas {
                id: leads
                anchors.fill: parent
                visible: !root.tight
                readonly property color ink: Theme.bright
                property var pins: telemetry.pins
                property real heroX: hero.x
                property real heroY: hero.y
                property real heroW: hero.width
                property real heroH: hero.height
                property real rowScale: telemetry.micro ? 26 : 30
                onPinsChanged: requestPaint()
                onHeroXChanged: requestPaint()
                onInkChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    for (var i = 0; i < pins.length; i++) {
                        var p = pins[i];
                        var dx = heroX + p.fx * heroW;
                        var dy = heroY + p.fy * heroH;
                        var sy = p.cy + (p.big ? rowScale : 22);
                        ctx.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.3);
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(p.sx, sy);
                        ctx.lineTo(dx, dy);
                        ctx.stroke();
                        ctx.fillStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.9);
                        ctx.beginPath();
                        ctx.arc(dx, dy, 2.6, 0, 6.2832);
                        ctx.fill();
                    }
                }
            }

            Repeater {
                model: telemetry.pins
                delegate: Column {
                    required property var modelData
                    x: modelData.x
                    y: modelData.cy
                    spacing: -1
                    readonly property real barPct: {
                        if (!root.svc)
                            return 0;
                        if (modelData.k === "core")
                            return root.svc.cpu / 100;
                        if (modelData.k === "gpu")
                            return root.svc.gpuUtil / 100;
                        if (modelData.k === "mem")
                            return root.svc.ram / 100;
                        if (modelData.k === "net")
                            return Math.min(1, (root.svc.netDown + root.svc.netUp) / 1048576);
                        return 0;
                    }
                    readonly property color barCol: {
                        if (!root.svc)
                            return root.wallAccent;
                        if (modelData.k === "core")
                            return root.heat(root.svc.cpuTemp);
                        if (modelData.k === "gpu")
                            return root.heat(root.svc.gpuTemp);
                        return root.wallAccent;
                    }
                    readonly property color bigCol: {
                        if (!root.svc)
                            return Theme.bright;
                        if (modelData.k === "core")
                            return root.heat(root.svc.cpuTemp);
                        if (modelData.k === "gpu")
                            return root.heat(root.svc.gpuTemp);
                        return Theme.bright;
                    }
                    Text {
                        text: modelData.name
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: root.fs(10, 14)
                    }
                    Text {
                        text: root.statBig(modelData.k)
                        color: parent.bigCol
                        font.family: Theme.font
                        font.pixelSize: modelData.big ? (root.tight ? 30 : (telemetry.micro ? 22 : 30)) : root.fs(15, 20)
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        visible: telemetry.full || !modelData.big
                        text: root.statSub(modelData.k)
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: root.fs(10, 14)
                    }
                    // the thin usage bar: load, utilisation, memory, throughput
                    Item {
                        visible: modelData.big
                        width: root.fs(150, 240)
                        height: 6
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 2
                            color: Theme.border
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: 2
                            radius: 1
                            width: parent.width * parent.parent.barPct
                            color: parent.parent.barCol
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                        }
                    }
                }
            }
        }

        // the signal: load average over a moving wave
        Item {
            visible: root.blockOn("Signal") && !root.tight
            x: root.heroLeft ? 55 : poster.width - 55 - width
            y: poster.height - 55 - height
            width: 240
            height: 58
            Text {
                text: qsTr("Signal")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11
            }
            Text {
                anchors.right: parent.right
                text: qsTr("Load %1").arg(svc ? svc.load.toFixed(2) : "0.00")
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11
            }
            // a damped wave in the card's ink, travelling only while live
            Canvas {
                id: wave
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 34
                property real phase: 0
                readonly property color ink: Theme.bright
                onPhaseChanged: requestPaint()
                onInkChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var mid = height / 2;
                    ctx.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.85);
                    ctx.lineWidth = 1.5;
                    ctx.beginPath();
                    for (var x = 0; x <= width; x += 1) {
                        var t = x / Math.max(1, width);
                        var amp = (mid - 2) * Math.exp(-2.6 * t) * (0.55 + 0.45 * Math.sin(t * 9 + wave.phase * 0.5));
                        var y = mid + amp * Math.sin(x * 0.32 - wave.phase);
                        if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    ctx.stroke();
                }
                NumberAnimation on phase {
                    running: root.live
                    from: 0
                    to: Math.PI * 2
                    duration: 1400
                    loops: Animation.Infinite
                }
            }
        }
    }

    // the collectible face: the trading card, scaled the same way. While the
    // cursor is over the tile (and `motion` is on) the card tilts toward it
    // in 3D and the foils lock their sheen under the pointer — the card
    // comes alive the way a real holo card does under a lamp.
    readonly property real cardScale: root.widthBudget > 0
        ? root.widthBudget / root.cardWidth : 480 / root.cardWidth

    // tilt state: animated on its own, then read by the rotations. The
    // plugin runtime ships a minimal QtQuick (no perspective transform),
    // so the tilt is an honest orthographic one — the card turns like
    // paper under the cursor and the foils do the rest.
    property real tiltX: cardFace.touched ? cardFace.hy * -13 : 0
    property real tiltY: cardFace.touched ? cardFace.hx * 17 : 0
    Behavior on tiltX { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
    Behavior on tiltY { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

    Card {
        id: cardFace
        visible: root.isCard
        width: root.cardWidth
        height: root.cardHeight
        svc: root.svc
        st: root.st
        live: root.live
        touched: cardHover.containsMouse && root.live
        hx: cardHover.mouseX / Math.max(1, cardHover.width) - 0.5
        hy: cardHover.mouseY / Math.max(1, cardHover.height) - 0.5
        transform: [
            Scale {
                origin.x: 0
                origin.y: 0
                xScale: root.cardScale
                yScale: root.cardScale
            },
            Rotation {
                origin.x: root.cardWidth / 2
                origin.y: root.cardHeight / 2
                axis: Qt.vector3d(1, 0, 0)
                angle: root.tiltX
            },
            Rotation {
                origin.x: root.cardWidth / 2
                origin.y: root.cardHeight / 2
                axis: Qt.vector3d(0, 1, 0)
                angle: root.tiltY
            }
        ]
    }

    // hover catcher sized to the scaled card, not the design box; NoButton
    // so the host's drag, resize and right-click all pass straight through.
    MouseArea {
        id: cardHover
        visible: root.isCard
        enabled: root.live
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.cardWidth * root.cardScale
        height: root.cardHeight * root.cardScale
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
