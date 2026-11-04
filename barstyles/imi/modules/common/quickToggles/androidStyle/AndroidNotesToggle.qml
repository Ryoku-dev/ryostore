pragma ComponentBehavior: Bound

import "../../../.."
import "../.."
import "../../models/quickToggles"
import "../../widgets"
import "../../../../services"
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root

    toggleModel: NotesToggle {}
}
