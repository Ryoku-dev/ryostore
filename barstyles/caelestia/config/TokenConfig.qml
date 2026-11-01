// Generated from caelestia-dots/shell b51fdb35ca7a14ac5a49e0d94fc5de2d79756aed. Do not edit.
pragma Singleton

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var _raw: root._parse(file.text())
    property bool _ready
    Component.onCompleted: _ready = true

    function _parse(text: string): var {
        try {
            const parsed = JSON.parse(text || "{}");
            if (parsed !== null && typeof parsed === "object" && !Array.isArray(parsed))
                return parsed;
        } catch (error) {
            console.warn("caelestia.config: invalid JSON, using defaults", error);
        }
        return {};
    }

    function _at(path): var {
        let value = root._raw;
        for (const key of path) {
            if (value === null || typeof value !== "object" || !(key in value))
                return undefined;
            value = value[key];
        }
        return value;
    }

    function _v(path, fallback): var {
        const value = root._at(path);
        if (value === undefined || value === null)
            return fallback;
        if (Array.isArray(fallback))
            return Array.isArray(value) ? value : fallback;
        if (typeof fallback === "object")
            return typeof value === "object" && !Array.isArray(value) ? value : fallback;
        return typeof value === typeof fallback ? value : fallback;
    }

    function _e(path, keys, fallback): int {
        const value = root._at(path);
        if (typeof value === "number")
            return value >= 0 && value < keys.length ? value : fallback;
        if (typeof value !== "string")
            return fallback;
        const index = keys.findIndex(key => key.toLowerCase() === value.toLowerCase());
        return index < 0 ? fallback : index;
    }

    function _std(location: int): string {
        return decodeURIComponent(StandardPaths.writableLocation(location).toString().replace(/^file:\/\//, ""));
    }

    function set(path, value): void {
        if (typeof path === "string")
            path = path.split(".");
        const raw = JSON.parse(JSON.stringify(root._raw));
        let node = raw;
        for (const key of path.slice(0, -1)) {
            if (node[key] === null || typeof node[key] !== "object" || Array.isArray(node[key]))
                node[key] = {};
            node = node[key];
        }
        node[path[path.length - 1]] = value;
        root._raw = raw;
        file.setText(JSON.stringify(raw, null, 4) + "\n");
    }

    function forScreen(screen: string): QtObject {
        return root;
    }

    FileView {
        id: file
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/ryoku/caelestia/shell-tokens.json`
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._raw = root._parse(text())
    }
    readonly property QtObject appearance: QtObject {
        readonly property QtObject curves: QtObject {
            property var emphasized: root._v(["appearance", "curves", "emphasized"], [0.05, 0, 0.13333333333333333, 0.06, 0.16666666666666666, 0.4, 0.20833333333333334, 0.82, 0.25, 1, 1, 1])
            onEmphasizedChanged: if (root._ready) root.set(["appearance", "curves", "emphasized"], emphasized)
            property var emphasizedAccel: root._v(["appearance", "curves", "emphasizedAccel"], [0.3, 0, 0.8, 0.15, 1, 1])
            onEmphasizedAccelChanged: if (root._ready) root.set(["appearance", "curves", "emphasizedAccel"], emphasizedAccel)
            property var emphasizedDecel: root._v(["appearance", "curves", "emphasizedDecel"], [0.05, 0.7, 0.1, 1, 1, 1])
            onEmphasizedDecelChanged: if (root._ready) root.set(["appearance", "curves", "emphasizedDecel"], emphasizedDecel)
            property var standard: root._v(["appearance", "curves", "standard"], [0.2, 0, 0, 1, 1, 1])
            onStandardChanged: if (root._ready) root.set(["appearance", "curves", "standard"], standard)
            property var standardAccel: root._v(["appearance", "curves", "standardAccel"], [0.3, 0, 1, 1, 1, 1])
            onStandardAccelChanged: if (root._ready) root.set(["appearance", "curves", "standardAccel"], standardAccel)
            property var standardDecel: root._v(["appearance", "curves", "standardDecel"], [0, 0, 0, 1, 1, 1])
            onStandardDecelChanged: if (root._ready) root.set(["appearance", "curves", "standardDecel"], standardDecel)
            property var expressiveFastSpatial: root._v(["appearance", "curves", "expressiveFastSpatial"], [0.42, 1.67, 0.21, 0.9, 1, 1])
            onExpressiveFastSpatialChanged: if (root._ready) root.set(["appearance", "curves", "expressiveFastSpatial"], expressiveFastSpatial)
            property var expressiveDefaultSpatial: root._v(["appearance", "curves", "expressiveDefaultSpatial"], [0.38, 1.21, 0.22, 1, 1, 1])
            onExpressiveDefaultSpatialChanged: if (root._ready) root.set(["appearance", "curves", "expressiveDefaultSpatial"], expressiveDefaultSpatial)
            property var expressiveSlowSpatial: root._v(["appearance", "curves", "expressiveSlowSpatial"], [0.39, 1.29, 0.35, 0.98, 1, 1])
            onExpressiveSlowSpatialChanged: if (root._ready) root.set(["appearance", "curves", "expressiveSlowSpatial"], expressiveSlowSpatial)
            property var expressiveFastEffects: root._v(["appearance", "curves", "expressiveFastEffects"], [0.31, 0.94, 0.34, 1, 1, 1])
            onExpressiveFastEffectsChanged: if (root._ready) root.set(["appearance", "curves", "expressiveFastEffects"], expressiveFastEffects)
            property var expressiveDefaultEffects: root._v(["appearance", "curves", "expressiveDefaultEffects"], [0.34, 0.8, 0.34, 1, 1, 1])
            onExpressiveDefaultEffectsChanged: if (root._ready) root.set(["appearance", "curves", "expressiveDefaultEffects"], expressiveDefaultEffects)
            property var expressiveSlowEffects: root._v(["appearance", "curves", "expressiveSlowEffects"], [0.34, 0.88, 0.34, 1, 1, 1])
            onExpressiveSlowEffectsChanged: if (root._ready) root.set(["appearance", "curves", "expressiveSlowEffects"], expressiveSlowEffects)
        }
        readonly property QtObject rounding: QtObject {
            property int extraSmall: root._v(["appearance", "rounding", "extraSmall"], 4)
            onExtraSmallChanged: if (root._ready) root.set(["appearance", "rounding", "extraSmall"], extraSmall)
            property int small: root._v(["appearance", "rounding", "small"], 8)
            onSmallChanged: if (root._ready) root.set(["appearance", "rounding", "small"], small)
            property int medium: root._v(["appearance", "rounding", "medium"], 12)
            onMediumChanged: if (root._ready) root.set(["appearance", "rounding", "medium"], medium)
            property int large: root._v(["appearance", "rounding", "large"], 16)
            onLargeChanged: if (root._ready) root.set(["appearance", "rounding", "large"], large)
            property int largeIncreased: root._v(["appearance", "rounding", "largeIncreased"], 20)
            onLargeIncreasedChanged: if (root._ready) root.set(["appearance", "rounding", "largeIncreased"], largeIncreased)
            property int extraLarge: root._v(["appearance", "rounding", "extraLarge"], 28)
            onExtraLargeChanged: if (root._ready) root.set(["appearance", "rounding", "extraLarge"], extraLarge)
            property int extraLargeIncreased: root._v(["appearance", "rounding", "extraLargeIncreased"], 32)
            onExtraLargeIncreasedChanged: if (root._ready) root.set(["appearance", "rounding", "extraLargeIncreased"], extraLargeIncreased)
            property int extraExtraLarge: root._v(["appearance", "rounding", "extraExtraLarge"], 48)
            onExtraExtraLargeChanged: if (root._ready) root.set(["appearance", "rounding", "extraExtraLarge"], extraExtraLarge)
            property int full: root._v(["appearance", "rounding", "full"], 2147483647)
            onFullChanged: if (root._ready) root.set(["appearance", "rounding", "full"], full)
        }
        readonly property QtObject spacing: QtObject {
            property int extraSmall: root._v(["appearance", "spacing", "extraSmall"], 4)
            onExtraSmallChanged: if (root._ready) root.set(["appearance", "spacing", "extraSmall"], extraSmall)
            property int small: root._v(["appearance", "spacing", "small"], 8)
            onSmallChanged: if (root._ready) root.set(["appearance", "spacing", "small"], small)
            property int medium: root._v(["appearance", "spacing", "medium"], 12)
            onMediumChanged: if (root._ready) root.set(["appearance", "spacing", "medium"], medium)
            property int large: root._v(["appearance", "spacing", "large"], 16)
            onLargeChanged: if (root._ready) root.set(["appearance", "spacing", "large"], large)
            property int largeIncreased: root._v(["appearance", "spacing", "largeIncreased"], 20)
            onLargeIncreasedChanged: if (root._ready) root.set(["appearance", "spacing", "largeIncreased"], largeIncreased)
            property int extraLarge: root._v(["appearance", "spacing", "extraLarge"], 28)
            onExtraLargeChanged: if (root._ready) root.set(["appearance", "spacing", "extraLarge"], extraLarge)
            property int extraLargeIncreased: root._v(["appearance", "spacing", "extraLargeIncreased"], 32)
            onExtraLargeIncreasedChanged: if (root._ready) root.set(["appearance", "spacing", "extraLargeIncreased"], extraLargeIncreased)
            property int extraExtraLarge: root._v(["appearance", "spacing", "extraExtraLarge"], 48)
            onExtraExtraLargeChanged: if (root._ready) root.set(["appearance", "spacing", "extraExtraLarge"], extraExtraLarge)
        }
        readonly property QtObject padding: QtObject {
            property int extraSmall: root._v(["appearance", "padding", "extraSmall"], 4)
            onExtraSmallChanged: if (root._ready) root.set(["appearance", "padding", "extraSmall"], extraSmall)
            property int small: root._v(["appearance", "padding", "small"], 8)
            onSmallChanged: if (root._ready) root.set(["appearance", "padding", "small"], small)
            property int medium: root._v(["appearance", "padding", "medium"], 12)
            onMediumChanged: if (root._ready) root.set(["appearance", "padding", "medium"], medium)
            property int large: root._v(["appearance", "padding", "large"], 16)
            onLargeChanged: if (root._ready) root.set(["appearance", "padding", "large"], large)
            property int largeIncreased: root._v(["appearance", "padding", "largeIncreased"], 20)
            onLargeIncreasedChanged: if (root._ready) root.set(["appearance", "padding", "largeIncreased"], largeIncreased)
            property int extraLarge: root._v(["appearance", "padding", "extraLarge"], 28)
            onExtraLargeChanged: if (root._ready) root.set(["appearance", "padding", "extraLarge"], extraLarge)
            property int extraLargeIncreased: root._v(["appearance", "padding", "extraLargeIncreased"], 32)
            onExtraLargeIncreasedChanged: if (root._ready) root.set(["appearance", "padding", "extraLargeIncreased"], extraLargeIncreased)
            property int extraExtraLarge: root._v(["appearance", "padding", "extraExtraLarge"], 48)
            onExtraExtraLargeChanged: if (root._ready) root.set(["appearance", "padding", "extraExtraLarge"], extraExtraLarge)
        }
        readonly property QtObject fontSize: QtObject {
            property int small: root._v(["appearance", "fontSize", "small"], 11)
            onSmallChanged: if (root._ready) root.set(["appearance", "fontSize", "small"], small)
            property int smaller: root._v(["appearance", "fontSize", "smaller"], 12)
            onSmallerChanged: if (root._ready) root.set(["appearance", "fontSize", "smaller"], smaller)
            property int normal: root._v(["appearance", "fontSize", "normal"], 13)
            onNormalChanged: if (root._ready) root.set(["appearance", "fontSize", "normal"], normal)
            property int larger: root._v(["appearance", "fontSize", "larger"], 15)
            onLargerChanged: if (root._ready) root.set(["appearance", "fontSize", "larger"], larger)
            property int large: root._v(["appearance", "fontSize", "large"], 18)
            onLargeChanged: if (root._ready) root.set(["appearance", "fontSize", "large"], large)
            property int extraLarge: root._v(["appearance", "fontSize", "extraLarge"], 28)
            onExtraLargeChanged: if (root._ready) root.set(["appearance", "fontSize", "extraLarge"], extraLarge)
        }
        readonly property QtObject animDurations: QtObject {
            property int small: root._v(["appearance", "animDurations", "small"], 200)
            onSmallChanged: if (root._ready) root.set(["appearance", "animDurations", "small"], small)
            property int normal: root._v(["appearance", "animDurations", "normal"], 400)
            onNormalChanged: if (root._ready) root.set(["appearance", "animDurations", "normal"], normal)
            property int large: root._v(["appearance", "animDurations", "large"], 600)
            onLargeChanged: if (root._ready) root.set(["appearance", "animDurations", "large"], large)
            property int extraLarge: root._v(["appearance", "animDurations", "extraLarge"], 1000)
            onExtraLargeChanged: if (root._ready) root.set(["appearance", "animDurations", "extraLarge"], extraLarge)
            property int expressiveFastSpatial: root._v(["appearance", "animDurations", "expressiveFastSpatial"], 350)
            onExpressiveFastSpatialChanged: if (root._ready) root.set(["appearance", "animDurations", "expressiveFastSpatial"], expressiveFastSpatial)
            property int expressiveDefaultSpatial: root._v(["appearance", "animDurations", "expressiveDefaultSpatial"], 500)
            onExpressiveDefaultSpatialChanged: if (root._ready) root.set(["appearance", "animDurations", "expressiveDefaultSpatial"], expressiveDefaultSpatial)
            property int expressiveSlowSpatial: root._v(["appearance", "animDurations", "expressiveSlowSpatial"], 650)
            onExpressiveSlowSpatialChanged: if (root._ready) root.set(["appearance", "animDurations", "expressiveSlowSpatial"], expressiveSlowSpatial)
            property int expressiveFastEffects: root._v(["appearance", "animDurations", "expressiveFastEffects"], 150)
            onExpressiveFastEffectsChanged: if (root._ready) root.set(["appearance", "animDurations", "expressiveFastEffects"], expressiveFastEffects)
            property int expressiveDefaultEffects: root._v(["appearance", "animDurations", "expressiveDefaultEffects"], 200)
            onExpressiveDefaultEffectsChanged: if (root._ready) root.set(["appearance", "animDurations", "expressiveDefaultEffects"], expressiveDefaultEffects)
            property int expressiveSlowEffects: root._v(["appearance", "animDurations", "expressiveSlowEffects"], 300)
            onExpressiveSlowEffectsChanged: if (root._ready) root.set(["appearance", "animDurations", "expressiveSlowEffects"], expressiveSlowEffects)
        }
    }
    readonly property QtObject sizes: QtObject {
        readonly property QtObject bar: QtObject {
            property int innerWidth: root._v(["sizes", "bar", "innerWidth"], 40)
            onInnerWidthChanged: if (root._ready) root.set(["sizes", "bar", "innerWidth"], innerWidth)
            property int windowPreviewSize: root._v(["sizes", "bar", "windowPreviewSize"], 400)
            onWindowPreviewSizeChanged: if (root._ready) root.set(["sizes", "bar", "windowPreviewSize"], windowPreviewSize)
            property int trayMenuWidth: root._v(["sizes", "bar", "trayMenuWidth"], 300)
            onTrayMenuWidthChanged: if (root._ready) root.set(["sizes", "bar", "trayMenuWidth"], trayMenuWidth)
            property int batteryWidth: root._v(["sizes", "bar", "batteryWidth"], 250)
            onBatteryWidthChanged: if (root._ready) root.set(["sizes", "bar", "batteryWidth"], batteryWidth)
            property int networkWidth: root._v(["sizes", "bar", "networkWidth"], 320)
            onNetworkWidthChanged: if (root._ready) root.set(["sizes", "bar", "networkWidth"], networkWidth)
            property int audioWidth: root._v(["sizes", "bar", "audioWidth"], 320)
            onAudioWidthChanged: if (root._ready) root.set(["sizes", "bar", "audioWidth"], audioWidth)
            property int kbLayoutWidth: root._v(["sizes", "bar", "kbLayoutWidth"], 320)
            onKbLayoutWidthChanged: if (root._ready) root.set(["sizes", "bar", "kbLayoutWidth"], kbLayoutWidth)
        }
        readonly property QtObject dashboard: QtObject {
            property int tabIndicatorHeight: root._v(["sizes", "dashboard", "tabIndicatorHeight"], 3)
            onTabIndicatorHeightChanged: if (root._ready) root.set(["sizes", "dashboard", "tabIndicatorHeight"], tabIndicatorHeight)
            property int tabIndicatorSpacing: root._v(["sizes", "dashboard", "tabIndicatorSpacing"], 5)
            onTabIndicatorSpacingChanged: if (root._ready) root.set(["sizes", "dashboard", "tabIndicatorSpacing"], tabIndicatorSpacing)
            property int userWidth: root._v(["sizes", "dashboard", "userWidth"], 340)
            onUserWidthChanged: if (root._ready) root.set(["sizes", "dashboard", "userWidth"], userWidth)
            property int logoSize: root._v(["sizes", "dashboard", "logoSize"], 30)
            onLogoSizeChanged: if (root._ready) root.set(["sizes", "dashboard", "logoSize"], logoSize)
            property int uptimeSize: root._v(["sizes", "dashboard", "uptimeSize"], 30)
            onUptimeSizeChanged: if (root._ready) root.set(["sizes", "dashboard", "uptimeSize"], uptimeSize)
            property int dateTimeWidth: root._v(["sizes", "dashboard", "dateTimeWidth"], 110)
            onDateTimeWidthChanged: if (root._ready) root.set(["sizes", "dashboard", "dateTimeWidth"], dateTimeWidth)
            property int mediaWidth: root._v(["sizes", "dashboard", "mediaWidth"], 200)
            onMediaWidthChanged: if (root._ready) root.set(["sizes", "dashboard", "mediaWidth"], mediaWidth)
            property int mediaProgressSweep: root._v(["sizes", "dashboard", "mediaProgressSweep"], 180)
            onMediaProgressSweepChanged: if (root._ready) root.set(["sizes", "dashboard", "mediaProgressSweep"], mediaProgressSweep)
            property int mediaProgressThickness: root._v(["sizes", "dashboard", "mediaProgressThickness"], 6)
            onMediaProgressThicknessChanged: if (root._ready) root.set(["sizes", "dashboard", "mediaProgressThickness"], mediaProgressThickness)
            property int resourceProgressThickness: root._v(["sizes", "dashboard", "resourceProgressThickness"], 6)
            onResourceProgressThicknessChanged: if (root._ready) root.set(["sizes", "dashboard", "resourceProgressThickness"], resourceProgressThickness)
            property int weatherWidth: root._v(["sizes", "dashboard", "weatherWidth"], 275)
            onWeatherWidthChanged: if (root._ready) root.set(["sizes", "dashboard", "weatherWidth"], weatherWidth)
            property int mediaCoverArtSize: root._v(["sizes", "dashboard", "mediaCoverArtSize"], 200)
            onMediaCoverArtSizeChanged: if (root._ready) root.set(["sizes", "dashboard", "mediaCoverArtSize"], mediaCoverArtSize)
            property int mediaTabWidth: root._v(["sizes", "dashboard", "mediaTabWidth"], 1000)
            onMediaTabWidthChanged: if (root._ready) root.set(["sizes", "dashboard", "mediaTabWidth"], mediaTabWidth)
            property int mediaTabHeight: root._v(["sizes", "dashboard", "mediaTabHeight"], 320)
            onMediaTabHeightChanged: if (root._ready) root.set(["sizes", "dashboard", "mediaTabHeight"], mediaTabHeight)
            property int mediaSectionWidth: root._v(["sizes", "dashboard", "mediaSectionWidth"], 300)
            onMediaSectionWidthChanged: if (root._ready) root.set(["sizes", "dashboard", "mediaSectionWidth"], mediaSectionWidth)
            property int perfHeroCardWidth: root._v(["sizes", "dashboard", "perfHeroCardWidth"], 400)
            onPerfHeroCardWidthChanged: if (root._ready) root.set(["sizes", "dashboard", "perfHeroCardWidth"], perfHeroCardWidth)
            property int perfUsageShapeSize: root._v(["sizes", "dashboard", "perfUsageShapeSize"], 100)
            onPerfUsageShapeSizeChanged: if (root._ready) root.set(["sizes", "dashboard", "perfUsageShapeSize"], perfUsageShapeSize)
            property int perfStorageTextWidth: root._v(["sizes", "dashboard", "perfStorageTextWidth"], 160)
            onPerfStorageTextWidthChanged: if (root._ready) root.set(["sizes", "dashboard", "perfStorageTextWidth"], perfStorageTextWidth)
            property int perfNetworkCardWidth: root._v(["sizes", "dashboard", "perfNetworkCardWidth"], 390)
            onPerfNetworkCardWidthChanged: if (root._ready) root.set(["sizes", "dashboard", "perfNetworkCardWidth"], perfNetworkCardWidth)
            property int perfNetworkCardHeight: root._v(["sizes", "dashboard", "perfNetworkCardHeight"], 220)
            onPerfNetworkCardHeightChanged: if (root._ready) root.set(["sizes", "dashboard", "perfNetworkCardHeight"], perfNetworkCardHeight)
            property int perfBattWidth: root._v(["sizes", "dashboard", "perfBattWidth"], 150)
            onPerfBattWidthChanged: if (root._ready) root.set(["sizes", "dashboard", "perfBattWidth"], perfBattWidth)
            property int perfBattWidthSingle: root._v(["sizes", "dashboard", "perfBattWidthSingle"], 400)
            onPerfBattWidthSingleChanged: if (root._ready) root.set(["sizes", "dashboard", "perfBattWidthSingle"], perfBattWidthSingle)
            property int perfBattHeight: root._v(["sizes", "dashboard", "perfBattHeight"], 160)
            onPerfBattHeightChanged: if (root._ready) root.set(["sizes", "dashboard", "perfBattHeight"], perfBattHeight)
            property int perfPlaceholderWidth: root._v(["sizes", "dashboard", "perfPlaceholderWidth"], 700)
            onPerfPlaceholderWidthChanged: if (root._ready) root.set(["sizes", "dashboard", "perfPlaceholderWidth"], perfPlaceholderWidth)
        }
        readonly property QtObject launcher: QtObject {
            property int itemWidth: root._v(["sizes", "launcher", "itemWidth"], 600)
            onItemWidthChanged: if (root._ready) root.set(["sizes", "launcher", "itemWidth"], itemWidth)
            property int itemHeight: root._v(["sizes", "launcher", "itemHeight"], 57)
            onItemHeightChanged: if (root._ready) root.set(["sizes", "launcher", "itemHeight"], itemHeight)
            property int wallpaperWidth: root._v(["sizes", "launcher", "wallpaperWidth"], 280)
            onWallpaperWidthChanged: if (root._ready) root.set(["sizes", "launcher", "wallpaperWidth"], wallpaperWidth)
            property int wallpaperHeight: root._v(["sizes", "launcher", "wallpaperHeight"], 200)
            onWallpaperHeightChanged: if (root._ready) root.set(["sizes", "launcher", "wallpaperHeight"], wallpaperHeight)
        }
        readonly property QtObject notifs: QtObject {
            property int width: root._v(["sizes", "notifs", "width"], 430)
            onWidthChanged: if (root._ready) root.set(["sizes", "notifs", "width"], width)
            property int image: root._v(["sizes", "notifs", "image"], 42)
            onImageChanged: if (root._ready) root.set(["sizes", "notifs", "image"], image)
            property int badge: root._v(["sizes", "notifs", "badge"], 20)
            onBadgeChanged: if (root._ready) root.set(["sizes", "notifs", "badge"], badge)
        }
        readonly property QtObject osd: QtObject {
            property int sliderWidth: root._v(["sizes", "osd", "sliderWidth"], 30)
            onSliderWidthChanged: if (root._ready) root.set(["sizes", "osd", "sliderWidth"], sliderWidth)
            property int sliderHeight: root._v(["sizes", "osd", "sliderHeight"], 150)
            onSliderHeightChanged: if (root._ready) root.set(["sizes", "osd", "sliderHeight"], sliderHeight)
        }
        readonly property QtObject session: QtObject {
            property int button: root._v(["sizes", "session", "button"], 80)
            onButtonChanged: if (root._ready) root.set(["sizes", "session", "button"], button)
        }
        readonly property QtObject sidebar: QtObject {
            property int width: root._v(["sizes", "sidebar", "width"], 430)
            onWidthChanged: if (root._ready) root.set(["sizes", "sidebar", "width"], width)
        }
        readonly property QtObject utilities: QtObject {
            property int width: root._v(["sizes", "utilities", "width"], 430)
            onWidthChanged: if (root._ready) root.set(["sizes", "utilities", "width"], width)
            property int toastWidth: root._v(["sizes", "utilities", "toastWidth"], 430)
            onToastWidthChanged: if (root._ready) root.set(["sizes", "utilities", "toastWidth"], toastWidth)
        }
        readonly property QtObject lock: QtObject {
            property real heightMult: root._v(["sizes", "lock", "heightMult"], 0.7)
            onHeightMultChanged: if (root._ready) root.set(["sizes", "lock", "heightMult"], heightMult)
            property real ratio: root._v(["sizes", "lock", "ratio"], 1.7777777777777777)
            onRatioChanged: if (root._ready) root.set(["sizes", "lock", "ratio"], ratio)
            property int centerWidth: root._v(["sizes", "lock", "centerWidth"], 600)
            onCenterWidthChanged: if (root._ready) root.set(["sizes", "lock", "centerWidth"], centerWidth)
            property int showWeatherDetailsHeight: root._v(["sizes", "lock", "showWeatherDetailsHeight"], 550)
            onShowWeatherDetailsHeightChanged: if (root._ready) root.set(["sizes", "lock", "showWeatherDetailsHeight"], showWeatherDetailsHeight)
            property int showForecastHeight: root._v(["sizes", "lock", "showForecastHeight"], 975)
            onShowForecastHeightChanged: if (root._ready) root.set(["sizes", "lock", "showForecastHeight"], showForecastHeight)
            property int forecastItemWidth: root._v(["sizes", "lock", "forecastItemWidth"], 51)
            onForecastItemWidthChanged: if (root._ready) root.set(["sizes", "lock", "forecastItemWidth"], forecastItemWidth)
            property int largeLogoWidth: root._v(["sizes", "lock", "largeLogoWidth"], 320)
            onLargeLogoWidthChanged: if (root._ready) root.set(["sizes", "lock", "largeLogoWidth"], largeLogoWidth)
            property int largeFontWidth: root._v(["sizes", "lock", "largeFontWidth"], 400)
            onLargeFontWidthChanged: if (root._ready) root.set(["sizes", "lock", "largeFontWidth"], largeFontWidth)
            property int fetch4LinesHeight: root._v(["sizes", "lock", "fetch4LinesHeight"], 600)
            onFetch4LinesHeightChanged: if (root._ready) root.set(["sizes", "lock", "fetch4LinesHeight"], fetch4LinesHeight)
            property int fetch3LinesHeight: root._v(["sizes", "lock", "fetch3LinesHeight"], 500)
            onFetch3LinesHeightChanged: if (root._ready) root.set(["sizes", "lock", "fetch3LinesHeight"], fetch3LinesHeight)
            property int showColourBoxRowHeight: root._v(["sizes", "lock", "showColourBoxRowHeight"], 570)
            onShowColourBoxRowHeightChanged: if (root._ready) root.set(["sizes", "lock", "showColourBoxRowHeight"], showColourBoxRowHeight)
        }
        readonly property QtObject winfo: QtObject {
            property real heightMult: root._v(["sizes", "winfo", "heightMult"], 0.7)
            onHeightMultChanged: if (root._ready) root.set(["sizes", "winfo", "heightMult"], heightMult)
            property real detailsWidth: root._v(["sizes", "winfo", "detailsWidth"], 500)
            onDetailsWidthChanged: if (root._ready) root.set(["sizes", "winfo", "detailsWidth"], detailsWidth)
        }
        readonly property QtObject nexus: QtObject {
            property real heightMult: root._v(["sizes", "nexus", "heightMult"], 0.7)
            onHeightMultChanged: if (root._ready) root.set(["sizes", "nexus", "heightMult"], heightMult)
            property real ratio: root._v(["sizes", "nexus", "ratio"], 1.7777777777777777)
            onRatioChanged: if (root._ready) root.set(["sizes", "nexus", "ratio"], ratio)
            property int minWidth: root._v(["sizes", "nexus", "minWidth"], 800)
            onMinWidthChanged: if (root._ready) root.set(["sizes", "nexus", "minWidth"], minWidth)
            property int minHeight: root._v(["sizes", "nexus", "minHeight"], 500)
            onMinHeightChanged: if (root._ready) root.set(["sizes", "nexus", "minHeight"], minHeight)
            property int maxNavWidth: root._v(["sizes", "nexus", "maxNavWidth"], 600)
            onMaxNavWidthChanged: if (root._ready) root.set(["sizes", "nexus", "maxNavWidth"], maxNavWidth)
            property int maxContentWidth: root._v(["sizes", "nexus", "maxContentWidth"], 800)
            onMaxContentWidthChanged: if (root._ready) root.set(["sizes", "nexus", "maxContentWidth"], maxContentWidth)
            property int popupWidth: root._v(["sizes", "nexus", "popupWidth"], 300)
            onPopupWidthChanged: if (root._ready) root.set(["sizes", "nexus", "popupWidth"], popupWidth)
            property int minPopupHeight: root._v(["sizes", "nexus", "minPopupHeight"], 200)
            onMinPopupHeightChanged: if (root._ready) root.set(["sizes", "nexus", "minPopupHeight"], minPopupHeight)
            property int maxPopupHeight: root._v(["sizes", "nexus", "maxPopupHeight"], 800)
            onMaxPopupHeightChanged: if (root._ready) root.set(["sizes", "nexus", "maxPopupHeight"], maxPopupHeight)
            property int networkShowEthDetailWidth: root._v(["sizes", "nexus", "networkShowEthDetailWidth"], 620)
            onNetworkShowEthDetailWidthChanged: if (root._ready) root.set(["sizes", "nexus", "networkShowEthDetailWidth"], networkShowEthDetailWidth)
            property int networkShowVpnDetailWidth: root._v(["sizes", "nexus", "networkShowVpnDetailWidth"], 620)
            onNetworkShowVpnDetailWidthChanged: if (root._ready) root.set(["sizes", "nexus", "networkShowVpnDetailWidth"], networkShowVpnDetailWidth)
            property int maxDialogWidth: root._v(["sizes", "nexus", "maxDialogWidth"], 400)
            onMaxDialogWidthChanged: if (root._ready) root.set(["sizes", "nexus", "maxDialogWidth"], maxDialogWidth)
            property int maxDialogHeight: root._v(["sizes", "nexus", "maxDialogHeight"], 600)
            onMaxDialogHeightChanged: if (root._ready) root.set(["sizes", "nexus", "maxDialogHeight"], maxDialogHeight)
            property int textFieldWidth: root._v(["sizes", "nexus", "textFieldWidth"], 250)
            onTextFieldWidthChanged: if (root._ready) root.set(["sizes", "nexus", "textFieldWidth"], textFieldWidth)
            property int smallTextFieldWidth: root._v(["sizes", "nexus", "smallTextFieldWidth"], 100)
            onSmallTextFieldWidthChanged: if (root._ready) root.set(["sizes", "nexus", "smallTextFieldWidth"], smallTextFieldWidth)
        }
    }
}
