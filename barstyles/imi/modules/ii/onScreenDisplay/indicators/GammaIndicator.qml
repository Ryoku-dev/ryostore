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
            id: rotateIcon
            icon: "wb_twilight"
            name: Translation.tr("Gamma")
            from: Hyprsunset.gammaLowerLimit / 100
            value: Hyprsunset.gamma / 100 ?? 0.5
        }
    }

    Component {
        id: materialOsdComp
        OsdMaterialValueIndicator {
            id: osdValues
            value: Hyprsunset.gamma / 100 ?? 0.5
            from: Hyprsunset.gammaLowerLimit / 100
            minimalFrom: Hyprsunset.gammaLowerLimit / 100
            icon: "wb_twilight"
            shape: MaterialShape.Shape.Gem

            onMoved: function(v) {
                const gamma = Math.max(Hyprsunset.gammaLowerLimit, Math.min(100, v * 100));
                Hyprsunset.setGamma(gamma);
            }
        }
    }
}