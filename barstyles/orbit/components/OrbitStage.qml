import QtQuick

Column {
    id: root

    property bool open: false
    property int delay: 0
    property real lift: 7

    opacity: open ? 1 : 0

    transform: Translate {
        y: root.open ? 0 : root.lift

        Behavior on y {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.open ? root.delay : 0
                }

                NumberAnimation {
                    duration: root.open ? 190 : 90
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation {
                duration: root.open ? root.delay : 0
            }

            NumberAnimation {
                duration: root.open ? 155 : 80
                easing.type: Easing.OutCubic
            }
        }
    }
}
