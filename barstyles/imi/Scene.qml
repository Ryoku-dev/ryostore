pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "modules/common"
import "modules/ii/bar"
import "modules/ii/dynamicIsland"
import "modules/ii/dynamicIsland/core"
import "modules/ii/sidebarPolicies"
import "modules/ii/sidebarDashboard"
import "modules/ii/onScreenDisplay"
import "modules/ii/onScreenDisplay/minimalist"
import "modules/ii/notificationPopup"
import "modules/ii/sessionScreen"
import "modules/ii/mediaControls"
import "modules/ii/bluetoothConnectionPopup"
import "modules/ii/bluetoothPairing"
import "modules/ii/modeFlashPopup"
import "modules/ii/alarmRingingPopup"
import "modules/ii/timerAlertPopup"
import "modules/ii/reminderAlertPopup"
import "modules/ii/polkit"
import "modules/ii/screenCorners"
import "modules/ii/wrappedFrame"
import "modules/ii/modes"
import "modules/ii/verticalBar"
import "modules/ii/phoneControls"
import "modules/common/panels/windowSwitcher"
import "modules/settings"
import "services"

// Entry point, loaded by Ryoku Frame.qml once per monitor with modelData set
// to the screen. Surfaces that resolve their own screen (island, sidebars,
// OSD, toasts, session) are instantiated here per screen// family did per screen.
Scope {
    id: scene

    property var modelData: null

    readonly property bool usingWrappedFrame: Config.options.appearance.fakeScreenRounding === 3

    Loader {
        active: !BarPlacement.vertical
        sourceComponent: Bar { screen: scene.modelData }
    }

    Loader {
        active: BarPlacement.vertical
        sourceComponent: VerticalBar {}
    }

    Loader {
        active: IslandPolicy.enabled
        sourceComponent: DynamicIsland {}
    }

    SidebarPolicies {}
    SidebarDashboard {}

    Loader {
        active: !(Config.options.osd.style === "minimalist" || Config.options.osd.style === "material")
        sourceComponent: OnScreenDisplay {}
    }
    Loader {
        active: Config.options.osd.style === "minimalist" || Config.options.osd.style === "material"
        sourceComponent: MinimalistOsd {}
    }

    Loader {
        active: !IslandPolicy.ownsNotifications
        sourceComponent: NotificationPopup {}
    }

    SessionScreen {}
    MediaControls {}

    Loader {
        active: !IslandPolicy.ownsBluetoothPopup
        sourceComponent: BluetoothConnectionPopup {}
    }
    BluetoothPairing {}
    Loader {
        active: !IslandPolicy.ownsModeFlash && Config.options.modes.overlayEnabled
        sourceComponent: ModeFlashPopup {}
    }
    Loader {
        active: AlarmService.ringingAlarmIndex !== -1 && Config.options.time.alarms.useFullscreenPopup
        sourceComponent: AlarmRingingPopup {}
    }
    Loader {
        active: TimerService.alert !== null
        sourceComponent: TimerAlertPopup {}
    }
    Loader {
        active: false // ReminderAlertPopup: reminders service is not part of this port yet
    }
    ScreenCorners {}

    Polkit {}
    Loader {
        active: scene.usingWrappedFrame
        sourceComponent: WrappedFrame {}
    }
    Loader {
        active: Config.options.modes.overlayEnabled
        sourceComponent: ModesApp {}
    }
    WindowSwitcherPanel {}
    WindowSwitcherPeek {}
    // Phone floating-window controls return with the phone suite (KDE Connect
    // based) in a later wave.

    // Settings is a single FloatingWindow on the primary screen.
    Loader {
        active: scene.modelData !== null && scene.modelData.name !== undefined
            && scene.modelData.name === (Quickshell.screens[0]?.name ?? "")
            && (GlobalStates.settingsOpen || GlobalStates.settingsPendingPageName !== "")
        sourceComponent: SettingsWindow {}
    }

    // Handoff for Ryoku Hub > Bar Studio.
    IpcHandler {
        target: "imi"
        function open(): void { GlobalStates.openSettings(); }
        function toggle(): void { GlobalStates.editMode = !GlobalStates.editMode; }
        function openSettings(): void {
            GlobalStates.openSettings();
        }
    }
}
