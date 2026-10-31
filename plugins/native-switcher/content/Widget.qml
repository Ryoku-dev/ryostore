pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.PluginKit.Singletons

Item {
    id: root
    property var pluginApi
    property var screen
    property bool active: false
    property string density: 'glyph'
    property real s: 1
    property real widthBudget: 220
    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    // Keep the plugin host alive for Alt+Tab, without a bar glyph or click target.
    implicitWidth: 0
    implicitHeight: 0

    // The view, textures and Wayland surface exist only while the panel is shown.
    LazyLoader {
        active: !!root.service && root.service.rendered
        PanelWindow {
            id: win
            Component.onCompleted: root.service.panelView = win
            Component.onDestruction: { if (root.service) root.service.panelView = null; }
            function motionMetrics() { return {opacity:surface.opacity,scale:surface.scale,highlightX:list.highlightItem ? list.highlightItem.x : -1,contentX:list.contentX,contentWidth:list.contentWidth,listWidth:list.width,scrollTo:win.scrollTarget,cards:list.contentItem.children.filter(c=>c.objectName === "switcher-card").map(c=>({index:c.index,hovered:c.pointerInside,iconY:c.iconY,iconScale:c.iconScale,glow:c.hoverGlow}))}; }
            property real scrollTarget: 0
            property bool motionReady: false
            function scrollCards(event) {
                if (!root.service.engaged) return;
                var pixel = event.pixelDelta.x || event.pixelDelta.y;
                var angle = event.angleDelta.x || event.angleDelta.y;
                var delta = angle ? -angle / 120 * 390 : -pixel * 2.5;
                var start = win.scrollTarget;
                var end = Math.max(0, list.contentWidth - list.width);
                win.scrollTarget = Math.max(0, Math.min(end, start + delta));
                event.accepted = true;
            }
            screen: Quickshell.screens.find(s => s.name === root.service.outputName) || Quickshell.screens[0]
            visible: true
            color: 'transparent'
            exclusiveZone: 0
            implicitWidth: Math.min(Math.max(1, root.service.windows.length) * 146 + Math.max(0, root.service.windows.length - 1) * 10 + 44, 1000, (screen ? screen.width : 1920) - 80)
            implicitHeight: 190
            WlrLayershell.namespace: 'ryoku-native-switcher'
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.service.engaged ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Rectangle {
                id: surface
                property bool entered: false
                readonly property bool presented: entered && root.service.shown
                Component.onCompleted: entered = true
                opacity: presented ? 1 : 0
                scale: presented ? 1 : 0.975
                transform: Translate { y: surface.presented ? 0 : 5; Behavior on y { NumberAnimation { duration: surface.presented ? 170 : 100; easing.type: Easing.OutCubic } } }
                Behavior on opacity { NumberAnimation { duration: surface.presented ? 140 : 90; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: surface.presented ? 180 : 100; easing.type: Easing.OutCubic } }
                anchors.fill: parent
                anchors.margins: 6
                radius: 16
                color: Qt.rgba(Theme.cardTop.r, Theme.cardTop.g, Theme.cardTop.b, 0.98)
                border.color: Theme.border
                border.width: 1
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    Row {
                        width: parent.width
                        Text { text: 'WINDOWS'; color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11 }
                        Text { text: '  /  ' + (root.service.selected + 1) + ' — ' + root.service.windows.length; color: Theme.accent; font.family: Theme.mono; font.pixelSize: 11 }
                    }
                    ListView {
                        id: list
                        width: parent.width
                        height: 120
                        orientation: ListView.Horizontal
                        spacing: 10
                        clip: true
                        model: root.service.windows
                        currentIndex: root.service.selected
                        contentX: win.scrollTarget
                        Behavior on contentX {
                            enabled: win.motionReady
                            SmoothedAnimation { velocity: -1; duration: 260; maximumEasingTime: 130; reversingMode: SmoothedAnimation.Immediate }
                        }
                        Component.onCompleted: { ensureSelectionVisible(); Qt.callLater(() => { ensureSelectionVisible(); win.motionReady = true; }); }
                        function ensureSelectionVisible() {
                            if (currentIndex < 0) return;
                            // Width may still be zero and currentItem stale during creation/indexChanged.
                            var viewport = width > 0 ? width : Math.max(0, win.implicitWidth - 44);
                            if (viewport <= 0) return;
                            var left = currentIndex * 156, right = left + 146;
                            var target = win.scrollTarget;
                            if (left < target) target = left;
                            else if (right > target + viewport) target = right - viewport;
                            win.scrollTarget = Math.max(0, Math.min(Math.max(0, contentWidth - viewport), target));
                        }
                        onCurrentIndexChanged: ensureSelectionVisible()
                        highlightMoveDuration: 135
                        highlightResizeDuration: 0
                        boundsBehavior: Flickable.StopAtBounds
                        highlightFollowsCurrentItem: false
                        highlight: Rectangle {
                            x: list.currentItem ? list.currentItem.x : 0
                            y: 0; width: 146; height: 116
                            Behavior on x { enabled: win.motionReady; NumberAnimation { duration: 145; easing.type: Easing.OutCubic } }
                            z: 2; radius: 10
                            color: "transparent"
                            border.width: 2; border.color: Theme.accent
                        }
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: width - 150
                        highlightRangeMode: ListView.NoHighlightRange
                        onCurrentItemChanged: ensureSelectionVisible()
                        delegate: Rectangle {
                            id: card
                            objectName: "switcher-card"
                            readonly property bool pointerInside: mouse.containsMouse
                            readonly property real iconY: iconLift.y
                            readonly property real iconScale: appIcon.scale
                            required property var modelData
                            required property int index
                            readonly property bool selected: root.service.selected === index
                            width: 146
                            height: 116
                            radius: 10
                            property real hoverGlow: 0
                            property real hoverLift: 0
                            NumberAnimation { id: hoverLiftIn; target: card; property: "hoverLift"; from: 0; to: -2; duration: 130; easing.type: Easing.OutCubic }
                            color: Theme.tileBg
                            border.width: 1
                            border.color: Theme.hair
                            scale: mouse.pressed ? 0.97 : 1
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: Theme.accent; opacity: card.hoverGlow
                            }
                            SequentialAnimation {
                                id: hoverEntry
                                NumberAnimation { target: card; property: "hoverGlow"; from: 0; to: 0.12; duration: 65; easing.type: Easing.OutCubic }
                                NumberAnimation { target: card; property: "hoverGlow"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                            }
                            Column {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6
                                Image {
                                    id: appIcon
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    scale: 1
                                    transform: Translate { id: iconLift; y: card.hoverLift }
                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    width: 42; height: 42
                                    source: root.service.iconFor(card.modelData)
                                    smooth: true
                                    mipmap: true
                                    asynchronous: true
                                    sourceSize.width: 42; sourceSize.height: 42
                                }
                                Text {
                                    width: parent.width
                                    text: card.modelData.title || card.modelData.class || 'Window'
                                    color: Theme.bright
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.modelData.workspace ? 'WS ' + card.modelData.workspace.name : ''
                                    color: Theme.dim; font.family: Theme.mono; font.pixelSize: 10
                                }
                            }
                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: { hoverEntry.restart(); hoverLiftIn.restart(); }
                                onExited: { hoverEntry.stop(); hoverLiftIn.stop(); card.hoverGlow = 0; card.hoverLift = 0; }
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.service.engaged
                                onClicked: root.service.pick(card.index)
                            }
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                z: 100
                acceptedButtons: Qt.NoButton
                onWheel: event => win.scrollCards(event)
            }
            Item {
                id: keyboard
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right || e.key === Qt.Key_Down) root.service.step((e.modifiers & Qt.ShiftModifier) ? -1 : 1);
                    else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left || e.key === Qt.Key_Up) root.service.step(-1);
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.service.commit();
                    else if (e.key === Qt.Key_Escape) root.service.cancel();
                    else return;
                    e.accepted = true;
                }
                Keys.onReleased: e => { if (e.key === Qt.Key_Alt && !e.isAutoRepeat) { root.service.commit(); e.accepted = true; } }
            }
        }
    }
}
