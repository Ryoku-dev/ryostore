pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import shell.services
import ".."

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property ShellScreen modelData

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.namespace: "ryoku-bar-popout"

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            readonly property var activePop: GlobalStates.activeBarPopup
            readonly property bool shouldShow: activePop !== null && activePop.shown
                && (!activePop.target?.QsWindow?.window?.screen || activePop.target?.QsWindow?.window?.screen.name === win.screen.name)

            visible: shouldShow || card.openProgress > 0.001
            mask: Region { item: card }

            onShouldShowChanged: {
                if (shouldShow) {
                    recalc();
                    card.openProgress = 1;
                } else {
                    card.openProgress = 0;
                }
            }

            Connections {
                target: GlobalStates
                function onActiveBarPopupChanged() {
                    if (win.shouldShow) {
                        win.recalc();
                    }
                }
            }

            function recalc() {
                if (!activePop || !activePop.target) return;
                const item = loader.item;
                const w = (item ? (item.implicitWidth || item.width || activePop.preferredWidth || 280) : (activePop.preferredWidth || 280)) + 2;
                const h = (item ? (item.implicitHeight || item.height || activePop.preferredHeight || 200) : (activePop.preferredHeight || 200)) + 2;

                const screenW = (win.screen && win.screen.width > 0) ? win.screen.width : (win.width > 0 ? win.width : 1920);
                let finalX = 200;
                if (typeof activePop.getMappedX === "function") {
                    finalX = activePop.getMappedX(w);
                }
                finalX = Math.max(8, Math.min(finalX, screenW - w - 8));

                card.targetX = finalX;
                card.targetW = w;
                card.targetH = h;
            }

            Rectangle {
                id: card
                clip: true

                property real openProgress: 0
                property real targetX: 200
                property real targetW: 280
                property real targetH: 200

                x: targetX
                y: (win.activePop?.barHeight ?? 46)
                width: targetW
                height: targetH

                radius: Theme.radiusWindow
                color: Theme.surface
                border.width: Theme.borderWidth
                border.color: Theme.outline
                opacity: Math.max(0, Math.min(1, openProgress)) * Theme.windowOpacity
                scale: 0.95 + 0.05 * openProgress

                Behavior on openProgress {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on x {
                    enabled: card.openProgress > 0.01
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on width {
                    enabled: card.openProgress > 0.01
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    enabled: card.openProgress > 0.01
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (win.activePop) {
                            win.activePop.cardHovered = hovered;
                        }
                    }
                }

                Loader {
                    id: loader
                    anchors.centerIn: parent
                    sourceComponent: win.shouldShow ? win.activePop.content : null

                    opacity: card.openProgress > 0.05 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }

                    onLoaded: win.recalc()
                }

                Connections {
                    target: loader.item
                    ignoreUnknownSignals: true
                    function onImplicitWidthChanged() { win.recalc(); }
                    function onImplicitHeightChanged() { win.recalc(); }
                }
            }
        }
    }
}
