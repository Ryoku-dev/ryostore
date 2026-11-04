pragma Singleton
import QtQuick
import Quickshell

/**
 * Single source of truth for the settings window's pages.
 *
 * Pages are addressed by stable string `id` — never by array index.
 * `name` holds the untranslated string key; display code (SettingsWindow,
 * Sidebar) applies Translation.tr so language switches stay reactive.
 *
 * Fields per page:
 *  - id:         stable identifier used by deep links and navigation helpers
 *  - name:       untranslated display name key
 *  - icon:       Material Symbol name
 *  - component:  page file, relative to the barstyle root
 *  - subPages:   widget config files opened from this page, relative to
 *                modules/settings/configs/ (used for search indexing)
 *  - aliases:    extra untranslated search terms (old page names etc.)
 *  - hidden:     not shown in the sidebar, excluded from keyboard cycling.
 *                Hidden pages must stay at the END of the list.
 *  - families:   panel families this page applies to. Absent means every family.
 *                A restricted family (tablet) does not render some surfaces at all,
 *                and a settings page for a surface that cannot exist is worse than
 *                no page: every switch on it is inert. Filtering happens in the
 *                sidebar and in keyboard cycling; the flat `pages` array keeps every
 *                entry so page indices stay stable across families.
 *  - searchable: set false to skip the file during search indexing
 *
 * Only the pages shipped with this barstyle are listed here; the settings
 * surfaces the shell already owns (wallpaper, dock, workspaces, overview,
 * widgets, dynamic island, launcher, hyprland, network, ...) have no files
 * here.
 */
Singleton {
    // Group 1 – Look & Feel
    // Group 2 – Modules
    // Group 3 – Tools
    // Group 4 – Services & Integrations
    // Group 5 – System
    // Hidden pages — keep at the end of the list

    id: root

    readonly property var pages: [
        // "colors" removed: palette, dark-mode scheduling, wallpaper theming and
        // app theming are the shell's (matugen, ryogami, Nightlight).
        {
            "id": "bar",
            "name": "Bar",
            "icon": "space_bar",
            "component": "modules/settings/configs/BarConfig.qml",
            "aliases": ["Bar & Status Bar", "Status Bar", "Shell mode", "Waffle", "Bar appearance", "Bar layout", "Bar style", "Brand icon", "Bar popups", "Floating popups", "Click bar to open sidebars"]
        },
        {
            "id": "sidebars",
            "name": "Sidebars",
            "icon": "side_navigation",
            "component": "modules/settings/configs/SidebarsConfig.qml",
            "aliases": ["Sidebars & Panels", "Panels"]
        },
        {
            "id": "overlays",
            "name": "Overlays & OSD",
            "icon": "picture_in_picture",
            "component": "modules/settings/configs/OverlaysConfig.qml",
            "subPages": [
                "widgets/GameOverlayConfig.qml",
                "widgets/OnScreenKeyboardConfig.qml",
                "widgets/OsdIndicatorsConfig.qml"
            ],
            "aliases": ["System Overlays", "Media overlay", "Game overlay", "Performance HUD", "FPS counter", "MangoHud", "RivaTuner"]
        },
        {
            "id": "notifications",
            "name": "Notifications",
            "icon": "notifications",
            "component": "modules/settings/configs/NotificationsConfig.qml",
            "subPages": [],
            "aliases": []
        },
        {
            "id": "languageTime",
            "name": "Language & Time",
            "icon": "translate",
            "component": "modules/settings/configs/LanguageTimeConfig.qml",
            "subPages": ["widgets/TimeDateFormatsConfig.qml"],
            "aliases": ["Core Services", "Language & Translation", "Time & Date", "World Clocks", "Alarms", "Translator", "Date format", "Clock format", "Custom format strings"]
        },
        {
            "id": "weather",
            "name": "Weather",
            "icon": "cloud",
            "component": "modules/settings/configs/WeatherConfig.qml",
            "subPages": [],
            "aliases": ["Core Services", "Weather Service"]
        },
        {
            "id": "soundAlerts",
            "name": "Sound & Alerts",
            "icon": "volume_up",
            "component": "modules/settings/configs/SoundAlertsConfig.qml",
            "subPages": ["widgets/SoundEventsConfig.qml", "widgets/CustomSoundsConfig.qml", "widgets/AlarmAudioConfig.qml", "widgets/AudioProtectionConfig.qml"],
            "aliases": ["Core Services", "Audio Controls", "Earbang protection", "Interactive Alerts", "Battery sound", "Pomodoro sound"]
        },
        {
            "id": "power",
            "name": "Power & Battery",
            "icon": "battery_android_full",
            "component": "modules/settings/configs/PowerConfig.qml",
            "subPages": [],
            "aliases": ["Core Services", "Suspend", "Battery warning", "Automatic suspend",
                "Charge limit", "Charge threshold", "Battery full notification", "Battery health"]
        },
        {
            "id": "about",
            "name": "About & Updates",
            "icon": "info",
            "component": "modules/settings/configs/AboutConfig.qml",
            "aliases": []
        },
        {
            "id": "profile",
            "name": "User Profile",
            "icon": "account_circle",
            "component": "modules/settings/configs/UserProfileConfig.qml",
            "subPages": ["widgets/BannerImageConfig.qml"],
            "aliases": ["Profile", "Avatar Appearance", "Sidebar header", "Right Sidebar Banner"],
            "hidden": true
        }
    ]
    /// Whether a page applies to the running panel family. Pages without a `families`
    /// field apply everywhere, which is the overwhelming majority.
    function availableForFamily(page, family) {
        if (!page || !page.families)
            return true;
        return page.families.indexOf(family ?? "ii") !== -1;
    }

    readonly property var groups: [
        {
            "id": "lookAndFeel",
            "name": "Look & Feel",
            "pageIds": ["bar"]
        },
        {
            "id": "modules",
            "name": "Modules",
            "pageIds": ["sidebars"]
        },
        {
            "id": "tools",
            "name": "Tools",
            "pageIds": ["notifications", "overlays"]
        },
        {
            "id": "servicesIntegrations",
            "name": "Services & Integrations",
            "pageIds": ["languageTime", "weather"]
        },
        {
            "id": "system",
            "name": "System",
            "pageIds": ["soundAlerts", "power", "about"]
        }
    ]

    function pageIndexById(id) {
        for (let i = 0; i < pages.length; i++) {
            if (pages[i].id === id)
                return i;
        }
        return -1;
    }

    function pageById(id) {
        const i = pageIndexById(id);
        return i >= 0 ? pages[i] : null;
    }
}
