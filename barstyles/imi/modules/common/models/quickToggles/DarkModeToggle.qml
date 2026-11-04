import QtQuick
import Quickshell
import "../../../.."
import "../../../../services"
import "../.."
import "../../functions"
import "../../widgets"

QuickToggleModel {
    name: Translation.tr("Dark Mode")
    statusText: Appearance.m3colors.darkmode ? Translation.tr("Dark") : Translation.tr("Light")

    toggled: Appearance.m3colors.darkmode
    icon: "contrast"
    hasMenu: true
    
    mainAction: () => {
        if (Config.options?.background?.useSeparateLightModeWallpaper) {
            if (Appearance.m3colors.darkmode) {
                // Switching to light mode
                const lightPath = Config.options.background.lightModeWallpaperPath;
                if (lightPath && lightPath !== "") {
                    Wallpapers.applyLightModeWallpaper(lightPath);
                    return;
                }
            } else {
                // Switching to dark mode
                const darkPath = Config.options.background.wallpaperPath;
                if (darkPath && darkPath !== "") {
                    Wallpapers.apply(darkPath, true);
                    return;
                }
            }
        }
        if (Appearance.m3colors.darkmode) {
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"]);
        } else {
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"]);
        }
    }

    tooltipText: Translation.tr("Dark Mode")
}
