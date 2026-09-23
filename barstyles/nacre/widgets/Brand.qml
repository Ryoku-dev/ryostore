import QtQuick
import Quickshell
import shell.services
import shell.barkit as Pill

Item {
    property real barHeight: 40

    implicitWidth: 24
    implicitHeight: 26

    Pill.BrandMark {
        anchors.centerIn: parent
        size: 12
    }
    TapHandler {
        // the click action is a Nacre setting (Bar Studio > Appearance): the
        // launcher, or the same quick-settings sidebar Super+Esc opens.
        onTapped: {
            if (Config.normalizedNacre.brandClick === "quicksettings")
                ShellState.requestSurfaceActive("quick-settings", undefined)
            else
                Quickshell.execDetached(["ryoku-shell", "launcher"])
        }
    }
}
