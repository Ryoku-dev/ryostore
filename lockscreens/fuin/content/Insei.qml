pragma Singleton

import QtQuick

// Insei's seat, kept empty on purpose.
//
// In the shell, Threshold shows Insei's medallion only while she is present
// (her own rule: absence hides it). A greeter theme has no Insei to witness,
// so this stub answers "not available" and the medallion code in Threshold
// stands verbatim, hidden by her own absence rule — the same face, the same
// law, on both sides of the door.
QtObject {
    readonly property bool available: false
    readonly property string state: "resting"
}
