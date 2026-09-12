import QtQuick
import shell.services

Item {
    id: root

    property bool running: false
    property color accentColor: Theme.primary

    implicitWidth: 18
    implicitHeight: 16

    Row {
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: 4

            delegate: Rectangle {
                id: bar

                required property int index

                property real pulse: 0.18

                readonly property real peak:
                    index === 0
                        ? 0.68
                        : index === 1
                            ? 1.0
                            : index === 2
                                ? 0.80
                                : 0.56

                width: 2.5
                height: 3 + 10 * pulse
                radius: width / 2
                color: root.accentColor
                opacity: root.running ? 0.95 : 0.42

                Behavior on height {
                    enabled: !root.running

                    NumberAnimation {
                        duration: 190
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }

                SequentialAnimation on pulse {
                    id: pulseAnim
                    running: root.running
                    loops: Animation.Infinite

                    PauseAnimation {
                        duration: bar.index * 55
                    }

                    NumberAnimation {
                        from: 0.18
                        to: bar.peak
                        duration: 190 + bar.index * 22
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        from: bar.peak
                        to: 0.22
                        duration: 220 + bar.index * 18
                        easing.type: Easing.InOutSine
                    }

                    PauseAnimation {
                        duration: (3 - bar.index) * 30
                    }
                }

                Connections {
                    target: root

                    function onRunningChanged() {
                        if (!root.running) {
                            pulseAnim.stop();
                            bar.pulse = 0.18;
                        }
                    }
                }
            }
        }
    }
}
