import "../.."
import "../../models/quickToggles"
import "../../widgets"
import "../../../../services"
import QtQuick
import Quickshell
import Quickshell.Io

AndroidQuickToggleButton {
    id: root

    toggleModel: CloudflareWarpToggle {}
}
