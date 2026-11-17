import QtQuick

Row {
    id: root
    property int count: 6
    property real barWidth: 3
    property real maxHeight: 16
    property color color: Theme.live
    spacing: 2
    height: maxHeight

    Repeater {
        model: root.count
        Rectangle {
            id: bar
            required property int index
            readonly property real level: {
                const b = Hub.bars;
                if (!b || b.length === 0) return 0;
                // mirror so the middle bars are the loudest, iOS-style
                const half = root.count / 2;
                const k = bar.index < half ? half - 1 - bar.index : bar.index - half;
                const i = Math.min(b.length - 1, Math.floor(k * b.length / half / 2));
                return Math.min(1, (b[i] || 0) / 100);
            }
            anchors.verticalCenter: parent.verticalCenter
            width: root.barWidth
            height: Math.max(root.barWidth, root.maxHeight * (Hub.playing ? level : 0))
            radius: width / 2
            color: root.color
            Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 400 } }
        }
    }
}
