/* KasugaiCrow.qml — the crow herself.
 *
 * One crow per slayer. She is drawn faceted — dark
 * chrome plates with lit edges, a cybernetic bird —
 * because she is a machine that carries words, perched
 * on the prism wire at the overlay's bottom-right. Her
 * eye is the prism; when a critical scroll waits, the
 * eye burns rose and she will not settle.
 *
 * She arrives when there is something to carry and
 * takes off when the last scroll has burned — the
 * flight is the dispatch's business (it moves her x);
 * the breathing, the blink, and the restless critical
 * shiver are hers.
 */
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    // The highest priority on the wire, for the eye:
    // "" (calm) or "CRITICAL".
    property string mood: ""

    width: 128
    height: 116

    // The breath — a slow ±2px settle, always while she
    // is on the wire.
    SequentialAnimation on y {
        loops: Animation.Infinite
        NumberAnimation { to: 2; duration: 2100; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 2100; easing.type: Easing.InOutSine }
    }

    // The critical shiver — she will not sit still under
    // an unacknowledged critical.
    property real _shiver: 0
    SequentialAnimation on _shiver {
        running: root.mood === "CRITICAL"
        loops: Animation.Infinite
        NumberAnimation { to: -1.2; duration: 80 }
        NumberAnimation { to: 1.2; duration: 80 }
        NumberAnimation { to: 0; duration: 200 }
        PauseAnimation { duration: 1400 }
    }

    Item {
        anchors.fill: parent
        x: root._shiver

        // ── The plates ──────────────────────────────────────
        Shape {
            anchors.fill: parent
            // Tail — a long wedge sweeping down-right.
            ShapePath {
                fillColor: "#0B0E14"
                strokeColor: Qt.rgba(0.13, 0.83, 0.93, 0.35)
                strokeWidth: 1
                PathSvg { path: "M78 56 L118 82 L113 92 L72 70 Z" }
            }
            // Body — the main plate.
            ShapePath {
                fillColor: "#11151D"
                strokeColor: Qt.rgba(0.13, 0.83, 0.93, 0.5)
                strokeWidth: 1
                PathSvg { path: "M28 52 L56 36 L86 46 L82 72 L48 82 L26 68 Z" }
            }
            // Wing — a darker plate over the body, lit edge.
            ShapePath {
                fillColor: "#080A0F"
                strokeColor: Qt.rgba(0.13, 0.83, 0.93, 0.65)
                strokeWidth: 1
                PathSvg { path: "M42 54 L66 46 L78 60 L62 74 L42 68 Z" }
            }
            // Head — the helm plate.
            ShapePath {
                fillColor: "#151A24"
                strokeColor: Qt.rgba(0.13, 0.83, 0.93, 0.55)
                strokeWidth: 1
                PathSvg { path: "M12 32 L34 26 L46 40 L36 56 L14 52 L8 42 Z" }
            }
            // Beak — a sharp wedge, her delivery edge.
            ShapePath {
                fillColor: "#1C2330"
                strokeColor: Qt.rgba(0.96, 0.98, 1, 0.5)
                strokeWidth: 1
                PathSvg { path: "M10 40 L0 47 L11 51 Z" }
            }
            // Legs — two struts to the wire.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.rgba(0.13, 0.83, 0.93, 0.6)
                strokeWidth: 1.6
                PathSvg { path: "M50 81 L50 97 M51 97 L46 100 M51 97 L56 100 M64 79 L64 97 M65 97 L60 100 M65 97 L70 100" }
            }
        }

        // ── The prism eye ───────────────────────────────────
        Rectangle {
            id: _eyeGlow
            x: 19; y: 31
            width: 16; height: 16
            radius: 8
            color: root.mood === "CRITICAL"
                ? Qt.rgba(0.96, 0.25, 0.37, 0.30)
                : root.mood === "HIGH"
                ? Qt.rgba(0.96, 0.70, 0.0, 0.28)
                : root.mood === "MEDIUM"
                ? Qt.rgba(0.06, 0.85, 0.64, 0.26)
                : Qt.rgba(0.13, 0.83, 0.93, 0.22)
        }
        Rectangle {
            id: _eye
            x: 23; y: 35
            width: 8; height: 8
            radius: 4
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.mood === "CRITICAL" ? "#F43F5E" : root.mood === "HIGH" ? "#F5B300" : root.mood === "MEDIUM" ? "#10D9A3" : root.mood === "LOW" ? "#22D3EE" : "#22D3EE" }
                GradientStop { position: 0.5; color: root.mood === "CRITICAL" ? "#F43F5E" : root.mood === "HIGH" ? "#F5B300" : root.mood === "MEDIUM" ? "#10D9A3" : root.mood === "LOW" ? "#22D3EE" : "#A78BFA" }
                GradientStop { position: 1.0; color: root.mood === "CRITICAL" ? "#F43F5E" : root.mood === "HIGH" ? "#F5B300" : root.mood === "MEDIUM" ? "#10D9A3" : root.mood === "LOW" ? "#22D3EE" : "#F5B300" }
            }
            // The blink — a lid, on her own slow clock.
            transform: Scale {
                id: _lid
                origin.x: 4; origin.y: 4
                yScale: 1
            }
            SequentialAnimation {
                running: true
                loops: Animation.Infinite
                PauseAnimation { duration: 3400 }
                NumberAnimation { target: _lid; property: "yScale"; to: 0.08; duration: 70 }
                NumberAnimation { target: _lid; property: "yScale"; to: 1; duration: 110 }
                PauseAnimation { duration: 2600 }
            }
        }
    }
}
