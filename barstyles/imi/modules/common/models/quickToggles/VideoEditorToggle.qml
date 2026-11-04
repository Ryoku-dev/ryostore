import QtQuick
import Quickshell
import "../../../.."
import "../../../../services"
import "../.."
import "../../functions"
import "../../widgets"

QuickToggleModel {
    name: Translation.tr("Video Editor")
    hasStatusText: false
    toggled: false
    icon: "movie_edit"

    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        delayedActionTimer.start();
    }
    
    Timer {
        id: delayedActionTimer
        interval: 300
        repeat: false
        onTriggered: {
            GlobalStates.videoEditorPath = "";
            GlobalStates.videoEditorOpen = true;
        }
    }

    tooltipText: Translation.tr("Video Editor")
}
