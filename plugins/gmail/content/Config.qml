pragma Singleton
import QtQuick

QtObject {
    id: root
    property bool ready: true
    property QtObject options: QtObject {
        property QtObject appearance: QtObject {
            property real roundingValue: 8
            property QtObject transparency: QtObject {
                property bool enable: true
                property bool automatic: false
                property real backgroundTransparency: 0.15
                property real contentTransparency: 0.95
            }
        }
        property QtObject search: QtObject {
            property QtObject appearance: QtObject {
                property bool showKeyHints: false
            }
        }
        property QtObject interactions: QtObject {
            property QtObject scrolling: QtObject {
                property real touchpadScrollFactor: 100
                property real mouseScrollFactor: 50
                property real mouseScrollDeltaThreshold: 120
            }
        }
    }
}
