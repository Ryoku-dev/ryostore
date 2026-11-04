pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// FeatureDeps is not in this port; members read as empty.
Singleton {
    property bool enabled: true
    property var requiredMissing: []
    function refresh(): void {
    }
}
