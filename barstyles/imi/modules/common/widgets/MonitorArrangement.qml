pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "."
import "../../../services"

Item {
    id: root

    required property var monitorConfig
    property int selectedIndex: 0
    signal monitorSelected(int index)

    property real padding: 20
    property var previewPositions: ({})
    property bool dragHasOverlap: false
    property bool expressive: false
    property bool draggingActive: false
    property int snapPulseToken: 0
    property int invalidDropToken: 0
    property int invalidDropIndex: -1
    property point nudgeOffset: Qt.point(0, 0)
    property int nudgeToken: 0

    implicitHeight: 220

    readonly property var monitors: root.monitorConfig ? (root.monitorConfig.monitors || []) : []
    readonly property var bounds: {
        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;
        for (const monitor of root.monitors) {
            if (!monitor || typeof monitor.width !== "number" || typeof monitor.height !== "number")
                continue;
            const width = root.monitorConfig.logicalWidth(monitor) || 1920;
            const height = root.monitorConfig.logicalHeight(monitor) || 1080;
            const x = monitor.name && root.previewPositions[monitor.name] !== undefined
                && root.previewPositions[monitor.name].x !== undefined
                ? root.previewPositions[monitor.name].x : (monitor.x || 0);
            const y = monitor.name && root.previewPositions[monitor.name] !== undefined
                && root.previewPositions[monitor.name].y !== undefined
                ? root.previewPositions[monitor.name].y : (monitor.y || 0);
            minX = Math.min(minX, x);
            minY = Math.min(minY, y);
            maxX = Math.max(maxX, x + width);
            maxY = Math.max(maxY, y + height);
        }
        if (minX === Infinity)
            return ({ minX: 0, minY: 0, width: 1920, height: 1080 });
        return ({ minX, minY, width: maxX - minX, height: maxY - minY });
    }

    readonly property real scaleFactor: {
        if (root.bounds.width <= 0 || root.bounds.height <= 0 || root.width <= root.padding * 2 || root.height <= root.padding * 2)
            return 0.1;
        const scaleX = (root.width - root.padding * 2) / root.bounds.width;
        const scaleY = (root.height - root.padding * 2) / root.bounds.height;
        return Math.max(0.01, Math.min(scaleX, scaleY));
    }

    readonly property point offset: Qt.point(
        (root.width - root.bounds.width * root.scaleFactor) / 2 - root.bounds.minX * root.scaleFactor,
        (root.height - root.bounds.height * root.scaleFactor) / 2 - root.bounds.minY * root.scaleFactor
    )

    readonly property var snapPoints: {
        const points = [];
        for (let i = 0; i < root.monitors.length; ++i) {
            const a = root.monitors[i];
            if (!a || a.disabled)
                continue;
            const aw = root.monitorConfig.logicalWidth(a);
            const ah = root.monitorConfig.logicalHeight(a);
            const ax = a.name && root.previewPositions[a.name] !== undefined
                && root.previewPositions[a.name].x !== undefined
                ? root.previewPositions[a.name].x : (a.x || 0);
            const ay = a.name && root.previewPositions[a.name] !== undefined
                && root.previewPositions[a.name].y !== undefined
                ? root.previewPositions[a.name].y : (a.y || 0);

            for (let j = i + 1; j < root.monitors.length; ++j) {
                const b = root.monitors[j];
                if (!b || b.disabled)
                    continue;
                const bw = root.monitorConfig.logicalWidth(b);
                const bh = root.monitorConfig.logicalHeight(b);
                const bx = b.name && root.previewPositions[b.name] !== undefined
                    && root.previewPositions[b.name].x !== undefined
                    ? root.previewPositions[b.name].x : (b.x || 0);
                const by = b.name && root.previewPositions[b.name] !== undefined
                    && root.previewPositions[b.name].y !== undefined
                    ? root.previewPositions[b.name].y : (b.y || 0);

                const aRight = ax + aw;
                const bRight = bx + bw;
                const aBottom = ay + ah;
                const bBottom = by + bh;
                const threshold = 6;
                const horizontalOverlap = Math.min(aRight, bRight) > Math.max(ax, bx);
                const verticalOverlap = Math.min(aBottom, bBottom) > Math.max(ay, by);

                if (Math.abs(aRight - bx) < threshold && verticalOverlap) {
                    points.push({ x: aRight, y: (Math.max(ay, by) + Math.min(aBottom, bBottom)) / 2 });
                } else if (Math.abs(bRight - ax) < threshold && verticalOverlap) {
                    points.push({ x: bRight, y: (Math.max(ay, by) + Math.min(aBottom, bBottom)) / 2 });
                } else if (Math.abs(aBottom - by) < threshold && horizontalOverlap) {
                    points.push({ x: (Math.max(ax, bx) + Math.min(aRight, bRight)) / 2, y: aBottom });
                } else if (Math.abs(bBottom - ay) < threshold && horizontalOverlap) {
                    points.push({ x: (Math.max(ax, bx) + Math.min(aRight, bRight)) / 2, y: bBottom });
                }
            }
        }
        return points;
    }

    function checkOverlap(monitors, index) {
        const selected = monitors[index];
        if (!selected || selected.disabled)
            return false;
        const selectedWidth = root.monitorConfig.logicalWidth(selected) || 1920;
        const selectedHeight = root.monitorConfig.logicalHeight(selected) || 1080;
        for (let i = 0; i < monitors.length; ++i) {
            if (i === index)
                continue;
            const other = monitors[i];
            if (!other || other.disabled)
                continue;
            const otherWidth = root.monitorConfig.logicalWidth(other) || 1920;
            const otherHeight = root.monitorConfig.logicalHeight(other) || 1080;
            if (selected.x < other.x + otherWidth && selected.x + selectedWidth > other.x
                    && selected.y < other.y + otherHeight && selected.y + selectedHeight > other.y)
                return true;
        }
        return false;
    }

    function computeNormalized(monitors, changedIndex, newX, newY) {
        const normalized = monitors.slice().map(monitor => Object.assign({}, monitor));
        if (normalized[changedIndex]) {
            normalized[changedIndex].x = newX;
            normalized[changedIndex].y = newY;
        }

        let minX = Infinity;
        let minY = Infinity;
        for (const monitor of normalized) {
            if (!monitor || monitor.disabled)
                continue;
            minX = Math.min(minX, monitor.x);
            minY = Math.min(minY, monitor.y);
        }

        const offsetX = minX < 0 ? -minX : 0;
        const offsetY = minY < 0 ? -minY : 0;
        if (offsetX > 0 || offsetY > 0) {
            for (const monitor of normalized) {
                if (monitor) {
                    monitor.x += offsetX;
                    monitor.y += offsetY;
                }
            }
        }
        return normalized;
    }

    function updatePreview(index, newX, newY) {
        const normalized = root.computeNormalized(root.monitors, index, newX, newY);
        root.dragHasOverlap = root.checkOverlap(normalized, index);
        const preview = {};
        for (const monitor of normalized) {
            if (monitor && monitor.name)
                preview[monitor.name] = { x: monitor.x, y: monitor.y };
        }
        root.previewPositions = preview;
    }

    function commitPosition(index, newX, newY) {
        root.monitorConfig.monitors = root.computeNormalized(root.monitors, index, newX, newY);
        root.previewPositions = {};
        root.monitorConfig.save();
    }

    component MonitorRect: Rectangle {
        id: rectRoot

        required property var monitor
        required property int monitorIndex
        required property var monitorConfig
        required property real scaleFactor
        required property point canvasOffset
        required property var allMonitors
        property bool isSelected: false
        property var previewPositions: ({})
        property bool hasOverlap: false

        signal positionCommitted(int index, int x, int y)
        signal monitorClicked(int index)
        signal positionDragging(int index, int x, int y)

        property bool isDragging: false
        property real dragX: 0
        property real dragY: 0
        property int snappedX: 0
        property int snappedY: 0
        property real snapThreshold: 12
        property real startMouseX: 0
        property real startMouseY: 0
        property real startX: 0
        property real startY: 0
        property bool expressive: false
        property int invalidDropToken: 0
        property int invalidDropIndex: -1
        property point nudgeOffset: Qt.point(0, 0)
        property int nudgeToken: 0

        property int logW: monitor && typeof monitor.width === "number" && typeof monitor.height === "number"
            ? monitorConfig.logicalWidth(monitor) : 1920
        property int logH: monitor && typeof monitor.width === "number" && typeof monitor.height === "number"
            ? monitorConfig.logicalHeight(monitor) : 1080

        x: isDragging ? dragX : ((previewPositions[monitor.name]?.x ?? monitor.x ?? 0) * scaleFactor + canvasOffset.x)
        y: isDragging ? dragY : ((previewPositions[monitor.name]?.y ?? monitor.y ?? 0) * scaleFactor + canvasOffset.y)
        width: logW * scaleFactor
        height: logH * scaleFactor
        radius: Appearance.rounding.small
        z: isDragging ? 100 : isSelected ? 2 : 1
        scale: expressive
            ? (isDragging ? 1.02 : (isSelected ? 1.012 : 1))
            : 1

        transform: [
            Translate {
                id: invalidShakeTransform
            },
            Translate {
                id: nudgeTransform
            }
        ]

        color: {
            if (monitor && monitor.disabled)
                return Appearance.colors.colLayer2;
            if (isDragging && hasOverlap)
                return Qt.alpha(Appearance.m3colors.m3error, 0.5);
            if (isDragging)
                return Qt.alpha(Appearance.colors.colPrimaryContainer, 0.7);
            if (isSelected)
                return Appearance.colors.colPrimaryContainer;
            if (hoverArea.containsMouse)
                return Appearance.colors.colSecondaryContainerHover;
            return Appearance.colors.colSecondaryContainer;
        }

        border.color: {
            if (isDragging && hasOverlap)
                return Appearance.m3colors.m3error;
            if (isDragging)
                return Appearance.colors.colPrimary;
            if (isSelected)
                return "transparent";
            return Appearance.colors.colLayer0Border;
        }
        border.width: isSelected ? 0 : (isDragging ? 2 : 1)

        Behavior on x {
            enabled: !isDragging && root.width > 40
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !isDragging && root.width > 40
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(rectRoot)
        }
        Behavior on scale {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(rectRoot)
        }

        SequentialAnimation {
            id: invalidShakeAnimation

            NumberAnimation {
                target: invalidShakeTransform
                property: "x"
                to: Appearance.rounding.verysmall
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
            NumberAnimation {
                target: invalidShakeTransform
                property: "x"
                to: -Appearance.rounding.verysmall
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
            NumberAnimation {
                target: invalidShakeTransform
                property: "x"
                to: 0
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        SequentialAnimation {
            id: nudgeAnimation

            ParallelAnimation {
                NumberAnimation {
                    target: nudgeTransform
                    property: "x"
                    to: rectRoot.nudgeOffset.x * Appearance.rounding.verysmall
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
                NumberAnimation {
                    target: nudgeTransform
                    property: "y"
                    to: rectRoot.nudgeOffset.y * Appearance.rounding.verysmall
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
            ParallelAnimation {
                NumberAnimation {
                    target: nudgeTransform
                    property: "x"
                    to: 0
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
                NumberAnimation {
                    target: nudgeTransform
                    property: "y"
                    to: 0
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        onInvalidDropTokenChanged: {
            if (rectRoot.expressive && rectRoot.invalidDropIndex === rectRoot.monitorIndex)
                invalidShakeAnimation.restart();
        }
        onNudgeTokenChanged: {
            if (rectRoot.expressive && rectRoot.isSelected)
                nudgeAnimation.restart();
        }

        DashedBorder {
            anchors.fill: parent
            color: Appearance.colors.colPrimary
            borderWidth: 2
            dashLength: 6
            gapLength: 4
            radius: rectRoot.radius
            visible: rectRoot.isSelected && !rectRoot.isDragging
        }

        Rectangle {
            parent: rectRoot.parent
            visible: rectRoot.isDragging && !rectRoot.hasOverlap
            x: rectRoot.snappedX * rectRoot.scaleFactor + rectRoot.canvasOffset.x
            y: rectRoot.snappedY * rectRoot.scaleFactor + rectRoot.canvasOffset.y
            width: rectRoot.width
            height: rectRoot.height
            radius: rectRoot.radius
            color: "transparent"
            border.color: Appearance.colors.colPrimary
            border.width: 2
            opacity: 0.6
            z: 99
        }

        Column {
            anchors.centerIn: parent
            spacing: 4

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (rectRoot.monitorIndex + 1).toString()
                font.pixelSize: Math.max(20, Math.min(36, rectRoot.width * 0.25))
                font.weight: Font.Bold
                font.family: Appearance.font.family.numbers
                color: (monitor && monitor.disabled) ? Appearance.colors.colSubtext
                    : isSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: monitor && monitor.name ? monitor.name : Translation.tr("Display")
                font.pixelSize: Math.max(9, Math.min(13, rectRoot.width * 0.1))
                font.weight: Font.Medium
                color: (monitor && monitor.disabled) ? Appearance.colors.colSubtext
                    : isSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, rectRoot.width - 8)
                horizontalAlignment: Text.AlignHCenter
            }
        }

        function snapPosition(px, py) {
            let snappedX = px;
            let snappedY = py;
            const threshold = snapThreshold / scaleFactor;
            for (let i = 0; i < allMonitors.length; ++i) {
                if (i === monitorIndex)
                    continue;
                const other = allMonitors[i];
                if (!other || other.disabled || typeof other.x !== "number" || typeof other.y !== "number")
                    continue;
                const otherWidth = monitorConfig.logicalWidth(other);
                const otherHeight = monitorConfig.logicalHeight(other);
                if (Math.abs(px - other.x) < threshold)
                    snappedX = other.x;
                if (Math.abs(px - (other.x + otherWidth)) < threshold)
                    snappedX = other.x + otherWidth;
                if (Math.abs((px + logW) - other.x) < threshold)
                    snappedX = other.x - logW;
                if (Math.abs((px + logW) - (other.x + otherWidth)) < threshold)
                    snappedX = other.x + otherWidth - logW;
                if (Math.abs(py - other.y) < threshold)
                    snappedY = other.y;
                if (Math.abs(py - (other.y + otherHeight)) < threshold)
                    snappedY = other.y + otherHeight;
                if (Math.abs((py + logH) - other.y) < threshold)
                    snappedY = other.y - logH;
                if (Math.abs((py + logH) - (other.y + otherHeight)) < threshold)
                    snappedY = other.y + otherHeight - logH;
            }
            return Qt.point(snappedX, snappedY);
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: monitor && monitor.disabled ? Qt.ArrowCursor
                : rectRoot.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.threshold: 4
            preventStealing: true

            onPressed: event => {
                const startPosition = hoverArea.mapToItem(rectRoot.parent, event.x, event.y);
                rectRoot.startMouseX = startPosition.x;
                rectRoot.startMouseY = startPosition.y;
                rectRoot.startX = rectRoot.x;
                rectRoot.startY = rectRoot.y;
                rectRoot.dragX = rectRoot.x;
                rectRoot.dragY = rectRoot.y;
                rectRoot.snappedX = monitor.x;
                rectRoot.snappedY = monitor.y;
                if (monitor && !monitor.disabled)
                    rectRoot.isDragging = true;
                if (monitor && !monitor.disabled) {
                    root.draggingActive = true;
                    root.snapPulseToken += 1;
                }
            }

            onPositionChanged: event => {
                if (!rectRoot.isDragging)
                    return;
                const currentPosition = hoverArea.mapToItem(rectRoot.parent, event.x, event.y);
                rectRoot.dragX = rectRoot.startX + currentPosition.x - rectRoot.startMouseX;
                rectRoot.dragY = rectRoot.startY + currentPosition.y - rectRoot.startMouseY;
                const realX = Math.round((rectRoot.dragX - rectRoot.canvasOffset.x) / rectRoot.scaleFactor);
                const realY = Math.round((rectRoot.dragY - rectRoot.canvasOffset.y) / rectRoot.scaleFactor);
                const snapped = rectRoot.snapPosition(realX, realY);
                rectRoot.snappedX = snapped.x;
                rectRoot.snappedY = snapped.y;
                rectRoot.positionDragging(rectRoot.monitorIndex, snapped.x, snapped.y);
            }

            onReleased: {
                rectRoot.isDragging = false;
                root.draggingActive = false;
                if (rectRoot.snappedX === monitor.x && rectRoot.snappedY === monitor.y) {
                    rectRoot.monitorClicked(rectRoot.monitorIndex);
                    return;
                }
                rectRoot.positionCommitted(rectRoot.monitorIndex, rectRoot.snappedX, rectRoot.snappedY);
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer2Base
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        Item {
            anchors.fill: parent

            Repeater {
                model: root.monitors.length

                delegate: MonitorRect {
                    required property int index
                    monitor: root.monitors[index]
                    monitorIndex: index
                    monitorConfig: root.monitorConfig
                    scaleFactor: root.scaleFactor
                    canvasOffset: root.offset
                    allMonitors: root.monitors
                    isSelected: index === root.selectedIndex
                    previewPositions: root.previewPositions
                    hasOverlap: root.dragHasOverlap && isDragging
                    expressive: root.expressive
                    invalidDropToken: root.invalidDropToken
                    invalidDropIndex: root.invalidDropIndex
                    nudgeOffset: root.nudgeOffset
                    nudgeToken: root.nudgeToken

                    onMonitorClicked: index => {
                        root.selectedIndex = index;
                        root.monitorSelected(index);
                    }
                    onPositionDragging: (index, x, y) => root.updatePreview(index, x, y)
                    onPositionCommitted: (index, x, y) => {
                        const hadOverlap = root.dragHasOverlap;
                        root.previewPositions = {};
                        root.dragHasOverlap = false;
                        if (hadOverlap) {
                            root.invalidDropIndex = index;
                            root.invalidDropToken += 1;
                        }
                        if (!hadOverlap)
                            root.commitPosition(index, x, y);
                    }
                }
            }

            Repeater {
                model: root.snapPoints

                delegate: Rectangle {
                    id: snapPoint
                    required property var modelData
                    property int pulseToken: root.snapPulseToken
                    x: modelData.x * root.scaleFactor + root.offset.x - width / 2
                    y: modelData.y * root.scaleFactor + root.offset.y - height / 2
                    width: 14
                    height: 14
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimary
                    border.width: 1.5
                    border.color: Appearance.colors.colOnPrimary
                    z: 10

                    onPulseTokenChanged: {
                        if (root.draggingActive)
                            snapPulseAnimation.restart();
                    }

                    SequentialAnimation {
                        id: snapPulseAnimation

                        NumberAnimation {
                            target: snapPoint
                            property: "scale"
                            from: 0.82
                            to: 1.12
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                        NumberAnimation {
                            target: snapPoint
                            property: "scale"
                            to: 1
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "link"
                        iconSize: 9
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.monitors.length === 0
        text: Translation.tr("No displays detected")
        color: Appearance.colors.colOnLayer2
        font.pixelSize: Appearance.font.pixelSize.normal
    }

    onMonitorsChanged: {
        if (root.selectedIndex >= root.monitors.length)
            root.selectedIndex = Math.max(0, root.monitors.length - 1);
    }
}
