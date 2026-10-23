import QtQuick
import "../../../services"
import "../../../modules/common"
import "../quickPanel"

// Bar: whether it is there, where it sits and how it looks, which modules it
// carries (every pill and key can be switched off), where each module sits on
// it, and how big the shell is. The package updates it shows are Ryoku's.
SettingsPage {
    id: page

    readonly property string screenName: page.host ? page.host.screenName : ""

    readonly property var modules: [
        { key: "bar.workspaces", icon: "grid_view", label: "Workspaces" },
        { key: "bar.activeWindow", icon: "web_asset", label: "Active window" },
        { key: "bar.media", icon: "music_note", label: "Media" },
        { key: "bar.weather", icon: "partly_cloudy_day", label: "Weather" },
        { key: "bar.date", icon: "calendar_month", label: "Date" },
        { key: "bar.clock", icon: "schedule", label: "Clock" },
        { key: "bar.resources", icon: "memory", label: "CPU & RAM" },
        { key: "bar.status", icon: "wifi", label: "Wi-Fi, Bluetooth & sound icons" },
        { key: "bar.battery", icon: "battery_android_full", label: "Battery" },
        { key: "bar.keyboardLayout", icon: "keyboard_alt", label: "Keyboard layout" },
        { key: "bar.notifications", icon: "notifications", label: "Notification bell" },
        { key: "bar.tray", icon: "apps", label: "Tray" },
        { key: "bar.utilButtons", icon: "construction", label: "Utility keys" },
        { key: "bar.privacy", icon: "shield_with_heart", label: "Privacy (mic / screen share)" },
        { key: "bar.updates", icon: "system_update_alt", label: "Package updates" }
    ]

    readonly property var utilKeys: [
        { key: "util.screenshot", icon: "screenshot_region", label: "Screenshot" },
        { key: "util.colorPicker", icon: "colorize", label: "Colour picker" },
        { key: "util.keyboard", icon: "keyboard", label: "Keyboard" },
        { key: "util.mic", icon: "mic", label: "Microphone" },
        { key: "util.darkMode", icon: "nightlight", label: "Night light" },
        { key: "util.profile", icon: "speed", label: "Performance" },
        { key: "util.record", icon: "screen_record", label: "Record" },
        { key: "util.wallpapers", icon: "wallpaper", label: "Wallpapers" }
    ]

    SectionCard {
        title: "Bar"

        SettingToggle {
            icon: "visibility"
            label: "Show bar"
            detail: SettingsService.flag("bar.visible") ? "ON" : "Hidden · gear in Quick Panel"
            checked: SettingsService.flag("bar.visible")
            onToggled: SettingsService.toggle("bar.visible")
        }

        SettingToggle {
            icon: "visibility_off"
            label: "Auto-hide"
            detail: SettingsService.flag("bar.autohide")
                ? "Slides away · hover the edge" : "Always on screen"
            checked: SettingsService.flag("bar.autohide")
            onToggled: SettingsService.toggle("bar.autohide")
        }

        SettingChoice {
            label: "Style"
            sublabel: "How the bar is drawn"
            current: BarStyleService.style
            options: [
                { id: "float", label: "Float", edge: "top", variant: "float" },
                { id: "straight", label: "Straight", edge: "top", variant: "straight" },
                { id: "transparent", label: "Transparent", edge: "top", variant: "transparent" },
                { id: "capsule", label: "Capsule", edge: "top", variant: "capsule" }
            ]
            onPicked: id => BarStyleService.setStyle(id)
        }

        SettingSlider {
            icon: "rounded_corner"
            label: "Corner radius"
            from: 0
            to: 100
            step: 1
            suffix: "%"
            value: SettingsService.get("bar.roundness", 100)
            onMoved: v => SettingsService.set("bar.roundness", Math.round(v))
        }

        SettingChoice {
            label: "Position"
            sublabel: "Which edge it sits on"
            current: BarPositionService.position
            options: [
                { id: "top", label: "Top", edge: "top" },
                { id: "right", label: "Right", edge: "right" },
                { id: "bottom", label: "Bottom", edge: "bottom" },
                { id: "left", label: "Left", edge: "left" }
            ]
            onPicked: id => BarPositionService.setPosition(id)
        }

        SettingToggle {
            icon: "monitor"
            label: "Separate bar per monitor"
            detail: BarLayoutService.perMonitor
                ? "Each monitor keeps its own modules and layout"
                : "The same bar on every monitor"
            checked: BarLayoutService.perMonitor
            onToggled: SettingsService.toggle("bar.perMonitor")
        }

        SettingAction {
            icon: "restart_alt"
            label: BarLayoutService.perMonitor ? "Reset this monitor's bar layout" : "Reset bar layout"
            detail: BarLayoutService.customizedFor(page.screenName) ? "Back to the default order" : "Already the default"
            onActivated: BarLayoutService.reset(page.screenName)
        }

        SettingToggle {
            icon: "close_fullscreen"
            label: "Small bar window"
            detail: "Shrink the window to the strip · less to composite"
            checked: SettingsService.flag("bar.compactWindow")
            onToggled: SettingsService.toggle("bar.compactWindow")
        }
    }

    SectionCard {
        title: "Modules"

        Repeater {
            model: page.modules

            delegate: SettingToggle {
                id: moduleToggle

                required property var modelData

                readonly property string moduleId: modelData.key.slice(4)

                icon: modelData.icon
                label: modelData.label
                checked: BarLayoutService.isOn(moduleToggle.moduleId, page.screenName)
                onToggled: BarLayoutService.setOff(moduleToggle.moduleId, moduleToggle.checked, page.screenName)
            }
        }

        SettingSlider {
            visible: SettingsService.flag("bar.workspaces")
            width: page.halfWidth
            icon: "grid_view"
            label: "Workspaces on the bar"
            from: 1
            to: 10
            step: 1
            value: SettingsService.get("bar.workspaceCount")
            onMoved: v => SettingsService.set("bar.workspaceCount", Math.round(v))
        }
    }

    SectionCard {
        title: "Layout"

        Repeater {
            model: BarLayoutService.modules

            delegate: SettingChoice {
                required property var modelData

                label: modelData.label
                labelWidth: 220
                current: BarLayoutService.zoneOf(modelData.id, page.screenName)
                options: [
                    { id: "left", label: "Left", icon: "align_horizontal_left" },
                    { id: "center", label: "Centre", icon: "align_horizontal_center" },
                    { id: "right", label: "Right", icon: "align_horizontal_right" }
                ]
                onPicked: id => BarLayoutService.moveTo(modelData.id, id, page.screenName)
            }
        }
    }

    SectionCard {
        title: "Updates"

        SettingToggle {
            icon: "exposure_zero"
            label: "Show 0 updates"
            detail: PackageUpdatesService.breakdown
            checked: SettingsService.flag("updates.showZero")
            onToggled: SettingsService.toggle("updates.showZero")
        }
    }

    SectionCard {
        title: "Media, tray & scrolling"

        SettingChoice {
            label: "Media pill click"
            sublabel: "Left click on the pill"
            current: SettingsService.get("media.leftClick")
            options: [
                { id: "panel", label: "Open panel", icon: "queue_music" },
                { id: "playpause", label: "Play / pause", icon: "play_pause" }
            ]
            onPicked: id => SettingsService.set("media.leftClick", id)
        }

        SettingToggle {
            icon: "swap_vert"
            label: "Scroll on tray icons"
            detail: "Sent to the app"
            checked: SettingsService.flag("tray.scroll")
            onToggled: SettingsService.toggle("tray.scroll")
        }

        SettingToggle {
            icon: "unfold_more"
            label: "Scroll hints"
            detail: "A marker where the wheel works"
            checked: SettingsService.flag("bar.scrollHints")
            onToggled: SettingsService.toggle("bar.scrollHints")
        }
    }

    SectionCard {
        title: "Utility keys"

        Repeater {
            model: page.utilKeys

            delegate: Item {
                id: keyCell
                required property var modelData

                width: 112
                height: 75 + 30

                QuickToggle {
                    kind: "round"
                    roundWidth: 74
                    flatShadow: Theme.quickFlat
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: keyCell.modelData.icon
                    on: SettingsService.flag(keyCell.modelData.key)
                    onClicked: SettingsService.toggle(keyCell.modelData.key)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 82
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: keyCell.modelData.label
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    SectionCard {
        title: "Size"

        SettingStepper {
            icon: "height"
            label: "Bar size"
            from: 0.7
            to: 1.3
            step: 0.05
            decimals: 2
            suffix: "×"
            value: ShellScale.barScale
            onMoved: v => ShellScale.setBarScale(v)
        }

        SettingAction {
            icon: "restart_alt"
            label: "Reset bar size"
            detail: "Back to 1.00×"
            onActivated: ShellScale.setBarScale(1)
        }

        SettingStepper {
            icon: "aspect_ratio"
            label: "Tansu size"
            from: 0.5
            to: 3
            step: 0.05
            decimals: 2
            suffix: "×"
            value: page.host ? ShellScale.effectiveFor(page.screenName) : 1
            onMoved: v => { if (page.host) ShellScale.setScale(page.screenName, v) }
        }

        SettingAction {
            icon: "restart_alt"
            label: "Reset Tansu size"
            detail: "Back to 1.00× on this monitor"
            onActivated: { if (page.host) ShellScale.resetScale(page.screenName) }
        }
    }
}