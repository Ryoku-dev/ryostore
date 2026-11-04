import QtQuick
import Quickshell
import "../../../.."
import "../../../../services"
import "../.."
import "../../functions"
import "../../widgets"

QuickToggleModel {
    id: root
    name: Translation.tr("Screen Record")
    statusText: Persistent.states.screenRecord.active
        ? (Persistent.states.screenRecord.paused ? Translation.tr("Paused") : Translation.tr("Recording"))
        : ""
    toggled: Persistent.states.screenRecord.active
    icon: Persistent.states.screenRecord.active ? "stop" : "videocam"

    readonly property string fullTooltipText: Translation.tr("Screen Record") + "\n" + Translation.tr("Right click to record a region")

    mainAction: () => {
        if (!Persistent.states.screenRecord.active) {
            GlobalStates.sidebarRightOpen = false;
            delayedFullscreenTimer.start();
        } else {
            Quickshell.execDetached([Directories.recordScriptPath]);
        }
    }

    altAction: () => {
        if (!Persistent.states.screenRecord.active) {
            GlobalStates.sidebarRightOpen = false;
            delayedRegionTimer.start();
        } else {
            Quickshell.execDetached([Directories.recordScriptPath]);
        }
    }

    Timer {
        id: delayedFullscreenTimer
        interval: 300
        repeat: false
        onTriggered: {
            Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen"]);
        }
    }

    Timer {
        id: delayedRegionTimer
        interval: 300
        repeat: false
        onTriggered: {
            Quickshell.execDetached([Directories.recordScriptPath, "--region"]);
        }
    }

    tooltipText: fullTooltipText
}
