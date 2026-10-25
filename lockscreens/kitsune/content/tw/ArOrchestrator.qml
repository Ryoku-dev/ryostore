pragma Singleton

import QtQuick

// ArOrchestrator — the resting seat.
//
// In Jurai shell this singleton is the AR stage's living state: the
// daemon's pulse, the scry phases, the folds drawn out on the hub.
// A lock face has no stage and no daemon, and the scene's hub — the
// one seat that reads him — is never raised at the door. What stands
// here is his shape at rest: every property the scene can name,
// holding the quiet values, so the face stands on its own in any
// host. Written for the RyoStore port (2026-10-25); the scene files
// themselves are unmodified.
QtObject {
    property real aseWidgetCenterX: 0.5
    property real aseWidgetCenterY: 0.0
    property color prismaticColor: "#bec2ff"
    property int thinkingPhase: 0
    property string scryCommPhase: "idle"
    property string daemonState: "asleep"
    property var aseDrawnFolds: []
    property string intelActiveMode: ""
    property real commandPulse: 0.0
    property real animationPhase: 0.0
    property string breathingStyle: "moon"
    property real shiguruiTokensPerSec: 0.0
    property string aseHubDrawFold: ""
    property string aseHubRecallFold: ""
}
