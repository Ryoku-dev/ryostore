pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

// The bar panel: the plugin's full view, mounted by the host in the shared
// plugin panel surface under the glyph. It reads the fan state off the service and
// lays out a readout (rpm, per-fan rows, the hottest sensors), the three
// profiles, and a custom level slider.
//
// Every privileged write is a deliberate tap here: AUTO hands the fans back to
// the EC, PERFORMANCE a fixed high level, MAX full speed, and APPLY the level
// picked on the slider. Each one goes through pkexec, so the desktop asks for
// authorisation the first time. The host owns the surface and sizes the card to
// this root's implicitHeight, so no window chrome is drawn here.
Item {
    id: root

    // Host-set; read only, never assign.
    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 320
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property real w: widthBudget > 0 ? widthBudget : 320
    readonly property int rpm: service ? service.rpm : -1
    readonly property var fans: service ? service.fans : []
    readonly property var temps: service ? service.topTemps : []
    readonly property string profile: service ? service.profile : "unknown"
    readonly property bool controllable: service ? service.controllable : false
    readonly property bool restricted: service ? service.restricted : false
    readonly property bool usable: controllable && !restricted
    readonly property bool busy: service ? service.busy : false
    readonly property int liveLevel: service ? service.level : -1
    readonly property string chip: service ? service.chip : ""
    readonly property string statusLine: service ? service.lastAction : ""

    // The status line turns to the warning colour when the last action did not
    // land, so a refusal never hides in the same grey as "all good".
    function isError(s) {
        var t = String(s).toLowerCase();
        return t.indexOf("fail") >= 0 || t.indexOf("refus") >= 0
            || t.indexOf("dismiss") >= 0 || t.indexOf("error") >= 0
            || t.indexOf("could not") >= 0;
    }
    // Kernel labels are human names ("CPU", "Package id 0"); a label that is just
    // the attribute id means the chip has none, so the chip name is shown instead.
    function sensorLabel(t) {
        if (/^temp\d+$/.test(String(t.label))) return String(t.chip);
        return String(t.label);
    }

    readonly property string pillText: {
        if (!controllable) return qsTr("NO PWM");
        if (profile === "auto") return qsTr("AUTO");
        if (profile === "max") return qsTr("MAX");
        if (profile === "manual") return liveLevel > 0 ? qsTr("MANUAL %1").arg(liveLevel) : qsTr("MANUAL");
        return qsTr("UNKNOWN");
    }
    readonly property color pillInk: {
        if (!controllable) return Theme.dim;
        if (profile === "auto") return Theme.dim;
        if (profile === "unknown") return Theme.dim;
        return Theme.accent;
    }

    // The panel slider's own value: seeded once from the saved setting, and only
    // pushed to the machine when APPLY is tapped.
    property int custom: 191
    property bool touched: false
    function seedCustom() {
        if (root.touched || !root.service) return;
        root.custom = root.service.customLevel;
    }
    Component.onCompleted: seedCustom()
    Connections {
        target: root.service
        function onHaveStateChanged() { root.seedCustom(); }
    }

    implicitWidth: root.w
    implicitHeight: col.implicitHeight + 24 * root.s

    // ── reusable bits ────────────────────────────────────────────────────────
    component Eyebrow: Row {
        id: eb
        property string label: ""
        spacing: 7 * root.s
        Rectangle {
            width: 5 * root.s
            height: 5 * root.s
            radius: 1 * root.s
            color: Theme.brand
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: eb.label
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10 * root.s
            font.weight: Font.DemiBold
            font.letterSpacing: 2.2 * root.s
            font.capitalization: Font.AllUppercase
        }
    }

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: Theme.hair
    }

    // A bordered mono button; `filled` marks the profile the machine is on.
    component Btn: Rectangle {
        id: btn
        property string label: ""
        property bool filled: false
        property bool enabledAction: true
        signal tapped()
        implicitWidth: btnText.implicitWidth + 18 * root.s
        implicitHeight: 24 * root.s
        radius: 0
        color: btn.filled ? Theme.accent
            : (btnHover.hovered && btn.enabledAction ? Theme.sheen : "transparent")
        border.width: 1
        border.color: btn.enabledAction ? (btn.filled ? Theme.accent : Theme.border) : Theme.border
        opacity: btn.enabledAction ? 1 : 0.5
        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: btn.filled ? Theme.cardBot : Theme.cream
            font.family: Theme.mono
            font.pixelSize: 9.5 * root.s
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4 * root.s
        }
        HoverHandler { id: btnHover; cursorShape: btn.enabledAction ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: btn.enabledAction; onTapped: btn.tapped() }
    }

    // A flat brutalist level slider over the helper's 128-255 range.
    component LevelSlider: Item {
        id: sl
        property int value: 191
        property int from: 128
        property int to: 255
        signal moved(int v)
        implicitHeight: 18 * root.s

        readonly property real span: width - handle.width
        readonly property real frac: to > from ? (value - from) / (to - from) : 0

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4 * root.s
            color: Theme.hair
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            width: handle.x + handle.width / 2
            height: 4 * root.s
            color: Theme.accent
        }
        Rectangle {
            id: handle
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(sl.frac * sl.span)
            width: 3 * root.s
            height: 14 * root.s
            color: Theme.cream
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function setFromX(x) {
                if (sl.span <= 0) return;
                var f = Math.max(0, Math.min(1, (x - handle.width / 2) / sl.span));
                sl.value = Math.round(sl.from + f * (sl.to - sl.from));
                root.touched = true;
                sl.moved(sl.value);
            }
            onPressed: (m) => setFromX(m.x)
            onPositionChanged: (m) => { if (pressed) setFromX(m.x) }
        }
    }

    // ── content ──────────────────────────────────────────────────────────────
    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.w - 24 * root.s
        spacing: 11 * root.s

        // head: title + the profile the machine is actually on
        Item {
            width: parent.width
            height: 20 * root.s
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("FAN CONTROL")
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 13 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 2.4 * root.s
            }
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: pill.implicitWidth + 14 * root.s
                height: 17 * root.s
                radius: 0
                color: "transparent"
                border.width: 1
                border.color: root.pillInk
                Text {
                    id: pill
                    anchors.centerIn: parent
                    text: root.pillText
                    color: root.pillInk
                    font.family: Theme.mono
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.6 * root.s
                }
            }
        }

        // readout: the big number, then the machine's own naming
        Item {
            width: parent.width
            height: bigNum.implicitHeight
            Text {
                id: bigNum
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.rpm >= 0 ? String(root.rpm) : "\u2014"
                color: root.rpm > 0 ? Theme.cream : Theme.dim
                font.family: Theme.mono
                font.pixelSize: 30 * root.s
                font.weight: Font.DemiBold
            }
            Text {
                x: bigNum.x + bigNum.implicitWidth + 7 * root.s
                anchors.baseline: bigNum.baseline
                text: qsTr("rpm")
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
            }
        }

        Text {
            width: parent.width
            text: {
                var parts = [];
                if (root.chip.length > 0) parts.push(root.chip);
                if (root.fans.length > 1) parts.push(root.fans.length + " " + qsTr("fans"));
                parts.push(root.profile === "manual" && root.liveLevel >= 0
                    ? qsTr("manual level %1/255").arg(root.liveLevel)
                    : root.profile === "auto" ? qsTr("EC auto curve") : qsTr("full speed"));
                return parts.join(" \u00b7 ");
            }
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 10.5 * root.s
            elide: Text.ElideRight
        }

        Divider {}

        // temperatures: the hottest readable sensors, gold past the warning mark
        Column {
            width: parent.width
            spacing: 4 * root.s
            visible: root.temps.length > 0

            Eyebrow { label: qsTr("Temperatures"); opacity: 0.9 }

            Repeater {
                model: root.temps
                delegate: Item {
                    id: trow
                    required property var modelData
                    width: parent ? parent.width : 0
                    height: 15 * root.s
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - tval.width - 8 * root.s
                        text: root.sensorLabel(trow.modelData)
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        elide: Text.ElideRight
                    }
                    Text {
                        id: tval
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(trow.modelData.celsius) + "\u00b0C"
                        color: trow.modelData.celsius >= root.service.warnTemp ? Theme.gold : Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 11.5 * root.s
                    }
                }
            }
        }

        Divider {}

        // profiles: the three taps that change the machine
        Column {
            width: parent.width
            spacing: 8 * root.s
            visible: root.usable

            Eyebrow { label: qsTr("Profiles") }

            Row {
                spacing: 6 * root.s
                Btn {
                    label: qsTr("AUTO")
                    filled: root.profile === "auto"
                    enabledAction: !root.busy
                    onTapped: if (root.service) root.service.applyAuto()
                }
                Btn {
                    label: qsTr("PERFORMANCE")
                    filled: root.profile === "manual"
                    enabledAction: !root.busy
                    onTapped: if (root.service) root.service.applyPerformance()
                }
                Btn {
                    label: qsTr("MAX")
                    filled: root.profile === "max"
                    enabledAction: !root.busy
                    onTapped: if (root.service) root.service.applyMax()
                }
            }

            // custom level
            Item {
                width: parent.width
                height: 15 * root.s
                Eyebrow { label: qsTr("Custom level"); anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.custom + " / 255"
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 11 * root.s
                }
            }

            Row {
                width: parent.width
                spacing: 8 * root.s
                LevelSlider {
                    id: slider
                    width: parent.width - applyBtn.width - 8 * root.s
                    value: root.custom
                    onMoved: (v) => root.custom = v
                }
                Btn {
                    id: applyBtn
                    label: qsTr("APPLY")
                    enabledAction: !root.busy
                    onTapped: if (root.service) root.service.applyCustom(root.custom)
                }
            }

            Text {
                width: parent.width
                visible: root.busy
                text: qsTr("waiting for authorisation\u2026")
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
            }

            // Say plainly which helper will run, because it decides whether the
            // desktop asks for a password.
            Text {
                width: parent.width
                text: root.service && root.service.helperIsSystem
                    ? qsTr("writes via %1 \u00b7 no prompt").arg(root.service.systemHelper)
                    : qsTr("writes via the plugin's own helper \u00b7 asks for authorisation")
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9.5 * root.s
                wrapMode: Text.WordWrap
            }
        }

        // what to say when the machine cannot be controlled
        Column {
            width: parent.width
            spacing: 6 * root.s
            visible: !root.usable

            Eyebrow { label: qsTr("Read only") }

            Text {
                width: parent.width
                text: root.restricted
                    ? qsTr("The kernel refuses fan writes: thinkpad_acpi is loaded with fan_control=N. Load it with fan_control=1 to enable the profiles here.")
                    : (root.service && root.service.blockReason.length > 0
                        ? root.service.blockReason
                        : qsTr("No controllable fan was found on this machine."))
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                wrapMode: Text.WordWrap
            }
        }

        // last action / error, when there is one
        Text {
            width: parent.width
            visible: root.statusLine.length > 0
            text: root.statusLine
            color: root.isError(root.statusLine) ? Theme.gold : Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10 * root.s
            wrapMode: Text.WordWrap
        }
    }
}
