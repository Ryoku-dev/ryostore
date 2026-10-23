import QtQuick
import Ryoku.PluginKit.Singletons

// GPU panel, laid out like the Ryoku CPU panel: header, model line, usage bar,
// history graph, details, top processes and an Open btop button. Rows a GPU
// doesn't report (VRAM on an iGPU, throttling on AMD, ...) are hidden.
// All colour comes from the plugin kit Theme, so it follows the Ryoku theme.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 340
    property bool active: false

    readonly property var svc: pluginApi ? pluginApi.mainInstance : null
    readonly property real btnRadius: 6 * root.s
    readonly property color track: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.10)

    function ghz(mhz) {
        return (mhz / 1000).toFixed(2);
    }
    function pct(v) {
        return Math.round(v) + "%";
    }
    function gb(bytes) {
        return (bytes / 1073741824).toFixed(1);
    }

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    component Divider: Rectangle {
        width: col.width
        height: 1
        color: Theme.frameBorder
    }

    component KV: Item {
        property string k: ""
        property string v: ""
        property color vColor: Theme.bright
        property bool show: true
        visible: show
        width: col.width
        height: 24 * root.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.k
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: 11 * root.s
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: parent.v
            color: parent.vColor
            font.family: Theme.mono
            font.pixelSize: 11 * root.s
        }
    }

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.width - 24 * root.s
        spacing: 6 * root.s

        // ── header ──
        Item {
            width: col.width
            height: 24 * root.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "GPU"
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: 13 * root.s
                font.letterSpacing: 3
                font.weight: Font.Medium
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: !root.svc ? "" : (root.svc.driver
                          + (root.svc.codename !== "" ? " · " + root.svc.codename : "")).toUpperCase()
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 1
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeArea.containsMouse ? Theme.accent : Theme.dim
                    font.pixelSize: 12 * root.s
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.pluginApi) root.pluginApi.closePanel()
                    }
                }
            }
        }

        Divider {}

        // ── no Intel card ──
        Text {
            visible: root.svc !== null && !root.svc.found
            width: col.width
            wrapMode: Text.WordWrap
            text: "No supported GPU found (i915, xe, amdgpu or nvidia)."
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 11 * root.s
        }

        Column {
            width: col.width
            spacing: 6 * root.s
            visible: root.svc === null || root.svc.found

            // ── model ──
            KV {
                k: root.svc ? root.svc.gpuName : ""
                v: !root.svc ? "" : root.svc.vramTotal > 0 ? root.gb(root.svc.vramTotal) + " GB" : "iGPU"
            }

            // ── usage bar ──
            Item {
                width: col.width
                height: 20 * root.s

                Text {
                    id: usageLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "USAGE"
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 11 * root.s
                    font.letterSpacing: 1
                }

                Rectangle {
                    id: barTrack
                    anchors.left: usageLabel.right
                    anchors.leftMargin: 10 * root.s
                    anchors.right: usageValue.left
                    anchors.rightMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8 * root.s
                    radius: height / 2
                    color: root.track

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                        width: Math.max(parent.height, parent.width * (root.svc ? root.svc.busy : 0) / 100)
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }

                Text {
                    id: usageValue
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36 * root.s
                    horizontalAlignment: Text.AlignRight
                    text: root.svc && root.svc.ready ? root.pct(root.svc.busy) : "--"
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 11 * root.s
                }
            }

            // ── history graph ──
            Canvas {
                id: graph
                width: col.width
                height: 40 * root.s
                readonly property var pts: root.svc ? root.svc.history : []
                readonly property color line: Theme.accent
                onPtsChanged: requestPaint()
                onLineChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var p = graph.pts;
                    if (!p || p.length < 2)
                        return;
                    var stepX = width / 59;
                    var x0 = width - (p.length - 1) * stepX;
                    ctx.strokeStyle = graph.line;
                    ctx.lineWidth = 1.5;
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    for (var i = 0; i < p.length; i++) {
                        var x = x0 + i * stepX;
                        var y = height - 2 - (p[i] / 100) * (height - 4);
                        if (i === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.stroke();
                }
            }

            Divider {}

            // ── details ──
            KV {
                k: "Clock"
                show: root.svc !== null && root.svc.actMhz >= 0
                v: !root.svc ? "" : root.ghz(root.svc.actMhz)
                   + (root.svc.maxMhz > 0 ? " / " + root.ghz(root.svc.maxMhz) : "") + " GHz"
            }
            KV {
                k: "Requested"
                show: root.svc !== null && root.svc.curMhz >= 0
                v: root.svc ? root.ghz(root.svc.curMhz) + " GHz" : ""
            }
            KV {
                k: "Engines"
                show: root.svc !== null && root.svc.mediaBusy >= 0
                v: root.svc ? "Render " + root.pct(root.svc.busy) + " · Media " + root.pct(root.svc.mediaBusy) : ""
            }
            KV {
                k: "Range"
                show: root.svc !== null && root.svc.minMhz > 0 && root.svc.maxMhz > 0
                v: root.svc ? root.ghz(root.svc.minMhz) + " – " + root.ghz(root.svc.maxMhz) + " GHz" : ""
            }
            KV {
                k: "VRAM"
                show: root.svc !== null && root.svc.vramTotal > 0
                v: root.svc ? root.gb(Math.max(0, root.svc.vramUsed)) + " / " + root.gb(root.svc.vramTotal) + " GB" : ""
            }
            KV {
                k: root.svc && root.svc.tempSrc === "gpu" ? "GPU temp" : "Package temp"
                show: root.svc !== null && root.svc.temp >= 0
                v: root.svc ? Math.round(root.svc.temp) + "°C" : ""
            }
            KV {
                k: "Throttling"
                show: root.svc !== null && root.svc.throttleKnown
                v: root.svc && root.svc.throttle !== ""
                   ? root.svc.throttle.split(",").map(function(r) { return r.toUpperCase(); }).join(" · ")
                   : "None"
                vColor: Theme.accent
            }

            Divider {}

            // ── top processes ──
            Item {
                width: col.width
                height: 20 * root.s

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TOP PROCESSES"
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 1
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "GPU"
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 1
                }
            }

            Text {
                visible: !root.svc || root.svc.topProcs.length === 0
                text: "No GPU activity"
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
            }

            Repeater {
                model: root.svc ? root.svc.topProcs : []

                delegate: Item {
                    id: proc
                    required property var modelData
                    required property int index
                    width: col.width
                    height: 22 * root.s

                    Text {
                        id: rank
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24 * root.s
                        text: String(proc.index + 1).padStart(2, "0")
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 11 * root.s
                    }
                    Text {
                        anchors.left: rank.right
                        anchors.right: procPct.left
                        anchors.rightMargin: 8 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: proc.modelData.name
                        color: Theme.bright
                        font.family: Theme.mono
                        font.pixelSize: 11 * root.s
                    }
                    Text {
                        id: procPct
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: proc.modelData.pct.toFixed(1) + "%"
                        color: Theme.bright
                        font.family: Theme.mono
                        font.pixelSize: 11 * root.s
                    }
                }
            }
        }

        Divider {}

        Item { width: 1; height: 2 * root.s }

        // ── Open btop ──
        Rectangle {
            width: col.width
            height: 30 * root.s
            radius: root.btnRadius
            color: btopArea.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "Open btop"
                color: Theme.cardBot
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
            }

            MouseArea {
                id: btopArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.svc) root.svc.openMonitor()
            }
        }
    }
}
