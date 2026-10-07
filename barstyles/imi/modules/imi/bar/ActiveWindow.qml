import "../../.."
import "../../../services"
import "../../common"
import "../../common/models"
import "../../common/widgets"
import "../../common/functions"
import Ryoku.Ui.Singletons
import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property bool vertical: false
    readonly property string screenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var focusedWindow: Wm.focusedWindow ?? ToplevelManager.activeToplevel
    readonly property bool tlActivated: ToplevelManager.activeToplevel?.activated ?? false
    property bool focusingThisMonitor: {
        const fout = Wm.focusedOutput ?? "";
        if (fout !== "" && root.screenName !== "")
            return fout === root.screenName;
        return root.tlActivated && root.screenName !== "";
    }
    readonly property int screenWorkspace: WM.activeWorkspaceNumber(root.screenName)
    property var biggestWindow: HyprlandData.biggestWindowForWorkspace(root.screenWorkspace)

    property string activeAppClass: {
        if (!root.focusingThisMonitor || !root.focusedWindow)
            return root.biggestWindow?.class ?? ""
        return root.focusedWindow?.appId ?? root.focusedWindow?.class ?? root.biggestWindow?.class ?? ""
    }

    property var mainAppIconSource: {
        if (!root.activeAppClass || root.activeAppClass === "")
            return Quickshell.iconPath("user-desktop", "image-missing")
        return Quickshell.iconPath(AppSearch.guessIcon(root.activeAppClass), 
            Quickshell.iconPath("user-desktop", "image-missing"))
    }

    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : Math.min(colLayout.implicitWidth + 6, 280)
    implicitHeight: vertical ? iconItem.implicitHeight : Appearance.sizes.barHeight

    // Vertical
    Item {
        id: iconItem
        visible: root.vertical
        anchors.centerIn: parent
        implicitWidth: 22
        implicitHeight: 22

        IconImage {
            anchors.centerIn: parent
            source: root.mainAppIconSource
            implicitSize: 18
            visible: root.mainAppIconSource !== ""
        }
    }

    // Horizontal
    ColumnLayout {
        id: colLayout
        visible: !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Appearance.spacing.space50
        anchors.rightMargin: Appearance.spacing.space100
        spacing: -Appearance.spacing.space50

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: root.focusingThisMonitor && root.focusedWindow && root.biggestWindow ?
                (root.focusedWindow?.appId ?? root.focusedWindow?.class ?? "") :
                (root.biggestWindow?.class) ?? Translation.tr("Desktop")
        }
        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            text: root.focusingThisMonitor && root.focusedWindow && root.biggestWindow ?
                (root.focusedWindow?.title ?? "") :
                (root.biggestWindow?.title) ?? `${Translation.tr("Workspace")} ${root.screenWorkspace}`
        }
    }
}
