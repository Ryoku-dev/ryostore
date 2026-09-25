pragma ComponentBehavior: Bound
import QtQuick
import "."

// Base frame for a ported desktop widget tile: what AbstractBackgroundWidget
// gave the illogical-impulse widgets (colour resolution, wallpaper reference,
// screen size) minus the placement engine, which Ryoku's desktop host owns.
Item {
    id: root

    // Pushed by the adapter from the host.
    property var pluginApi: null
    property var screen: null
    property bool active: true
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0

    // True while the tile shows a focused text field; the adapter re-exports
    // it as `editing` so the desktop host grabs the keyboard layer for it.
    property bool _kb: false

    // Per-widget config block: the widget declares its illogical-impulse
    // entry name; the adapter's Config exposes exactly that entry.
    property string configEntryName: ""
    readonly property var configEntry: Config.options.background.widgets[configEntryName]

    readonly property int screenWidth: screen ? screen.width : 1920
    readonly property int screenHeight: screen ? screen.height : 1080

    // Text colour over the wallpaper, the upstream rule: the palette primary
    // tuned for contrast when the tile floats on the desktop, the layer ink
    // when locked with blur.
    property color dominantColor: Appearance.colors.colPrimary
    readonly property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
    property color colText: {
        const onNormalBackground = GlobalStates.screenLocked && Config.options.lock.blur.enable;
        return onNormalBackground
            ? Appearance.colors.colOnLayer0
            : ColorUtils.colorWithLightness(Appearance.colors.colPrimary,
                (dominantColorIsDark ? 0.8 : 0.12));
    }

    readonly property bool wallpaperIsVideo: {
        const p = Config.options.background.wallpaperPath;
        return p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv")
            || p.endsWith(".avi") || p.endsWith(".mov");
    }
    readonly property string wallpaperPath: wallpaperIsVideo
        ? Config.options.background.thumbnailPath
        : Config.options.background.wallpaperPath

    // Placement vocabulary the widget bodies read: they stay draggable-looking
    // but Ryoku owns movement, so these are inert defaults.
    readonly property string placementStrategy: "free"
    property bool draggable: false
    property bool containsPress: false
    property bool containsMouse: false
    property bool hoverEnabled: false
    property bool needsColText: false
    property Item wallpaperItem: null

    // Placement vocabulary the widget bodies bind; inert under Ryoku.
    property bool visibleWhenLocked: true
    property real targetX: 0
    property real targetY: 0
    property real targetZ: 0
    function requestDelete() {}
    function commitPosition() {}
    function restoreXYBinding() {}
}
