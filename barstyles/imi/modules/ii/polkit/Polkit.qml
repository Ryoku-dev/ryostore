import "../../.."
import "../../../services"
import "../../common"
import "../../common/widgets"
import "../../common/functions"
import QtQuick
import Quickshell
import Quickshell.Wayland

FullscreenPolkitWindow {
    id: root
    contentComponent: Component {
        PolkitContent {}
    }
}
