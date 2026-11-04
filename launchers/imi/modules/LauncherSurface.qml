pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.Ui.Singletons
import ".."
import "../services"
import "common"
import "common/widgets"

// The launcher window: one PanelWindow on the output the host named, hosting the ported overview SearchWidget.
Item {
    id: root

    required property var host
    property string monitor: ""
    readonly property bool open: host.openRequested
    // The host settles `shown` from this; it flips false once the fade-out
    // has finished and the window is gone.
    signal finishedClosing

    readonly property bool animationsDisabled: Config.options.overview.animationStyle === "none"

    readonly property var output: {
        const screens = Quickshell.screens;
        const wanted = root.monitor.length > 0 ? root.monitor : Wm.focusedOutput;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === wanted)
                return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }

    onOpenChanged: {
        GlobalStates.overviewOpen = root.open;
        GlobalStates.activeSearchMonitor = root.open ? root.monitor : "";
        if (root.open) {
            // Drop anything left over from the previous open so the surface
            // always comes up as plain search on its first frame.
            searchWidget.cancelSearch();
            searchWidget.requestedPanelId = "";
            searchWidget.searchingText = "";
            GlobalStates.searchPanelActive = false;
            GlobalStates.panelOpenedDirectly = false;
            Qt.callLater(searchWidget.focusSearchInput);
        }
    }
    Component.onCompleted: {
        GlobalStates.overviewOpen = root.open;
        GlobalStates.activeSearchMonitor = root.open ? root.monitor : "";
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            // Panels and result rows close the launcher through GlobalStates;
            // mirror that back into the host's open flag.
            if (!GlobalStates.overviewOpen && root.open)
                host.hide();
        }
    }

    PanelWindow {
        id: window

        visible: root.open || fadeOut.running
        screen: root.output
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "launcher"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Dismiss on a click anywhere outside the search surface.
        MouseArea {
            anchors.fill: parent
            onClicked: host.hide()
        }

        Item {
            id: surfaceBox

            width: searchWidget.width
            height: searchWidget.height
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.max(48, parent.height * 0.14)
            opacity: root.open ? 1.0 : 0.0
            scale: root.open ? 1.0 : 0.98

            Behavior on opacity {
                NumberAnimation {
                    id: fadeOut
                    duration: root.animationsDisabled ? 0 : 150
                    easing.type: Easing.OutCubic
                    onStopped: {
                        if (!root.open)
                            root.finishedClosing();
                    }
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.animationsDisabled ? 0 : 150
                    easing.type: Easing.OutCubic
                }
            }

            SearchWidget {
                id: searchWidget

                surfaceMonitorName: root.monitor
            }
        }
    }
}
