pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property real spacing: 0
    property bool _completed: false
    property bool _relayoutScheduled: false
    property bool _inRelayout: false

    function _morphOf(item): real {
        return item?.shapeMorphExpansion ?? 0;
    }

    function _scheduleRelayout(): void {
        if (!_completed || _relayoutScheduled)
            return;
        _relayoutScheduled = true;
        Qt.callLater(() => {
            root._relayoutScheduled = false;
            root._relayout();
        });
    }

    function _relayout(): void {
        if (_inRelayout)
            return;
        _inRelayout = true;

        const allChildren = root.children;
        const validChildren = [];
        for (let i = 0; i < allChildren.length; ++i) {
            const child = allChildren[i];
            if (child && child.visible && !(child instanceof Repeater))
                validChildren.push(child);
        }

        const nChildren = validChildren.length;
        const totalSpacing = nChildren > 1 ? (nChildren - 1) * root.spacing : 0;

        let reservedWidth = 0;
        let unreservedWidth = 0;
        let fillWidthCount = 0;
        let maxHeight = 0;

        for (let i = 0; i < nChildren; ++i) {
            const child = validChildren[i];
            maxHeight = Math.max(maxHeight, child.implicitHeight);

            if (!("fillWidth" in child))
                continue;

            if (child.fillWidth) {
                fillWidthCount++;
                unreservedWidth += child.implicitWidth;
            } else {
                reservedWidth += child.implicitWidth;
            }
        }

        const divisor = fillWidthCount > 0 ? fillWidthCount : 1;
        const widthPerItem = (root.width - totalSpacing - reservedWidth) / divisor;

        let accX = 0;
        for (let i = 0; i < nChildren; ++i) {
            const child = validChildren[i];
            const baseWidth = ("fillWidth" in child && child.fillWidth) ? widthPerItem : child.implicitWidth;

            let prevExtraWidth = i > 0 ? _morphOf(validChildren[i - 1]) : 0;
            let nextExtraWidth = i < nChildren - 1 ? _morphOf(validChildren[i + 1]) : 0;

            if (i > 1)
                prevExtraWidth /= 2;
            if (i < nChildren - 2)
                nextExtraWidth /= 2;

            child.width = baseWidth + _morphOf(child) - prevExtraWidth - nextExtraWidth;
            child.height = maxHeight;
            child.x = accX;
            child.y = 0;
            accX += child.width + root.spacing;
        }

        root.implicitWidth = reservedWidth + unreservedWidth + totalSpacing;
        root.implicitHeight = maxHeight;
        _inRelayout = false;
    }

    onWidthChanged: {
        if (_completed)
            _relayout();
    }
    onSpacingChanged: _scheduleRelayout()
    onChildrenChanged: _scheduleRelayout()

    Component.onCompleted: {
        _completed = true;
        _relayout();
    }

    // Lives in resources rather than children so callers inspecting row.children only see buttons.
    Instantiator {
        model: root.children

        delegate: QtObject {
            id: watcher

            required property var modelData

            readonly property Connections conn: Connections {
                target: watcher.modelData
                ignoreUnknownSignals: true

                function onImplicitWidthChanged(): void {
                    root._scheduleRelayout();
                }

                function onImplicitHeightChanged(): void {
                    root._scheduleRelayout();
                }

                function onVisibleChanged(): void {
                    root._scheduleRelayout();
                }

                function onFillWidthChanged(): void {
                    root._scheduleRelayout();
                }

                function onShapeMorphExpansionChanged(): void {
                    root._scheduleRelayout();
                }
            }
        }

        onObjectAdded: root._scheduleRelayout()
        onObjectRemoved: root._scheduleRelayout()
    }
}
