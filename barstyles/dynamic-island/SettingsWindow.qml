pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

// iPadOS-style Settings app. Every change is live and saved to settings.json.
FloatingWindow {
    id: win
    title: "Island Settings"
    implicitWidth: 900
    implicitHeight: 640
    color: Theme.window
    visible: true
    onVisibleChanged: if (!visible) Hub.settingsOpen = false

    property int page: 0
    readonly property var pages: [
        { title: "Appearance",    icon: "palette",            tint: Theme.blue },
        { title: "Island",        icon: "smart_button",       tint: "#1c1c1e" },
        { title: "Notifications", icon: "notifications",      tint: Theme.red },
        { title: "Focus",         icon: "bedtime",            tint: Theme.indigo },
        { title: "Media",         icon: "music_note",         tint: Theme.pink },
        { title: "Weather",       icon: "partly_cloudy_day",  tint: Theme.teal },
        { title: "Controls",      icon: "tune",               tint: Theme.gray },
        { title: "Shortcuts",     icon: "keyboard",           tint: Theme.gray },
        { title: "About",         icon: "info",               tint: Theme.gray }
    ]

    Shortcut { sequences: ["Ctrl+W", "Escape"]; onActivated: Hub.settingsOpen = false }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: win.page = (win.page + 1) % win.pages.length }

    // ═══════════════════════ ROW TOOLKIT ═══════════════════════
    component IconTile: Rectangle {
        id: it
        property string icon: ""
        property color tint: Theme.blue
        width: 29; height: 29; radius: 7
        color: tint
        Icon { anchors.centerIn: parent; text: it.icon; size: 18; fill: 1; color: "#ffffff" }
    }

    component Section: Column {
        id: sec
        property string title: ""
        property string footer: ""
        default property alias rows: box.data
        width: parent ? parent.width : 0
        spacing: 6
        Txt {
            visible: sec.title !== ""
            leftPadding: 16
            text: sec.title.toUpperCase()
            size: 11.5
            weight: Font.Medium
            color: Theme.fg2
        }
        Rectangle {
            width: parent.width
            height: box.implicitHeight
            radius: 12
            color: Theme.group
            clip: true
            Column { id: box; width: parent.width }
        }
        Txt {
            visible: sec.footer !== ""
            width: parent.width
            leftPadding: 16
            rightPadding: 16
            text: sec.footer
            size: 11.5
            color: Theme.fg2
            wrapMode: Text.Wrap
        }
        Item { width: 1; height: 16 }
    }

    component Row_: Item {
        id: rw
        property string label: ""
        property string sub: ""
        property string icon: ""
        property color iconTint: Theme.blue
        default property alias trailing: tr.data
        property real minHeight: 46
        width: parent ? parent.width : 0
        implicitHeight: Math.max(minHeight, lbl.implicitHeight + 20)
        Rectangle {
            visible: rw.parent && rw.parent.children[0] !== rw
            x: rw.icon !== "" ? 58 : 16
            width: parent.width - x
            height: 0.5
            color: Theme.sep
        }
        IconTile {
            id: ic
            visible: rw.icon !== ""
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            icon: rw.icon
            tint: rw.iconTint
        }
        Column {
            id: lbl
            x: rw.icon !== "" ? 58 : 16
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - tr.width - 28
            Txt { width: parent.width; text: rw.label; size: 14; weight: Font.Normal }
            Txt { visible: rw.sub !== ""; width: parent.width; text: rw.sub; size: 11.5; color: Theme.fg2; wrapMode: Text.Wrap }
        }
        Row {
            id: tr
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }

    component SwitchRow: Row_ {
        id: sr
        property string key: ""
        property bool checked: key !== "" ? !!Config.s[sr.key] : false
        signal toggled(bool value)
        IosSwitch {
            checked: sr.checked
            onToggled: v => {
                if (sr.key !== "")
                    Config.s[sr.key] = v;
                sr.toggled(v);
            }
        }
    }

    component SegRow: Row_ {
        id: sg
        property string key: ""
        property var options: []     // [{label, value}]
        property real segWidth: 260
        Segmented {
            width: sg.segWidth
            model: sg.options.map(o => o.label)
            currentIndex: Math.max(0, sg.options.findIndex(o => o.value === Config.s[sg.key]))
            onActivated: i => Config.s[sg.key] = sg.options[i].value
        }
    }

    component SliderRow: Row_ {
        id: sl
        property string key: ""
        property real from: 0
        property real to: 1
        property real step: 0
        property var fmt: v => String(v)
        SliderBar {
            width: 220
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
            value: (Config.s[sl.key] - sl.from) / (sl.to - sl.from)
            onMoved: v => {
                let x = sl.from + v * (sl.to - sl.from);
                if (sl.step > 0) x = Math.round(x / sl.step) * sl.step;
                Config.s[sl.key] = x;
            }
        }
        Txt {
            width: 56
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: sl.fmt(Config.s[sl.key])
            size: 13
            color: Theme.fg2
        }
    }

    component TextRow: Row_ {
        id: tx
        property string key: ""
        property string placeholder: ""
        TextField {
            width: 280
            implicitHeight: 30
            leftPadding: 10
            rightPadding: 10
            text: Config.s[tx.key]
            placeholderText: tx.placeholder
            placeholderTextColor: Theme.fg3
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 13
            horizontalAlignment: Text.AlignRight
            selectionColor: Theme.accent
            background: Rectangle { radius: 8; color: Theme.fill; border.width: parent.activeFocus ? 1 : 0; border.color: Theme.accent }
            onEditingFinished: Config.s[tx.key] = text
        }
    }

    component ValueRow: Row_ {
        id: vr
        property string value: ""
        property color valueColor: Theme.fg2
        Txt { text: vr.value; size: 13.5; color: vr.valueColor; anchors.verticalCenter: parent.verticalCenter }
    }

    component CheckRow: Row_ {
        id: cr
        property string key: ""
        property string value: ""
        readonly property bool sel: Config.s[key] === value
        Icon { visible: cr.sel; text: "check"; size: 20; weight: 700; color: Theme.accent }
        MouseArea {
            parent: cr
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Config.s[cr.key] = cr.value
        }
    }

    component ButtonRow: Row_ {
        id: br
        property string text: ""
        property color textColor: Theme.accent
        signal clicked()
        Item { width: 1; height: 1 }
        Txt {
            parent: br
            x: br.icon !== "" ? 58 : 16
            anchors.verticalCenter: parent.verticalCenter
            text: br.text
            size: 14
            color: br.textColor
        }
        MouseArea {
            parent: br
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: br.clicked()
        }
    }

    // ═══════════════════════ LAYOUT ═══════════════════════
    // Sidebar
    Rectangle {
        id: sidebar
        width: 250
        height: parent.height
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.03) : Qt.rgba(0, 0, 0, 0.025)
        Rectangle { anchors.right: parent.right; width: 0.5; height: parent.height; color: Theme.sep }

        Column {
            x: 14; y: 22
            width: parent.width - 28
            spacing: 2
            Txt { leftPadding: 6; text: "Settings"; size: 30; weight: Font.Bold }
            Item { width: 1; height: 10 }

            // profile-style header card
            Rectangle {
                width: parent.width
                height: 64
                radius: 12
                color: Theme.group
                Rectangle {
                    id: avatar
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42; height: 42; radius: 21
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(Theme.accent, 1.25) }
                        GradientStop { position: 1; color: Theme.accent }
                    }
                    Icon { anchors.centerIn: parent; text: "smart_button"; size: 22; fill: 1; color: "#ffffff" }
                }
                Column {
                    anchors.left: avatar.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    Txt { text: "Dynamic Island"; size: 14.5; weight: Font.DemiBold }
                    Txt { text: "Accent: " + Theme.originLabel; size: 11.5; color: Theme.fg2 }
                }
            }
            Item { width: 1; height: 12 }

            Repeater {
                model: win.pages
                Rectangle {
                    id: navItem
                    required property var modelData
                    required property int index
                    readonly property bool sel: win.page === index
                    width: parent.width
                    height: 40
                    radius: 10
                    color: sel ? Theme.accent : navMa.containsMouse ? Theme.fill : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }
                    IconTile {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        icon: navItem.modelData.icon
                        tint: navItem.modelData.tint
                        border.width: navItem.sel ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.6)
                    }
                    Txt {
                        x: 46
                        anchors.verticalCenter: parent.verticalCenter
                        text: navItem.modelData.title
                        size: 14
                        weight: navItem.sel ? Font.DemiBold : Font.Normal
                        color: navItem.sel ? Theme.accentText : Theme.fg
                    }
                    Rectangle {
                        visible: navItem.index === 2 && Notifs.visibleCount > 0 && !navItem.sel
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20; radius: 10
                        width: Math.max(20, nbadge.implicitWidth + 10)
                        color: Theme.red
                        Txt { id: nbadge; anchors.centerIn: parent; text: Notifs.visibleCount; size: 11; weight: Font.Bold; color: "#ffffff" }
                    }
                    MouseArea {
                        id: navMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.page = navItem.index
                    }
                }
            }
        }
    }

    // Content
    Flickable {
        id: flick
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: pageCol.implicitHeight + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Connections { target: win; function onPageChanged() { flick.contentY = 0; } }

        Column {
            id: pageCol
            x: 32; y: 26
            width: flick.width - 64
            spacing: 0

            Txt { text: win.pages[win.page].title; size: 30; weight: Font.Bold }
            Item { width: 1; height: 18 }

            Loader {
                width: parent.width
                sourceComponent: [appearancePage, islandPage, notifPage, focusPage, mediaPage, weatherPage, controlsPage, shortcutsPage, aboutPage][win.page]
            }
        }
    }

    // ═══════════════════════ PAGES ═══════════════════════
    Component {
        id: appearancePage
        Column {
            width: parent ? parent.width : 0

            // Live preview
            Section {
                title: "Preview"
                Item {
                    width: parent.width
                    height: 170
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.darker(Theme.accent, 1.6) }
                            GradientStop { position: 0.55; color: Theme.accent }
                            GradientStop { position: 1; color: Qt.lighter(Theme.purple, 1.1) }
                        }
                    }
                    Glass {
                        id: pvIsland
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 18
                        width: 220; height: 38
                        radius: 19
                        glowColor: Theme.live
                        glowStrength: Config.s.glow ? 0.35 : 0
                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            Rectangle { width: 22; height: 22; radius: 11; color: Theme.live; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: "Now Playing"; size: 12.5; weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                            Visualizer { count: 5; maxHeight: 14; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Glass {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 70
                        width: 340; height: 76
                        radius: 22
                        tint: Theme.card
                        Row {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            AppIcon { size: 40; fallback: "chat_bubble"; fallbackColor: Theme.green }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Txt { text: "Messages"; size: 13.5; weight: Font.DemiBold }
                                Txt { text: "Liquid glass looks good on you ✨"; size: 12.5; color: Theme.fg2 }
                            }
                        }
                    }
                }
            }

            Section {
                title: "Style"
                footer: "Glass is a translucent tint; the compositor blur behind it is not available here. Black is the classic solid look."
                SegRow { label: "Material"; key: "style"; options: [{ label: "Liquid Glass", value: "glass" }, { label: "Black", value: "black" }] }
                SegRow { label: "Appearance"; key: "appearance"; options: [{ label: "Auto", value: "auto" }, { label: "Dark", value: "dark" }, { label: "Light", value: "light" }] }
                SliderRow { label: "Glass Tint"; key: "glassOpacity"; from: 0.15; to: 0.95; fmt: v => Math.round(v * 100) + "%" }
                SwitchRow { label: "Specular Rim"; sub: "The bright refracted edge of liquid glass"; key: "glassRim" }
                SwitchRow { label: "Tint Glass with Accent"; sub: "A hint of your theme colour in the glass"; key: "glassAccentTint" }
                SwitchRow { label: "Glow"; sub: "Coloured halo while music plays or recording"; key: "glow" }
            }

            Section {
                title: "Accent Colour"
                footer: "Automatic picks the first one found: Ryoku theme → Matugen → Pywal/Wallust → Wallpaper → GTK accent. Currently using " + Theme.originLabel + "."
                CheckRow { label: "Automatic"; sub: "Follow your desktop theme"; key: "accentSource"; value: "auto" }
                CheckRow { label: "Ryoku Theme"; sub: "Ryoku's active palette"; key: "accentSource"; value: "ryoku" }
                CheckRow { label: "Matugen"; sub: Theme.matAccent !== "" ? Theme.matAccent : "Not found at " + Config.s.matugenPath; key: "accentSource"; value: "matugen" }
                CheckRow { label: "Pywal / Wallust"; sub: Theme.walAccent !== "" ? Theme.walAccent : "~/.cache/wal/colors.json not found"; key: "accentSource"; value: "wal" }
                CheckRow {
                    label: "Wallpaper"
                    sub: Theme.wallAccent !== "" ? Theme.wallAccent + " from " + Theme.wallpaper.split("/").pop()
                       : Theme.wallpaper !== "" ? "Reading " + Theme.wallpaper.split("/").pop() + "…" : "No wallpaper detected — set the path below"
                    key: "accentSource"; value: "wallpaper"
                    Rectangle { visible: Theme.wallAccent !== ""; width: 18; height: 18; radius: 9; color: Theme.wallAccent || "transparent"; anchors.verticalCenter: parent.verticalCenter }
                }
                CheckRow { label: "GTK Accent"; sub: Theme.gtkAccent !== "" ? Theme.gtkAccent : "Not set"; key: "accentSource"; value: "gtk" }
                CheckRow { label: "Album Art"; sub: "Changes with the song"; key: "accentSource"; value: "album" }
                CheckRow { label: "Custom"; key: "accentSource"; value: "custom" }
                Row_ {
                    visible: Config.s.accentSource === "custom"
                    label: "Colour"
                    minHeight: 54
                    Repeater {
                        model: ["#0a84ff", "#bf5af2", "#ff375f", "#ff453a", "#ff9f0a", "#ffd60a", "#30d158", "#40c8e0", "#8e8e93"]
                        Rectangle {
                            id: sw
                            required property string modelData
                            readonly property bool sel: Config.s.customAccent.toLowerCase() === modelData
                            width: 26; height: 26; radius: 13
                            color: modelData
                            border.width: sel ? 3 : 0
                            border.color: Theme.dark ? "#ffffff" : "#000000"
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Config.s.customAccent = sw.modelData }
                        }
                    }
                }
                TextRow { visible: Config.s.accentSource === "custom"; label: "Hex"; key: "customAccent"; placeholder: "#0a84ff" }
                TextRow { visible: Config.s.accentSource === "matugen" || Config.s.accentSource === "auto"; label: "Matugen JSON"; key: "matugenPath"; placeholder: "~/.cache/matugen/colors.json" }
                TextRow { visible: Config.s.accentSource === "wallpaper" || Config.s.accentSource === "auto"; label: "Wallpaper File"; sub: "Leave empty to detect it"; key: "wallpaperPath"; placeholder: "Automatic" }
            }

            Section {
                title: "Typography"
                footer: "\"auto\" uses SF Pro if installed, otherwise Inter. Detected: " + Theme.font
                TextRow { label: "Font Family"; key: "font"; placeholder: "auto" }
            }
        }
    }

    Component {
        id: islandPage
        Column {
            width: parent ? parent.width : 0
            Section {
                title: "Placement"
                footer: "On top of bar floats the island over your bar like a notch — leave the middle of your bar empty."
                SwitchRow { label: "On Top of Bar"; key: "overlayBar" }
                SwitchRow { label: "Reserve Space"; sub: "Keep windows below the island so it never covers an app"; key: "reserveSpace" }
                SliderRow { label: "Top Margin"; key: "topMargin"; from: 0; to: 60; step: 1; fmt: v => Math.round(v) + " px" }
            }
            Section {
                title: "Motion"
                SegRow { label: "Spring"; key: "motion"; segWidth: 340; options: [{ label: "Gentle", value: "gentle" }, { label: "Balanced", value: "balanced" }, { label: "Bouncy", value: "bouncy" }, { label: "Reduced", value: "reduced" }] }
                SwitchRow { label: "Peek on Hover"; sub: "Expand the island a little when the pointer rests on it"; key: "hoverPeek" }
                SliderRow { label: "Hover Delay"; key: "hoverDelay"; from: 80; to: 900; step: 10; fmt: v => Math.round(v) + " ms" }
            }
            Section {
                title: "Live Activities"
                SegRow {
                    label: "Clock During Activities"
                    sub: "Split pops the time out into its own bubble while music or a timer runs"
                    key: "activityClock"
                    options: [{ label: "Split", value: "split" }, { label: "Inline", value: "inline" }, { label: "Hidden", value: "hidden" }]
                }
                SwitchRow { label: "Split Second Activity"; sub: "A second live activity gets its own bubble on the right"; key: "splitActivities" }
                SwitchRow { label: "Workspace Indicator"; key: "workspaceFlash" }
            }
            Section {
                title: "Status"
                SwitchRow { label: "24-Hour Time"; sub: Config.s.use24h ? "13:41" : "1:41"; key: "use24h" }
                SwitchRow { visible: !Config.s.use24h; label: "Show AM/PM"; key: "showAmPm" }
                SwitchRow { label: "Show Seconds"; key: "showSeconds" }
                SwitchRow { label: "Battery"; key: "showBattery" }
                SwitchRow { label: "Privacy Indicators"; sub: "Orange dot = microphone, green dot = camera, red = screen recording"; key: "showPrivacy" }
            }
        }
    }

    Component {
        id: notifPage
        Column {
            width: parent ? parent.width : 0
            Section {
                title: "Status"
                Row_ {
                    label: Config.s.notifications
                         ? "Island is handling the banner display"
                         : "Ryoku's own toasts are showing"
                    sub: Config.s.notifications
                         ? "Ryoku's shell owns the notification daemon; Island takes the banners from it."
                         : "Turn Allow Notifications on to let Island draw the banners."
                    icon: "check_circle"
                    iconTint: Theme.green
                }
            }
            Section {
                title: "Daemon"
                footer: "Ryoku's shell owns org.freedesktop.Notifications. Island shows the banners and the Notification Center on top of it."
                SwitchRow { label: "Allow Notifications"; sub: "Island takes the banner display over from the shell"; key: "notifications" }
            }
            Section {
                title: "Banners"
                SegRow { label: "Style"; key: "notifStyle"; options: [{ label: "Banner", value: "banner" }, { label: "Island", value: "island" }, { label: "Corner", value: "corner" }] }
                SliderRow { label: "Duration"; key: "bannerTimeout"; from: 2; to: 15; step: 1; fmt: v => Math.round(v) + " s" }
                SegRow { label: "Show Previews"; key: "previews"; segWidth: 200; options: [{ label: "Always", value: "always" }, { label: "Never", value: "never" }] }
                SwitchRow { label: "Group by App"; key: "groupByApp" }
            }
            Section {
                title: "Sound"
                SwitchRow { label: "Play Sound"; key: "notifSound" }
                TextRow { label: "Sound File"; key: "soundFile"; placeholder: "/usr/share/sounds/…" }
            }
            Section {
                ButtonRow { text: "Send Test Notification"; onClicked: Notifs.test() }
                ButtonRow { text: "Open Notification Center"; onClicked: { Hub.settingsOpen = false; Notifs.toggleCenter(""); } }
                ButtonRow { text: "Clear All Notifications"; textColor: Theme.red; onClicked: Notifs.clearAll() }
            }
        }
    }

    Component {
        id: focusPage
        Column {
            width: parent ? parent.width : 0
            Section {
                footer: "While Do Not Disturb is on, notifications go quietly to the Notification Center."
                SwitchRow { label: "Do Not Disturb"; icon: "bedtime"; iconTint: Theme.indigo; checked: Notifs.dnd; key: ""; onToggled: v => Notifs.toggleDnd() }
                SwitchRow { label: "Allow Critical Alerts"; sub: "Urgent notifications still show a banner"; key: "dndAllowCritical" }
            }
        }
    }

    Component {
        id: mediaPage
        Column {
            width: parent ? parent.width : 0
            Section {
                title: "Now Playing"
                SwitchRow { label: "Audio Visualizer"; sub: Hub.cavaAvailable ? "Using cava" : "Install cava for a real visualizer"; key: "visualizer" }
                SwitchRow { label: "Spinning Album Art"; key: "spinArt" }
                SwitchRow { label: "Peek on Track Change"; key: "trackChangePeek" }
                SwitchRow { label: "Album Colour Tint"; sub: "Glow and media controls take the album's colour"; key: "albumTint" }
            }
            Section {
                title: "Players"
                Repeater {
                    model: Hub.players
                    ValueRow {
                        required property var modelData
                        label: modelData.identity
                        sub: modelData.trackTitle || ""
                        value: modelData.isPlaying ? "Playing" : "Paused"
                        valueColor: modelData.isPlaying ? Theme.green : Theme.fg2
                    }
                }
                ValueRow { visible: Hub.players.length === 0; label: "No players"; value: "" }
            }
        }
    }

    Component {
        id: weatherPage
        Column {
            width: parent ? parent.width : 0
            Section {
                footer: "Automatic tries GeoClue (Wi-Fi positioning, accurate to a street) and falls back to your IP address, which is often only right to the nearest big city. If it's off, pick your city below. Weather from Open-Meteo."
                SwitchRow { label: "Show Weather"; key: "weather" }
                SegRow { label: "Location"; key: "locationMode"; segWidth: 300; options: [{ label: "Automatic", value: "auto" }, { label: "IP Only", value: "ip" }, { label: "Manual", value: "manual" }] }
                SegRow { label: "Units"; key: "units"; segWidth: 200; options: [{ label: "°C", value: "metric" }, { label: "°F", value: "imperial" }] }
            }
            Section {
                title: "Current Location"
                ValueRow {
                    icon: Hub.locSource === "Manual" ? "location_on" : "near_me"
                    iconTint: Theme.blue
                    label: Hub.locName !== "" ? Hub.locName : (Hub.locStatus !== "" ? Hub.locStatus : "—")
                    sub: !Hub.hasLocation ? "" : Hub.locSource
                         + (Hub.locAccuracy > 0 ? " · ±" + (Hub.locAccuracy >= 1000 ? (Hub.locAccuracy / 1000).toFixed(1) + " km" : Math.round(Hub.locAccuracy) + " m") : "")
                         + " · " + Hub.locLat.toFixed(3) + ", " + Hub.locLon.toFixed(3)
                    value: Hub.wTemp !== "" ? Hub.wTemp + "  " + Hub.wDesc : ""
                }
                ButtonRow { text: "Refresh Location & Weather"; onClicked: Hub.refreshWeather() }
            }
            Section {
                title: "Choose a City"
                footer: "Picking a city switches Location to Manual. Switch back to Automatic any time."
                Row_ {
                    label: "Search"
                    TextField {
                        id: citySearch
                        width: 300
                        implicitHeight: 30
                        leftPadding: 10
                        rightPadding: 10
                        placeholderText: "City name…"
                        placeholderTextColor: Theme.fg3
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 13
                        selectionColor: Theme.accent
                        background: Rectangle { radius: 8; color: Theme.fill; border.width: parent.activeFocus ? 1 : 0; border.color: Theme.accent }
                        onAccepted: Hub.searchLocation(text)
                        onTextChanged: searchDebounce.restart()
                        Timer { id: searchDebounce; interval: 500; onTriggered: Hub.searchLocation(citySearch.text) }
                    }
                }
                Row_ {
                    visible: Hub.locSearching
                    label: "Searching…"
                }
                Repeater {
                    model: Hub.locResults
                    Row_ {
                        id: res
                        required property var modelData
                        icon: "location_on"
                        iconTint: Theme.red
                        label: modelData.name
                        sub: modelData.region
                        Txt { text: "Use"; size: 13.5; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        MouseArea { parent: res; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hub.setManualLocation(res.modelData) }
                    }
                }
                ValueRow { visible: Config.s.manualName !== ""; label: "Saved city"; value: Config.s.manualName }
            }
        }
    }

    Component {
        id: controlsPage
        Column {
            width: parent ? parent.width : 0
            Section {
                title: "Control Center"
                footer: "When on, Wi-Fi, Bluetooth, Focus and the other toggles light up in your theme's accent (from the wallpaper) instead of iOS blue."
                SwitchRow { label: "Theme-Coloured Toggles"; key: "ccAccent" }
            }
            Section {
                title: "Night Shift"
                SliderRow { label: "Colour Temperature"; key: "nightLightTemp"; from: 2500; to: 6500; step: 100; fmt: v => Math.round(v) + "K" }
            }
            Section {
                title: "On-Screen Display"
                SwitchRow { label: "Island OSD Pills"; sub: "Volume, mic and brightness pills on the island (the shell draws its own OSD)"; key: "osdPopups" }
                SliderRow { label: "OSD Duration"; key: "osdTimeout"; from: 800; to: 4000; step: 100; fmt: v => (v / 1000).toFixed(1) + " s" }
            }
            Section {
                title: "Power"
                SwitchRow { label: "Confirm Power Actions"; sub: "Click twice to sleep, restart or shut down"; key: "confirmPower" }
            }
        }
    }

    Component {
        id: shortcutsPage
        Column {
            width: parent ? parent.width : 0
            Section {
                title: "Global shortcuts"
                footer: "The island registers these through the compositor's global-shortcut protocol. Bind them in your desktop's shortcut settings."
                ValueRow { label: "App launcher"; value: "quickshell:islandLauncher" }
                ValueRow { label: "Open / close island"; value: "quickshell:islandToggle" }
                ValueRow { label: "Notification Center"; value: "quickshell:islandCenter" }
                ValueRow { label: "Settings"; value: "quickshell:islandSettings" }
            }
            Section {
                title: "In the island"
                ValueRow { label: "Click"; value: "Expand" }
                ValueRow { label: "Right-click"; value: "Controls" }
                ValueRow { label: "Middle-click"; value: "Play / Pause" }
                ValueRow { label: "Scroll"; value: "Volume" }
                ValueRow { label: "← → or 1–4"; value: "Switch tabs" }
                ValueRow { label: "Esc"; value: "Close" }
            }
            Section {
                title: "Notifications"
                ValueRow { label: "Banner: swipe up or sideways"; value: "Send to Notification Center" }
                ValueRow { label: "Banner: pull down, ⌄ or right-click"; value: "Actions & reply" }
                ValueRow { label: "Center: swipe left"; value: "Options / Clear" }
                ValueRow { label: "Center: swipe right or click"; value: "Open" }
                ValueRow { label: "Hover ✕"; value: "Clear" }
            }
        }
    }

    Component {
        id: aboutPage
        Column {
            width: parent ? parent.width : 0
            Section {
                ValueRow { label: "Version"; value: "3.0" }
                ValueRow { label: "Config"; value: Config.dir }
                ValueRow { label: "Accent Source"; value: Theme.originLabel }
                ValueRow { label: "Font"; value: Theme.font }
                ValueRow { label: "Theme"; value: Theme.dark ? "Dark" : "Light" }
            }
            Section {
                title: "Dependencies"
                footer: "A missing tool turns off the feature next to it. Install with pacman (or yay for AUR packages), then Recheck."
                Repeater {
                    model: Hub.depList
                    Row_ {
                        id: dep
                        required property var modelData
                        readonly property var ok: Hub.deps[modelData.cmd]
                        label: modelData.what
                        sub: modelData.cmd + (ok === false ? " — install " + modelData.pkg : "")
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: dep.ok === undefined ? "pending" : dep.ok ? "check_circle" : "cancel"
                            fill: 1; size: 20
                            color: dep.ok === undefined ? Theme.fg3 : dep.ok ? Theme.green : Theme.red
                        }
                    }
                }
                Row_ {
                    id: btSvc
                    readonly property var ok: Hub.btAdapter !== null
                    label: "Bluetooth adapter"
                    sub: ok ? "adapter present" : "no adapter — enable the bluetooth service on your host"
                    Icon { anchors.verticalCenter: parent.verticalCenter; text: btSvc.ok ? "check_circle" : "cancel"; fill: 1; size: 20; color: btSvc.ok ? Theme.green : Theme.red }
                }
                Row_ {
                    id: geoRow
                    readonly property var ok: Hub.deps["where-am-i"]
                    label: "Precise location (GeoClue)"
                    sub: ok === false ? "Optional: pacman -S geoclue — falls back to IP location" : "geoclue demo client"
                    Icon { anchors.verticalCenter: parent.verticalCenter; text: geoRow.ok ? "check_circle" : "remove_circle"; fill: 1; size: 20; color: geoRow.ok ? Theme.green : Theme.orange }
                }
                ButtonRow { text: "Recheck"; onClicked: Hub.checkDeps() }
            }
            Section {
                ButtonRow { text: "Reset All Settings"; textColor: Theme.red; onClicked: Config.reset() }
            }
        }
    }
}
