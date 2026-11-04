import "../../../../services"
import "../.."
import "../../models/quickToggles"
import "../../functions"
import "../../widgets"
import QtQuick

AndroidQuickToggleButton {
    id: root
    toggleModel: ModesToggle {
        // The model's "nothing to toggle" fallback lands on the menu.
        altAction: () => root.openMenu()
    }
}
