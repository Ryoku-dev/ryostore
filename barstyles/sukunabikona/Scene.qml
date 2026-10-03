pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import Ryoku.Ui.Singletons
import shell.services
import "components" as C

// Sukunabikona
//
// An adaptive store bar style: an empty/floating-only workspace shows the full
// left command rail; the first tiled window collapses it into the three-pill top
// bar. All window-manager state is read through Ryoku's Wm facade so the style
// does not bind to a compositor implementation.
Scope {
    id: shell

    property var modelData: null
    property date now: new Date()
    property bool railPinned: false
    property bool railHidden: false

    // Per-output window state through the public Ryoku WM facade.
    readonly property string outputName: shell.modelData ? String(shell.modelData.name || "") : ""
    readonly property var outputState: shell.outputName.length > 0 ? Wm.outputByName(shell.outputName) : null
    readonly property string workspaceKey: {
        if (shell.outputState && shell.outputState.activeWorkspace)
            return String(shell.outputState.activeWorkspace)
        if (Wm.focusedWorkspace && (!shell.outputName || String(Wm.focusedWorkspace.output || "") === shell.outputName))
            return String(Wm.focusedWorkspace.name || Wm.focusedWorkspace.id || "")
        return ""
    }
    readonly property var workspace: shell.workspaceKey.length > 0 ? Wm.workspaceByName(shell.workspaceKey) : null
    readonly property var workspaceWindows: {
        const out = []
        const wins = Wm.windows || []
        for (let i = 0; i < wins.length; ++i) {
            const w = wins[i]
            if (!w || String(w.workspace || "") !== shell.workspaceKey)
                continue
            if (shell.outputName && w.output && String(w.output) !== shell.outputName)
                continue
            out.push(w)
        }
        return out
    }
    readonly property int windowCount: shell.workspaceWindows.length
    readonly property int floatingCount: shell.workspaceWindows.filter(w => w && w.floating === true).length
    readonly property int tiledCount: shell.workspaceWindows.filter(w => w && w.floating !== true).length
    readonly property bool compact: shell.railHidden || (shell.tiledCount > 0 && !shell.railPinned)
    readonly property bool hasFullscreen: shell.outputName.length > 0 && Wm.outputHasFullscreen(shell.outputName)
    readonly property var activeWindow: {
        const focused = Wm.focusedWindow
        if (focused && (!shell.outputName || !focused.output || String(focused.output) === shell.outputName))
            return focused
        let best = null
        const wins = shell.workspaceWindows
        for (let i = 0; i < wins.length; ++i) {
            const w = wins[i]
            if (!best || (typeof w.focusOrder === "number" && w.focusOrder >= 0 && (best.focusOrder < 0 || w.focusOrder < best.focusOrder)))
                best = w
        }
        return best
    }
    readonly property string activeClass: shell.activeWindow
        ? shell.trim(shell.activeWindow.appId, "DESKTOP").toUpperCase() : "DESKTOP"
    readonly property string activeTitle: shell.activeWindow
        ? shell.trim(shell.activeWindow.title, "RYOKU") : "RYOKU"
    readonly property string workspaceDisplay: {
        if (!shell.workspace)
            return "--"
        const key = String(shell.workspace.name || shell.workspace.id || shell.workspaceKey)
        const n = Number(key)
        if (!isNaN(n) && n >= 0)
            return String(Math.floor(n)).padStart(2, "0")
        const names = shell.workspaceNames()
        const at = names.indexOf(key)
        return at >= 0 ? String(at + 1).padStart(2, "0") : "--"
    }

    // Ryoku live palette. This is the same Matugen/theme data plane used by the
    // rest of the shell, so no file poller or second theme engine exists here.
    readonly property color bg: Theme.surface
    readonly property color raised: Theme.surfaceContainerLow
    readonly property color raisedSoft: Theme.surfaceContainerHigh
    readonly property color ivory: Theme.onSurface
    readonly property color soft: Theme.onSurfaceVariant
    readonly property color mutedText: Qt.rgba(soft.r, soft.g, soft.b, 0.72)
    readonly property color accent: Theme.primary
    readonly property color accentDark: Theme.secondary
    readonly property color accentQuiet: Qt.rgba(accent.r, accent.g, accent.b, 0.58)
    readonly property color brand: Theme.primary
    readonly property color brandQuiet: Qt.rgba(brand.r, brand.g, brand.b, 0.72)
    readonly property color hairline: Qt.rgba(ivory.r, ivory.g, ivory.b, 0.26)
    readonly property color lineSoft: Qt.rgba(ivory.r, ivory.g, ivory.b, 0.13)
    readonly property color tint10: Qt.rgba(ivory.r, ivory.g, ivory.b, 0.10)
    readonly property color bone: Theme.inverseSurface
    readonly property color inkOnBone: Theme.inverseOnSurface
    readonly property color inkOnBoneDim: Qt.rgba(inkOnBone.r, inkOnBone.g, inkOnBone.b, 0.62)
    readonly property color onAccent: Theme.onPrimary
    readonly property string fontDisplay: Theme.display
    readonly property string fontUi: Theme.fontPrimary
    readonly property string fontMono: Theme.mono
    readonly property string fontJp: Theme.fontJp

    // Shared shell services, rather than a second MPRIS/PipeWire stack.
    readonly property var mediaPlayer: Media.player
    readonly property int volumePercent: (Audio.sink && Audio.sink.audio)
        ? Math.round(Audio.sink.audio.volume * 100) : 0
    readonly property bool muted: !!(Audio.sink && Audio.sink.audio && Audio.sink.audio.muted)
    readonly property string networkName: Network.vpnActive
        ? (Network.vpnName || "VPN")
        : Network.kind === "wifi"
            ? (Network.activeSsid || "WIFI")
            : Network.kind === "ethernet" ? "ETHERNET" : "OFFLINE"

    // The full rail's live machine telemetry is already provided by Ryoku.
    readonly property int cpuPercent: Math.round(Sysinfo.cpu * 100)
    readonly property int memoryPercent: Math.round(Sysinfo.mem * 100)
    readonly property int gpuPercent: Math.round(StatsFeed.gpuPct)
    readonly property int diskPercent: StatsFeed.diskTotalGiB > 0
        ? Math.round(StatsFeed.diskUsedGiB * 100 / StatsFeed.diskTotalGiB) : 0
    readonly property int temperature: Sysinfo.hasTemp ? Math.round(Sysinfo.tempC) : Math.round(StatsFeed.gpuTempC)
    readonly property real ramUsedGiB: Sysinfo.memUsedGiB
    readonly property real ramTotalGiB: Sysinfo.memTotalGiB
    readonly property real diskUsedGiB: StatsFeed.diskUsedGiB
    readonly property real diskTotalGiB: StatsFeed.diskTotalGiB
    readonly property string uptimeText: Session.uptimeText.toUpperCase()
    readonly property int cpuTemperature: Sysinfo.hasTemp ? Math.round(Sysinfo.tempC) : 0
    readonly property int gpuTemperature: Math.round(StatsFeed.gpuTempC)
    readonly property real gpuPowerWatts: StatsFeed.gpuPowerW
    readonly property int cavaBarCount: 24
    readonly property var cavaValues: {
        const values = AudioBars.levels || []
        const out = []

        if (values.length === 0)
            return out

        // Ryoku AudioBars exposes 40 bands. The original Sukunabikona rail
        // is designed around 24, so average the spectrum down instead of
        // truncating it and losing the upper frequencies.
        for (let bar = 0; bar < shell.cavaBarCount; ++bar) {
            const start = Math.floor(bar * values.length / shell.cavaBarCount)
            const end = Math.max(
                start + 1,
                Math.floor((bar + 1) * values.length / shell.cavaBarCount)
            )

            let sum = 0
            let count = 0

            for (let i = start; i < Math.min(end, values.length); ++i) {
                sum += Number(values[i] || 0)
                count++
            }

            out.push(Math.round((count > 0 ? sum / count : 0) * 100))
        }

        return out
    }

    property string cpuName: "CPU"
    property string gpuName: "GRAPHICS"
    property string osName: "LINUX"
    property string kernelName: ""

    function trim(value, fallback) {
        const text = String(value || "").trim()
        return text.length > 0 ? text : fallback
    }

    function toggleRail() {
        if (shell.compact) {
            shell.railHidden = false
            shell.railPinned = shell.tiledCount > 0
        } else {
            shell.railHidden = true
            shell.railPinned = false
        }
    }

    function workspaceNames() {
        if (Wm.workspaceModel !== "dynamic")
            return ["1", "2", "3", "4", "5"]
        const names = []
        const rows = Wm.workspaces || []
        for (let i = 0; i < rows.length; ++i) {
            const ws = rows[i]
            if (!ws || ws.special === true)
                continue
            if (shell.outputName && ws.output && String(ws.output) !== shell.outputName)
                continue
            names.push(String(ws.name || ws.id || ""))
            if (names.length >= 5)
                break
        }
        return names
    }

    function workspaceNameAt(index) {
        const names = shell.workspaceNames()
        return index >= 0 && index < names.length ? names[index] : ""
    }

    function workspaceActive(index) {
        const name = shell.workspaceNameAt(index)
        return name.length > 0 && name === shell.workspaceKey
    }

    function focusWorkspace(index) {
        const name = shell.workspaceNameAt(index)
        if (name.length > 0)
            Wm.focusWorkspace(name)
    }

    function execCommand(argv) {
        if (argv && argv.length)
            Quickshell.execDetached(argv)
    }

    function openLauncher() {
        const state = ShellState.forScreen(shell.modelData)
        if (state)
            state.launcherOpen = !state.launcherOpen
    }

    function toggleMute() {
        if (Audio.sink && Audio.sink.audio)
            Audio.sink.audio.muted = !Audio.sink.audio.muted
    }

    function adjustVolume(delta) {
        if (!Audio.sink || !Audio.sink.audio)
            return
        Audio.sink.audio.volume = Math.max(0, Math.min(1.2, Audio.sink.audio.volume + delta))
    }

    function updateClaims() {
        Sysinfo.setActive(shell, !shell.compact && !shell.hasFullscreen)
        StatsFeed.setActive(shell, !shell.compact && !shell.hasFullscreen)
        AudioBars.setActive(shell, !shell.hasFullscreen && Media.present)
    }

    onCompactChanged: shell.updateClaims()
    onHasFullscreenChanged: shell.updateClaims()

    Connections {
        target: Media
        function onPresentChanged() { shell.updateClaims() }
    }

    Component.onCompleted: {
        Session.watchers += 1
        shell.updateClaims()
    }
    Component.onDestruction: {
        Sysinfo.setActive(shell, false)
        StatsFeed.setActive(shell, false)
        AudioBars.setActive(shell, false)
        Session.watchers = Math.max(0, Session.watchers - 1)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: shell.now = new Date()
    }

    // Static identity reads. No compositor command, no network request, no
    // privileged access: these are local files plus Ryoku's shipped pciutils.
    FileView {
        id: cpuInfo
        path: "/proc/cpuinfo"
        blockLoading: true
        printErrors: false
        onLoaded: {
            const lines = cpuInfo.text().split("\n")
            for (let i = 0; i < lines.length; ++i) {
                const m = /^model name\s*:\s*(.+)$/.exec(lines[i])
                if (m) {
                    shell.cpuName = m[1].replace(/\s+\d+-Core Processor$/, "").trim()
                    break
                }
            }
        }
    }

    FileView {
        id: osRelease
        path: "/etc/os-release"
        blockLoading: true
        printErrors: false
        onLoaded: {
            const lines = osRelease.text().split("\n")
            for (let i = 0; i < lines.length; ++i) {
                const m = /^PRETTY_NAME=(.*)$/.exec(lines[i])
                if (m) {
                    shell.osName = m[1].replace(/^\"|\"$/g, "")
                    break
                }
            }
        }
    }

    FileView {
        id: kernelRelease
        path: "/proc/sys/kernel/osrelease"
        blockLoading: true
        printErrors: false
        onLoaded: shell.kernelName = kernelRelease.text().trim()
    }

    Process {
        id: pciProbe
        running: true
        command: ["lspci", "-mm"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; ++i) {
                    if (!/(VGA compatible controller|3D controller|Display controller)/i.test(lines[i]))
                        continue
                    const quoted = lines[i].match(/\"([^\"]+)\"/g) || []
                    if (quoted.length >= 3) {
                        const vendor = quoted[1].replace(/^\"|\"$/g, "")
                        const model = quoted[2].replace(/^\"|\"$/g, "")
                        shell.gpuName = (vendor + " " + model).replace(/Corporation/g, "").replace(/\s+/g, " ").trim()
                        break
                    }
                }
            }
        }
    }

    PanelWindow {
        id: railWindow

        screen: shell.modelData
        readonly property var workspace: shell.workspace
        readonly property int windowCount: shell.windowCount
        readonly property int floatingCount: shell.floatingCount
        readonly property int tiledCount: shell.tiledCount
        readonly property bool compact: shell.compact

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "sukunabikona-rail"
        anchors { top: true; bottom: true; left: true; right: true }
        visible: !shell.hasFullscreen
        mask: Region { item: rail }

        C.RyokuRail {
            id: rail
            controller: shell
            windowData: shell
            compact: railWindow.compact
        }
    }

    PanelWindow {
        id: topBar
        screen: shell.modelData
        color: "transparent"
        implicitHeight: 78
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 72
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "sukunabikona-bar"
        anchors { top: true; left: true; right: true }
        visible: shell.compact && !shell.hasFullscreen
        mask: Region {
            Region { item: leftPill }
            Region { item: middlePill }
            Region { item: rightPill }
        }

        Item {
            id: barPills
            anchors.fill: parent

            Rectangle {
                id: leftPill
                x: 18
                y: 10
                width: 250
                height: 52
                radius: 16
                color: shell.bg
                border.color: shell.hairline
                border.width: 1

                Item {
                    id: brandTap
                    x: 0
                    y: 0
                    width: 92
                    height: parent.height

                    Text {
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: "力"
                        color: shell.accent
                        font.family: shell.fontJp
                        font.weight: Font.Bold
                        font.pixelSize: 18
                        renderType: Text.NativeRendering
                    }
                    Text {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RYOKU"
                        color: shell.ivory
                        font.family: shell.fontUi
                        font.weight: Font.DemiBold
                        font.pixelSize: 11
                        font.letterSpacing: 1.0
                    }

                    MouseArea {
                        id: brandArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.toggleRail()
                    }
                }

                Rectangle {
                    x: 92
                    y: 11
                    width: 1
                    height: parent.height - 22
                    color: shell.hairline
                }

                Item {
                    x: 99
                    y: 0
                    width: parent.width - 108
                    height: parent.height

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Repeater {
                            model: 5

                            Rectangle {
                                required property int index
                                readonly property int workspaceId: index + 1
                                readonly property bool active: shell.workspaceActive(index)
                                width: active ? 34 : 24
                                height: 32
                                radius: 10
                                color: active ? shell.bone : workspaceArea.containsMouse ? shell.tint10 : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.workspaceId
                                    color: parent.active ? shell.inkOnBone : shell.soft
                                    font.family: shell.fontUi
                                    font.weight: parent.active ? Font.DemiBold : Font.Medium
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    id: workspaceArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: shell.focusWorkspace(index)
                                }

                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: middlePill
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: shell.mediaPlayer ? 420 : 360
                height: 52
                radius: 16
                color: shell.bg
                border.color: shell.hairline
                border.width: 1
                clip: true
                visible: topBar.width >= 1260

                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                Item {
                    id: islandBlock
                    x: 0
                    y: 0
                    width: parent.width - 102
                    height: parent.height

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 18
                        spacing: 10

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            radius: 9
                            color: shell.raised
                            clip: true

                            Image {
                                id: albumArt
                                anchors.fill: parent
                                source: shell.mediaPlayer ? shell.mediaPlayer.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: shell.mediaPlayer !== null && status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !albumArt.visible
                                text: shell.mediaPlayer ? "󰎆" : "窓"
                                color: shell.accent
                                font.family: shell.mediaPlayer ? "JetBrainsMono Nerd Font" : shell.fontJp
                                font.pixelSize: shell.mediaPlayer ? 13 : 11
                                renderType: Text.NativeRendering
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: islandBlock.width - 110
                            spacing: 2

                            Text {
                                width: parent.width
                                text: shell.mediaPlayer
                                    ? shell.trim(shell.mediaPlayer.trackTitle, shell.mediaPlayer.identity || "NOW PLAYING")
                                    : shell.activeTitle
                                color: shell.ivory
                                font.family: shell.fontUi
                                font.weight: Font.DemiBold
                                font.pixelSize: 15
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: shell.mediaPlayer
                                    ? shell.trim(shell.mediaPlayer.trackArtist, "NOW PLAYING")
                                    : shell.activeClass
                                color: shell.mutedText
                                font.family: shell.fontUi
                                font.weight: Font.Medium
                                font.pixelSize: 9
                                font.letterSpacing: 0.4
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: shell.mediaPlayer !== null
                            text: shell.mediaPlayer && shell.mediaPlayer.isPlaying ? "󰏤" : "󰐊"
                            color: shell.soft
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                        }
                    }

                    MouseArea {
                        id: islandArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: shell.mediaPlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (shell.mediaPlayer && shell.mediaPlayer.canTogglePlaying)
                                shell.mediaPlayer.togglePlaying()
                        }
                    }
                }

                Item {
                    id: cavaBlock
                    x: parent.width - 96
                    y: 0
                    width: 90
                    height: parent.height

                    Row {
                        anchors.centerIn: parent
                        spacing: 3

                        Repeater {
                            model: 14

                            Item {
                                required property int index
                                width: 3
                                height: 28

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: 2
                                    height: {
                                        const values = shell.cavaValues || []
                                        if (values.length === 0) return 2
                                        const sourceIndex = Math.min(values.length - 1, Math.floor(index * values.length / 14))
                                        return Math.max(2, Math.min(28, Number(values[sourceIndex]) * 0.26))
                                    }
                                    radius: 1.5
                                    color: shell.accentQuiet

                                    Behavior on height { NumberAnimation { duration: 70 } }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: rightPill
                anchors.right: parent.right
                anchors.rightMargin: 18
                y: 10
                width: 172
                height: 52
                radius: 16
                color: shell.bg
                border.color: shell.hairline
                border.width: 1

                Item {
                    id: volumeBlock
                    x: 0
                    y: 0
                    width: 78
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: (shell.muted ? "󰝟" : "󰕾") + "  " + shell.volumePercent + "%"
                        color: shell.muted ? shell.accent : shell.soft
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: volumeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.toggleMute()
                        onWheel: wheel => shell.adjustVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                    }
                }

                Text {
                    x: 82
                    width: 82
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatTime(shell.now, "HH:mm")
                    color: shell.ivory
                    font.family: shell.fontUi
                    font.weight: Font.DemiBold
                    font.pixelSize: 12
                }
            }
        }
    }
}
