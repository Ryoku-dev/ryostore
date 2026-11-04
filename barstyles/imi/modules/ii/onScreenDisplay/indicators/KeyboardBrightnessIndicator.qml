import "../../../../services"
import QtQuick
import Quickshell
import ".."
import "../../../common/widgets"
import "../../../common"

Loader {
    sourceComponent: Config.options.osd.style === "material" ? materialOsdComp : minimalOsdComp

    Component {
        id: minimalOsdComp
        OsdValueIndicator {
            id: kbdBrightnessOsd
            icon: "keyboard"
            rotateIcon: false
            scaleIcon: true
            name: Translation.tr("Keyboard Backlight")
            value: KeyboardBacklight.percentage / 100
            shape: MaterialShape.Shape.Hexagon
        }
    }

    Component {
        id: materialOsdComp
        OsdMaterialValueIndicator {
            id: osdValues
            value: KeyboardBacklight.percentage / 100
            icon: "keyboard"
            shape: MaterialShape.Shape.Hexagon

            onMoved: function(newValue) {
                const max = KeyboardBacklight.maxValue;
                const level = Math.round(newValue * max);
                KeyboardBacklight.setValue(level);
            }
        }
    }
}