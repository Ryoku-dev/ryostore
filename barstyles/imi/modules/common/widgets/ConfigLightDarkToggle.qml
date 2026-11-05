import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../services"
import ".."
import "."

RowLayout {
    id: lightDarkToggleRoot
    property string text: ""

    Layout.alignment: Qt.AlignHCenter
    Layout.fillWidth: true
    Layout.preferredHeight: 60
    uniformCellSizes: true

    component SmallLightDarkPreferenceButton: RippleButton {
        id: smallLightDarkPreferenceButton
        required property bool dark
        property color colText: enabled ? toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2 : Appearance.colors.colOnLayer3
        padding: 5
        Layout.fillWidth: true
        toggled: Appearance.m3colors.darkmode === dark
        colBackground: Appearance.colors.colLayer2
        onClicked: {
            if (Config.options?.background?.useSeparateLightModeWallpaper) {
                if (dark) {
                    const darkPath = Config.options.background.wallpaperPath;
                    if (darkPath && darkPath !== "") {
                        Wallpapers.apply(darkPath, true);
                    } else {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode dark --noswitch`]);
                    }
                } else {
                    const lightPath = Config.options.background.lightModeWallpaperPath;
                    if (lightPath && lightPath !== "") {
                        Wallpapers.applyLightModeWallpaper(lightPath);
                    } else {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode light --noswitch`]);
                    }
                }
            } else {
                Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`]);
            }
        }
        StyledToolTip {
            extraVisibleCondition: !smallLightDarkPreferenceButton.enabled
            text: Translation.tr("Custom color scheme has been selected")
        }
        contentItem: Item {
            anchors.centerIn: parent
            RowLayout {
                anchors.centerIn: parent
                spacing: 10
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    iconSize: 30
                    text: dark ? "dark_mode" : "light_mode"
                    fill: toggled ? 1 : 0
                    color: smallLightDarkPreferenceButton.colText
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: dark ? Translation.tr("Dark") : Translation.tr("Light")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: smallLightDarkPreferenceButton.colText
                }
            }
        }
    }

    SmallLightDarkPreferenceButton {
        Layout.preferredHeight: 60
        dark: false
    }
    SmallLightDarkPreferenceButton {
        Layout.preferredHeight: 60
        dark: true
    }
}
