pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "lib/screens.js" as Screens
import "."
import "Singletons"

/**
 * Ryoku adapter for Ricelin's original Pill shell.
 *
 * Frame.qml loads this Scene once per monitor. Only the primary Scene instance
 * owns the Pill host; inside it we reproduce Ricelin's original two Variants:
 * one exclusive reserve window and one full-screen overlay per monitor.
 * This keeps the original geometry/input behavior while fitting Ryoku's
 * BarProducts Scene contract.
 */
Item {
    id: root

    property var modelData: null
    readonly property bool isPrimary: {
        var list = Screens.uniqueByName(Quickshell.screens)
        return list.length > 0 && !!root.modelData && list[0].name === root.modelData.name
    }

    // These are the same controller/state fields the original ShellRoot owned.
    property string openMon: ""
    property string openSurface: ""
    property string peekMon: ""

    function refresh() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    function toggleSurface(mon, surface) {
        if (!mon || mon.length === 0)
            mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        if (root.openMon === mon && root.openSurface === surface) {
            root.close();
            return;
        }
        root.openMon = mon;
        root.openSurface = surface;
    }

    function close() {
        root.openMon = "";
        root.openSurface = "";
    }

    function peek(mon) {
        root.peekMon = root.peekMon === mon ? "" : mon;
    }

    readonly property var refreshEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true, activespecial: true,
        focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true,
        movewindow: true, movewindowv2: true,
        fullscreen: true,
        monitoradded: true, monitoraddedv2: true,
        monitorremoved: true
    })

    // Frame.qml mounts this Scene once PER monitor, so every global-once node --
    // the "pill" IPC handler (whose target must be unique per process), the
    // keep-awake idle inhibitor and the startup/refresh side-effects -- lives
    // under one primary-owned Loader. Without the gate a two-monitor session
    // builds two IpcHandlers fighting for the same target and two idle
    // inhibitors. The visual reserve/overlay Variants below carry their own
    // isPrimary Loader.
    Loader {
        active: root.isPrimary
        sourceComponent: Component {
            Item {
                Component.onCompleted: {
                    root.refresh();
                    Devices.restore();
                    void GameMode.active;
                }

                Connections {
                    target: Hyprland
                    function onRawEvent(event) {
                        if (root.refreshEvents[event.name])
                            root.refresh();
                    }
                }

                // The single Ricelin IPC namespace lives in the active Ryoku
                // shell, exactly where the old ShellRoot handler lived.
                IpcHandler {
                    target: "pill"
                    function mixer(mon: string): void { root.toggleSurface(mon, "mixer"); }
                    function calendar(mon: string): void { root.toggleSurface(mon, "calendar"); }
                    function launcher(mon: string): void { root.toggleSurface(mon, "launcher"); }
                    function power(mon: string): void { root.toggleSurface(mon, "power"); }
                    function link(mon: string): void { root.toggleSurface(mon, "link"); }
                    function battery(mon: string): void { root.toggleSurface(mon, "battery"); }
                    function settings(mon: string): void { root.toggleSurface(mon, "settings"); }
                    function keybinds(mon: string): void { root.toggleSurface(mon, "keybinds"); }
                    function recorder(mon: string): void { root.toggleSurface(mon, "recorder"); }
                    function screenrec(mon: string): void { root.toggleSurface(mon, "recorder"); }
                    function record(mon: string): void { root.toggleSurface(mon, "recorder"); }
                    function sysmon(mon: string): void { root.toggleSurface(mon, "sysmon"); }
                    function system(mon: string): void { root.toggleSurface(mon, "sysmon"); }
                    function clipboard(mon: string): void { root.toggleSurface(mon, "clipboard"); }
                    function wallpaper(mon: string): void { root.toggleSurface(mon, "wallpaper"); }
                    function media(mon: string): void {
                        if (Players.list.length > 0)
                            root.toggleSurface(mon, "media");
                    }
                    function peek(mon: string): void { root.peek(mon); }
                    function hide(): void { root.close(); }
                    function page(mon: string, name: string): void { root.toggleSurface(mon, name); }
                    function gameMode(mon: string): void { Flags.gameMode = !Flags.gameMode; }
                    function quickRecord(mon: string): void {
                        if (ScreenRec.recording) {
                            ScreenRec.stop();
                        } else if (ScreenRec.counting) {
                            ScreenRec.cancel();
                        } else if (ScreenRec.quickChoosing) {
                            ScreenRec.quickChoosing = false;
                            ScreenRec.quickScreenChoosing = false;
                        } else {
                            ScreenRec.quickMon = mon;
                            ScreenRec.quickScreenChoosing = false;
                            ScreenRec.quickChoosing = true;
                        }
                    }
                    function minimizeWindow(addr: string): void {
                        Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:' + addr + '" })');
                    }
                    function restoreWindow(arg: string): void {
                        var p = arg.split("|");
                        if (p.length < 2 || p[0].length === 0)
                            return;
                        Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + p[1] + ', window = "address:' + p[0] + '" })');
                    }
                }

                // Ricelin's keep-awake, instantiated once under the primary Scene.
                PanelWindow {
                    id: inhibitWin
                    visible: Flags.keepAwake
                    implicitWidth: 1
                    implicitHeight: 1
                    color: "transparent"
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.layer: WlrLayer.Background
                    WlrLayershell.namespace: "pill-inhibit"
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                    anchors { top: true; left: true }
                    IdleInhibitor { window: inhibitWin; enabled: Flags.keepAwake }
                }

                Process {
                    running: Flags.keepAwake
                    command: ["systemd-inhibit", "--what=idle:sleep", "--who=Ricelin",
                              "--why=keep awake", "--mode=block", "sleep", "infinity"]
                }
            }
        }
    }

    Loader {
        active: root.isPrimary
        sourceComponent: Component {
            Item {
                // Original Ricelin reserve band, once per monitor.
                Variants {
                    model: Quickshell.screens

                    PanelWindow {
                        id: reserve
                        required property var modelData
                        readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
                        readonly property real topGap: 8 * Flags.topGap * s
                        readonly property real restHeight: 38 * s
                        readonly property real reservedH: Math.max(0, restHeight + topGap - 12 * (1 - Flags.appGap) * s)
                        readonly property real gameBarH: 34 * s

                        screen: modelData
                        color: "transparent"
                        exclusionMode: ExclusionMode.Normal
                        exclusiveZone: Flags.gameMode ? gameBarH : reservedH
                        aboveWindows: true
                        anchors { top: true; left: true; right: true }
                        implicitHeight: Flags.gameMode ? gameBarH : reservedH
                        mask: emptyReserve
                        Region { id: emptyReserve }
                    }
                }

                // Original Ricelin full-screen overlay, once per monitor.
                Variants {
                    model: Quickshell.screens

                    PanelWindow {
                        id: overlay
                        required property var modelData
                        readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
                        readonly property real topGap: 8 * Flags.topGap * s
                        readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
                        readonly property bool surfaceOpen: surface.length > 0
                        readonly property bool modal: pill.authPending ? false : (surfaceOpen || pill.held || pill.quickChoosing)

                        readonly property bool monFullscreen: {
                            var mons = Hyprland.monitors.values;
                            for (var i = 0; i < mons.length; i++) {
                                if (mons[i] && mons[i].name === modelData.name) {
                                    var ws = mons[i].activeWorkspace;
                                    var o = ws ? ws.lastIpcObject : null;
                                    return o ? !!o.hasfullscreen : false;
                                }
                            }
                            return false;
                        }
                        readonly property bool summoned: modal || root.peekMon === modelData.name
                        readonly property bool pillHidden: monFullscreen && !summoned

                        onMonFullscreenChanged: if (monFullscreen) {
                            if (root.openMon === modelData.name) root.close();
                            if (root.peekMon === modelData.name) root.peekMon = "";
                            pill.pinned = false;
                        }

                        screen: modelData
                        color: "transparent"
                        exclusionMode: ExclusionMode.Ignore
                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.keyboardFocus: ((surfaceOpen || pill.quickChoosing) && !pill.authPending)
                            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                        WlrLayershell.namespace: "pill"
                        anchors { top: true; left: true; right: true; bottom: true }

                        mask: modal ? fullRegion : (pillHidden ? hiddenRegion : pillRegion)
                        Region { id: hiddenRegion }
                        Region {
                            id: pillRegion
                            readonly property real baseW: Math.max(pill.width, pill.targetW)
                            x: pill.x + (pill.width - baseW) / 2
                            y: pill.y
                            width: baseW + pill.inputPadRight
                            height: Math.max(pill.height, pill.targetH)
                        }
                        Region {
                            id: fullRegion
                            width: overlay.width
                            height: overlay.height
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: overlay.modal
                            acceptedButtons: Qt.AllButtons
                            onPressed: (mouse) => {
                                if (pill.quickChoosing) {
                                    ScreenRec.quickChoosing = false;
                                    ScreenRec.quickScreenChoosing = false;
                                } else if (overlay.surfaceOpen) {
                                    var inside = mouse.x >= pillRegion.x && mouse.x <= pillRegion.x + pillRegion.width
                                        && mouse.y >= pillRegion.y && mouse.y <= pillRegion.y + pillRegion.height;
                                    if (!inside)
                                        root.close();
                                    else if (mouse.y <= pillRegion.y + 40 * pill.s)
                                        pill.surfaceBack();
                                } else {
                                    pill.pinned = false;
                                    root.peekMon = "";
                                }
                            }
                        }

                        FocusScope {
                            id: focusScope
                            anchors.fill: parent
                            focus: overlay.surfaceOpen || pill.quickChoosing

                            HoverHandler { onHoveredChanged: pill.hovered = hovered }

                            Keys.onEscapePressed: {
                                if (pill.quickChoosing) {
                                    ScreenRec.quickChoosing = false;
                                    ScreenRec.quickScreenChoosing = false;
                                } else if (!pill.keybindsBack()) {
                                    root.close();
                                }
                            }
                            Keys.onUpPressed: (e) => {
                                if (pill.keybindsOpen) { pill.keybindsMove(-1); e.accepted = true; return; }
                                e.accepted = pill.mixerStep(1) || pill.recorderStep(5) || pill.settingsMove(-1);
                            }
                            Keys.onDownPressed: (e) => {
                                if (pill.keybindsOpen) { pill.keybindsMove(1); e.accepted = true; return; }
                                e.accepted = pill.mixerStep(-1) || pill.recorderStep(-5) || pill.settingsMove(1);
                            }
                            Keys.onLeftPressed: (e) => {
                                if (pill.mixerOpen) { pill.mixerFocusMove(-1); e.accepted = true; }
                                else if (pill.wallpaperOpen) { pill.wallpaperMove(-1); e.accepted = true; }
                                else if (pill.powerOpen) { pill.powerMove(-1); e.accepted = true; }
                                else if (pill.recorderOpen) { e.accepted = pill.recorderStep(-5); }
                                else if (pill.settingsLike) { pill.settingsAdjust(-1); e.accepted = true; }
                            }
                            Keys.onRightPressed: (e) => {
                                if (pill.mixerOpen) { pill.mixerFocusMove(1); e.accepted = true; }
                                else if (pill.wallpaperOpen) { pill.wallpaperMove(1); e.accepted = true; }
                                else if (pill.powerOpen) { pill.powerMove(1); e.accepted = true; }
                                else if (pill.recorderOpen) { e.accepted = pill.recorderStep(5); }
                                else if (pill.settingsLike) { pill.settingsAdjust(1); e.accepted = true; }
                            }
                            Keys.onPressed: (e) => {
                                if (pill.wallpaperOpen && e.text.length === 1 && e.text > " ") {
                                    pill.openWallpaperPicker();
                                    e.accepted = true;
                                    return;
                                }
                                if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space)
                                    return;
                                if (pill.wallpaperOpen) {
                                    if (!e.isAutoRepeat) pill.wallpaperActivate();
                                    e.accepted = true;
                                } else if (pill.powerOpen) {
                                    if (!e.isAutoRepeat) pill.powerPress();
                                    e.accepted = true;
                                } else if (pill.settingsLike) {
                                    if (!e.isAutoRepeat) pill.settingsActivate();
                                    e.accepted = true;
                                } else if (pill.keybindsOpen) {
                                    if (!e.isAutoRepeat) pill.keybindsActivate();
                                    e.accepted = true;
                                }
                            }
                            Keys.onReleased: (e) => {
                                if (e.isAutoRepeat) return;
                                if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) && pill.powerOpen) {
                                    pill.powerRelease();
                                    e.accepted = true;
                                }
                            }

                            Pill {
                                id: pill
                                anchors.top: parent.top
                                anchors.topMargin: pill.mode === "game" ? 0 : overlay.topGap
                                anchors.horizontalCenter: parent.horizontalCenter
                                s: overlay.s
                                screenName: overlay.modelData.name
                                barWindow: overlay
                                surface: overlay.surface
                                forcePinned: root.peekMon === overlay.modelData.name

                                Behavior on anchors.topMargin {
                                    NumberAnimation {
                                        duration: Motion.morph
                                        easing.type: Motion.easeMorph
                                        easing.bezierCurve: Motion.morphCurve
                                    }
                                }
                                opacity: overlay.pillHidden ? 0 : 1
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Motion.morph
                                        easing.type: Motion.easeMorph
                                        easing.bezierCurve: Motion.morphCurve
                                    }
                                }
                                transform: Translate {
                                    y: overlay.pillHidden ? -(pill.height + overlay.topGap) : 0
                                    Behavior on y {
                                        NumberAnimation {
                                            duration: Motion.morph
                                            easing.type: Motion.easeMorph
                                            easing.bezierCurve: Motion.morphCurve
                                        }
                                    }
                                }

                                onRequestSurface: (name) => root.toggleSurface(overlay.modelData.name, name)
                                onRequestClose: root.close()
                            }
                        }

                        onSurfaceOpenChanged: if (surfaceOpen) focusScope.forceActiveFocus()

                        Connections {
                            target: pill
                            function onQuickChoosingChanged() {
                                if (pill.quickChoosing) focusScope.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
    }
}
