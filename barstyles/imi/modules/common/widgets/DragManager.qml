import ".."
import "../../../services"
import QtQuick

/**
 * A convenience MouseArea for handling drag events.
 */
MouseArea {
    id: root
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton

    property bool interactive: true
    property bool automaticallyReset: true
    readonly property real dragDiffX: _dragDiffX
    readonly property real dragDiffY: _dragDiffY
    property real startX: 0
    property real startY: 0
    property real minimumX: -Infinity
    property real maximumX: Infinity
    property real regionTopLeftX: Math.min(startX, startX + _dragDiffX)
    property real regionTopLeftY: Math.min(startY, startY + _dragDiffY)
    property real regionWidth: Math.abs(_dragDiffX)
    property real regionHeight: Math.abs(_dragDiffY)

    signal dragPressed(diffX: real, diffY: real)
    signal dragReleased(diffX: real, diffY: real)
    
    property bool dragging: false
    property real _dragDiffX: 0
    property real _dragDiffY: 0

    function resetDrag() {
        _dragDiffX = 0
        _dragDiffY = 0
    }

    onPressed: (mouse) => {
        if (!root.interactive) {
            if (mouse.button === Qt.LeftButton) {
                mouse.accepted = false;
            }
            return;
        }
        if (mouse.button === Qt.LeftButton) {
            startX = mouse.x
            startY = mouse.y
        }
    }
    onReleased: (mouse) => {
        if (!root.interactive) {
            return;
        }
        dragging = false
        root.dragReleased(_dragDiffX, _dragDiffY);
        if (root.automaticallyReset) {
            root.resetDrag();
        }
    }
    onPositionChanged: (mouse) => {
        if (!root.interactive) {
            return;
        }
        if (mouse.buttons & Qt.LeftButton) {
            let dx = mouse.x - startX
            if (dx < root.minimumX) dx = root.minimumX
            if (dx > root.maximumX) dx = root.maximumX
            root._dragDiffX = dx
            root._dragDiffY = mouse.y - startY
            const dist = Math.sqrt(root._dragDiffX * root._dragDiffX + root._dragDiffY * root._dragDiffY);
            root.dragPressed(_dragDiffX, _dragDiffY);
            root.dragging = true;
        }
    }
    onCanceled: (mouse) => {
        if (!root.interactive) {
            return;
        }
        released(mouse);
    }
}
