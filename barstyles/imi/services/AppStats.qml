pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// AppStats is not in this port; members read as empty.
Singleton {
    property bool enabled: false
    function batteryHours(days: int): var {
        return [];
    }
    function batteryRollup(days: int): var {
        return ({ fullMwh: 0, outMwh: 0, offAc: 0, samples: [] });
    }
    readonly property var history: []
    readonly property string todayDate: ""
    property string sampleDir: ""
}
