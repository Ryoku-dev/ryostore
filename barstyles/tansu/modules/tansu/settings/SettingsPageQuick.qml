import QtQuick
import "../../../services"

SettingsPage {
    id: page

    readonly property var src: host ? host.source : null

    SectionCard {
        title: "Quick Panel"

        SettingChoice {
            label: "Phone"
            sublabel: "Tilted 2.5D, or flat 2D"
            current: SettingsService.flag("quick.flat") ? "flat" : "tilted"
            options: [
                { id: "tilted", label: "2.5D", icon: "view_in_ar" },
                { id: "flat", label: "2D", icon: "crop_portrait" }
            ]
            onPicked: id => SettingsService.set("quick.flat", id === "flat")
        }

        SettingToggle {
            icon: "blur_on"
            label: "Phone shadow"
            detail: "A soft shadow under the phone (Quick Panel, Settings, Wallpapers)"
            checked: SettingsService.flag("quick.phoneShadow")
            onToggled: SettingsService.toggle("quick.phoneShadow")
        }

        SettingToggle {
            icon: "music_note"
            label: "Now playing"
            detail: "A media card on the phone while something is playing"
            checked: SettingsService.flag("quick.media")
            onToggled: SettingsService.toggle("quick.media")
        }

        SettingSlider {
            icon: "photo_size_select_large"
            label: "Pinned size"
            from: 30
            to: 90
            step: 1
            suffix: "%"
            value: SettingsService.get("quick.pinScale", 58)
            onMoved: v => SettingsService.set("quick.pinScale", Math.round(v))
        }

        SettingSlider {
            icon: "opacity"
            label: "Pinned opacity"
            from: 30
            to: 100
            step: 5
            suffix: "%"
            value: SettingsService.get("quick.pinOpacity", 100)
            onMoved: v => SettingsService.set("quick.pinOpacity", Math.round(v))
        }
    }

    SectionCard {
        title: "Shell"

        SettingToggle {
            icon: page.src && page.src.notificationsOn ? "notifications_active" : "notifications_off"
            label: "Notifications"
            checked: page.src ? page.src.notificationsOn : true
            onToggled: if (page.src) page.src.toggleNotifications()
        }

        SettingToggle {
            icon: "nightlight"
            label: "Night Light"
            checked: page.src ? page.src.nightLightOn : false
            onToggled: if (page.src) page.src.toggleNightLight()
        }

        SettingToggle {
            icon: "coffee"
            label: "Keep Awake"
            checked: page.src ? page.src.keepAwakeOn : false
            onToggled: if (page.src) page.src.toggleKeepAwake()
        }

        SettingToggle {
            icon: "dock_to_bottom"
            label: "Bar"
            checked: SettingsService.flag("bar.visible")
            onToggled: SettingsService.toggle("bar.visible")
        }

        SettingAction {
            icon: "wallpaper"
            label: "Wallpapers"
            detail: "Open the picker"
            onActivated: if (page.host) page.host.wallpapersRequested()
        }
    }
}
