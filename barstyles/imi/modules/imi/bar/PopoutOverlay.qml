pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import shell.services
import "../../.."
import "../../../services"
import "../../common"
import "../../common/widgets"
import "../../../shared" as Shared

PanelWindow {
    id: popoutWindow
    property var modelData: null
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
    readonly property bool onThisScreen: activePop !== null && activePop.shown

    visible: true

    mask: Region {
        item: (card.openProgress > 0.01 && card.opacity > 0.01) ? card : null
    }

    Rectangle {
        id: card

        property real openProgress: 0
        Behavior on openProgress {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        property real targetX: popoutWindow.activePop ? (popoutWindow.activePop.lastMappedX ?? 200) : 200
        property real targetWidth: (popoutWindow.activePop?.preferredWidth ?? 280) + 24
        property real targetHeight: (popoutWindow.activePop?.preferredHeight ?? 200) + 24

        Behavior on x {
            enabled: card.openProgress > 0.01
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            enabled: card.openProgress > 0.01
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: card.openProgress > 0.01
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        x: targetX
        y: (popoutWindow.activePop?.barHeight ?? 48) + 6
        width: targetWidth
        height: targetHeight
        clip: true

        radius: Theme.radiusWindow || 16
        color: Theme.surface || "#141318"
        border.width: Theme.borderWidth || 1
        border.color: Theme.outline || "#333333"
        opacity: (popContentLoader.status === Loader.Ready) ? card.openProgress : 0

        HoverHandler {
            onHoveredChanged: {
                if (popoutWindow.activePop) {
                    popoutWindow.activePop.cardHovered = hovered;
                }
            }
        }

        Loader {
            id: popContentLoader
            anchors.fill: parent
            anchors.margins: 12
            sourceComponent: popoutWindow.onThisScreen ? popoutWindow.activePop.content : null

            opacity: status === Loader.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            onLoaded: popoutWindow.updatePosition()
        }

        Connections {
            target: popContentLoader.item
            ignoreUnknownSignals: true
            function onImplicitWidthChanged() { popoutWindow.updatePosition(); }
            function onImplicitHeightChanged() { popoutWindow.updatePosition(); }
        }
    }

    function updatePosition() {
        if (!onThisScreen || !activePop || !activePop.target) return;
        const item = popContentLoader.item;
        const w = (item ? (item.implicitWidth || item.width || activePop.preferredWidth || 280) : (activePop.preferredWidth || 280));
        const h = (item ? (item.implicitHeight || item.height || activePop.preferredHeight || 200) : (activePop.preferredHeight || 200));

        const nextW = Math.max(120, w + 24);
        const nextH = Math.max(80, h + 24);

        const screenW = popoutWindow.width > 0 ? popoutWindow.width : (popoutWindow.screen ? popoutWindow.screen.width : 1920);
        let mappedX = 200;
        if (typeof activePop.getMappedX === "function") {
            mappedX = activePop.getMappedX(nextW);
        }
        const newX = Math.max(12, Math.min(mappedX, screenW - nextW - 12));

        card.targetX = newX;
        card.targetWidth = nextW;
        card.targetHeight = nextH;
    }

    Connections {
        target: GlobalStates
        function onActiveBarPopupChanged() {
            if (popoutWindow.onThisScreen) {
                popoutWindow.updatePosition();
                card.openProgress = 1;
            } else {
                card.openProgress = 0;
            }
        }
    }
}
