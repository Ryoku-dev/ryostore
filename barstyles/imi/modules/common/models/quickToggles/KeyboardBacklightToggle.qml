import QtQuick
import Quickshell
import "../../../.."
import "../../../../services"
import "../.."
import "../../functions"
import "../../widgets"

QuickToggleModel {
    name: Translation.tr("Keyboard Light")
    statusText: KeyboardBacklight.levelText

    toggled: KeyboardBacklight.available && KeyboardBacklight.currentValue > 0
    available: KeyboardBacklight.available
    icon: {
        if (!KeyboardBacklight.available) return "keyboard_hide"
        if (KeyboardBacklight.currentValue === 0) return "backlight_high_off"
        if (KeyboardBacklight.maxValue <= 2) {
            return KeyboardBacklight.currentValue === 1 ? "backlight_high" : "brightness_6"
        }
        return "brightness_6"
    }
    hasMenu: true

    mainAction: () => {
        KeyboardBacklight.cycleNext()
    }

    altAction: () => {
        KeyboardBacklight.cyclePrevious()
    }

    tooltipText: Translation.tr("Keyboard backlight")
}
