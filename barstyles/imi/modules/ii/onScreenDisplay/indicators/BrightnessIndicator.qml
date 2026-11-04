import "../../../../services"
import QtQuick
import Quickshell
import ".."
import "../../../common/widgets"
import "../../../common"

Loader {
    id: root
    sourceComponent: Config.options.osd.style === "material" ? materialOsdComp : minimalOsdComp

    property var focusedScreen: Quickshell.screens.find(s => s.name === HyprlandData.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
    property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)

    Component {
        id: minimalOsdComp
        OsdValueIndicator {
            id: brightnessOsd
            icon: {
                if (Hyprsunset.temperatureActive) return "routine";
                const val = brightnessOsd.value;
                if (val <= 0.33) return "brightness_low";
                if (val <= 0.66) return "brightness_medium";
                return "brightness_high";
            }
            rotateIcon: true
            scaleIcon: true
            name: Translation.tr("Brightness")
            value: root.brightnessMonitor?.brightness ?? 0.5
            shape: MaterialShape.Shape.Burst
        }
    }

    Component {
        id: materialOsdComp
        OsdMaterialValueIndicator {
            id: osdValues
            value: root.brightnessMonitor?.brightness ?? 0.5
            icon: {
                if (Hyprsunset.temperatureActive) return "routine";
                const val = osdValues.value;
                if (val <= 0.33) return "brightness_low";
                if (val <= 0.66) return "brightness_medium";
                return "brightness_high";
            }
            shape: MaterialShape.Shape.SoftBurst

            onMoved: function(newValue) {
                if (root.brightnessMonitor) {
                    root.brightnessMonitor.setBrightness(newValue);
                }
            }
        }
    }
}