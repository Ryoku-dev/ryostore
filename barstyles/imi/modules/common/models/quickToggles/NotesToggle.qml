pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../../.."
import "../../../../services"
import "../.."
import "../../functions"
import "../../widgets"

QuickToggleModel {
    id: root

    name: Translation.tr("Notes")
    hasStatusText: false
    toggled: GlobalStates.notesAppOpen
    icon: "note_stack"

    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        GlobalStates.notesAppOpen = !GlobalStates.notesAppOpen;
    }

    tooltipText: Translation.tr("Notes")
}
