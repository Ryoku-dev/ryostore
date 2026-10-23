pragma ComponentBehavior: Bound

import QtQuick
import "../../components"
Item {
    id: root

    property var model: null
    property Component delegate: null

    property real spacing: 0
    readonly property alias contentHeight: listView.contentHeight
    readonly property real layoutHeight: _layoutHeight
    property real contentY: 0

    property rect viewport: Qt.rect(0, 0, 0, 0)
    property bool useCustomViewport: false
    property real cacheBuffer: 0
    property bool cullDelegates: true
    property real estimatedHeight: -1
    property bool asynchronous: false

    property int removeDuration: 300
    property int readyDelay: 0

    readonly property alias count: listView.count

    property real _layoutHeight: 0
    property bool _populated: false

    signal viewportAdjustNeeded(delta: real)

    function itemAtIndex(index: int): Item {
        return listView.itemAtIndex(index);
    }

    function itemAt(x: real, y: real): Item {
        return listView.itemAt(x, y + listView.contentY);
    }

    function _recalcLayoutHeight(): void {
        const kids = listView.contentItem.children;
        let total = 0;
        let hasItem = false;
        for (let i = 0; i < kids.length; ++i) {
            const item = kids[i];
            if (!item || item.removing)
                continue;
            const h = item.preferredHeight !== undefined && item.preferredHeight >= 0 ? item.preferredHeight : item.implicitHeight;
            if (h <= 0)
                continue;
            if (hasItem)
                total += root.spacing;
            hasItem = true;
            total += h;
        }
        root._layoutHeight = total;
    }

    onSpacingChanged: _recalcLayoutHeight()

    onModelChanged: {
        _populated = false;
        Qt.callLater(() => {
            root._populated = true;
            root._recalcLayoutHeight();
        });
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            root._populated = true;
            root._recalcLayoutHeight();
        });
    }

    ListView {
        id: listView

        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        contentWidth: width
        interactive: false
        reuseItems: false
        // Outer Flickable owns scrolling; keep all notification delegates instantiated for exact layoutHeight.
        cacheBuffer: 100000
        spacing: root.spacing
        model: root.model
        delegate: root.delegate

        populate: Transition {}

        add: Transition {
            enabled: root._populated

            SequentialAnimation {
                PropertyAction {
                    property: "animationsEnabled"
                    value: false
                }
                PropertyAction {
                    property: "adding"
                    value: true
                }
                PropertyAction {
                    property: "animationsEnabled"
                    value: true
                }
                PauseAnimation {
                    duration: Math.max(1, root.readyDelay)
                }
                PropertyAction {
                    property: "adding"
                    value: false
                }
            }
        }

        displaced: Transition {
            PropertyAction {
                property: "animationsEnabled"
                value: true
            }
            PropertyAction {
                property: "adding"
                value: false
            }
            Anim {
                properties: "y"
            }
        }

        remove: Transition {
            SequentialAnimation {
                PropertyAction {
                    property: "ListView.delayRemove"
                    value: true
                }
                PropertyAction {
                    property: "removing"
                    value: true
                }
                PauseAnimation {
                    duration: root.removeDuration
                }
                PropertyAction {
                    property: "ListView.delayRemove"
                    value: false
                }
            }
        }
    }

    // Delayed binding prevents ListView geometryChange -> contentHeight binding loops.
    Binding {
        target: listView
        property: "height"
        value: Math.max(1, listView.contentHeight)
        delayed: true
    }

    Instantiator {
        model: listView.contentItem.children

        delegate: QtObject {
            id: tracker

            required property var modelData
            property real prevHeight: -1
            property bool heightKnown: false

            function currentPreferredHeight(): real {
                if (!modelData || modelData.removing)
                    return 0;
                if (modelData.preferredHeight !== undefined && modelData.preferredHeight >= 0)
                    return modelData.preferredHeight;
                return modelData.implicitHeight;
            }

            function handleHeightChange(): void {
                const h = currentPreferredHeight();
                if (heightKnown && !modelData.removing && Math.abs(h - prevHeight) > 0.01) {
                    const vpTop = root.useCustomViewport ? root.viewport.y : root.contentY;
                    if (modelData.trackViewport && modelData.y < vpTop)
                        root.viewportAdjustNeeded(h - prevHeight);
                }
                prevHeight = h;
                heightKnown = true;
                root._recalcLayoutHeight();
            }

            Component.onCompleted: {
                prevHeight = currentPreferredHeight();
                heightKnown = true;
                root._recalcLayoutHeight();
            }

            readonly property Connections conn: Connections {
                target: tracker.modelData
                ignoreUnknownSignals: true

                function onPreferredHeightChanged(): void {
                    tracker.handleHeightChange();
                }

                function onImplicitHeightChanged(): void {
                    tracker.handleHeightChange();
                }

                function onRemovingChanged(): void {
                    root._recalcLayoutHeight();
                }
            }
        }

        onObjectAdded: root._recalcLayoutHeight()
        onObjectRemoved: root._recalcLayoutHeight()
    }
}
