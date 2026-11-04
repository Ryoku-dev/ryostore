import QtQuick
import Quickshell
import "../../../.."
import "../.."
import "../../functions"
import "../../widgets"
import "../../../../services"

QuickToggleModel {
    name: Translation.tr("Laptop Keyboard")
    statusText: toggled ? Translation.tr("Disabled") : Translation.tr("Enabled")
    toggled: LaptopKeyboardService.disabled
    icon: toggled ? "keyboard_off" : "keyboard"
    mainAction: () => {
        LaptopKeyboardService.toggle();
    }
    tooltipText: {
        if (LaptopKeyboardService.keydDetected)
            return toggled ? Translation.tr("Built-in keyboard disabled (keyd active, stop keyd to take effect)") : Translation.tr("Disable built-in laptop keyboard (incompatible with keyd daemon)");

        return toggled ? Translation.tr("Built-in keyboard disabled | Click to enable") : Translation.tr("Disable built-in laptop keyboard");
    }
}
