pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// The panel's Widgets section: the widgets you picked, as tabs, one mounted at a time.
// Clock, Calendar, Music, All-in-one, System stats, Weather, Notes and Visualizer are
// drawn here; a picked desktop-widget plugin is mounted the way the desktop mounts it.
// EDIT shows the picked list (drag to reorder, × to remove) and every widget you can add.
Column {
    id: dw

    property var service
    property real s: 1
    property bool active: false
    property bool editing: false

    readonly property var tabs: service ? service.chosenWidgets : []
    property string current: ""
    readonly property var tab: tabs.find(t => t.key === current) || tabs[0] || null

    spacing: 12 * s

    // ---- EDIT: picked widgets in order, then the ones you can add ---------
    OrderList {
        visible: dw.editing
        width: dw.width
        s: dw.s
        model: dw.editing ? dw.tabs : []
        labelOf: (w) => w.label
        subOf: (w) => w.plugin ? "store widget" : ""
        onMoveTo: (from, to) => dw.service.moveWidget(from, to)
        onRemove: (i) => dw.service.toggleWidget(dw.tabs[i].key)
    }
    Flow {
        visible: dw.editing
        width: dw.width
        spacing: 6 * dw.s
        Repeater {
            model: dw.editing && dw.service ? dw.service.availableWidgets.filter(w => !dw.service.widgetKeys.includes(w.key)) : []
            delegate: Pill {
                required property var modelData
                label: modelData.label
                glyph: "install"
                onClicked: dw.service.toggleWidget(modelData.key)
            }
        }
    }

    Text {
        visible: !dw.editing && dw.tabs.length === 0
        text: "No widgets yet. EDIT to pick some."
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 11.5 * dw.s
    }

    // ---- tab row ----------------------------------------------------------
    Flow {
        visible: !dw.editing && dw.tabs.length > 1
        width: dw.width
        spacing: 6 * dw.s
        Repeater {
            model: dw.tabs
            delegate: Pill {
                required property var modelData
                label: modelData.label
                on: dw.tab && dw.tab.key === modelData.key
                onClicked: dw.current = modelData.key
            }
        }
    }

    // ---- the mounted widget -----------------------------------------------
    Loader {
        visible: !dw.editing
        width: dw.width
        active: dw.active && !dw.editing && !!dw.tab
        sourceComponent: !dw.tab ? null
            : dw.tab.plugin ? hostedView
            : ({ clock: clockView, calendar: calendarView, music: musicView, aio: aioView,
                 stats: statsView, weather: weatherView, notes: notesView, visualizer: vizView })[dw.tab.key] || null
    }

    // ======================================================================

    component Pill: Rectangle {
        id: pill
        property string label
        property string glyph: ""
        property bool on: false
        signal clicked()
        width: pillRow.implicitWidth + 20 * dw.s
        height: 26 * dw.s
        radius: height / 2
        color: on ? Theme.threadBg : pillArea.containsMouse ? Theme.sheen : "transparent"
        border.width: 1
        border.color: on || pillArea.containsMouse ? Theme.accent : Theme.hair
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6 * dw.s
            GlyphIcon {
                visible: pill.glyph.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 10 * dw.s
                height: 10 * dw.s
                name: pill.glyph
                color: pillArea.containsMouse ? Theme.accent : Theme.iconDim
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                color: pill.on ? Theme.accent : Theme.dim
                font.family: Theme.mono
                font.pixelSize: 10.5 * dw.s
            }
        }
        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component Stat: Column {
        id: st
        property string label
        property string value
        property real frac: -1   // 0..1 draws a meter
        width: dw.width
        spacing: 5 * dw.s
        Item {
            width: st.width
            height: stLabel.implicitHeight
            Text { id: stLabel; text: st.label; color: Theme.faint; font.family: Theme.mono; font.pixelSize: 9.5 * dw.s; font.letterSpacing: 1.6 * dw.s }
            Text { anchors.right: parent.right; text: st.value; color: Theme.bright; font.family: Theme.mono; font.pixelSize: 10.5 * dw.s }
        }
        Rectangle {
            visible: st.frac >= 0
            width: st.width
            height: 3 * dw.s
            radius: height / 2
            color: Theme.hair
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, st.frac))
                height: parent.height
                radius: parent.radius
                color: st.frac > 0.85 ? Theme.verm : Theme.accent
                Behavior on width { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }
        }
    }

    // ---- clock ------------------------------------------------------------
    component ClockFace: Column {
        id: cf
        property real size: 54
        SystemClock { id: now; precision: SystemClock.Minutes }
        spacing: 2 * dw.s
        Text {
            text: Qt.formatTime(now.date, "HH:mm")
            color: Theme.bright
            font.family: Theme.display
            font.pixelSize: cf.size * dw.s
        }
        Text {
            text: Qt.formatDate(now.date, "dddd · d MMMM").toLowerCase()
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 11 * dw.s
        }
    }
    Component { id: clockView; ClockFace {} }

    // ---- calendar ---------------------------------------------------------
    Component {
        id: calendarView
        Column {
            id: cal
            spacing: 8 * dw.s
            SystemClock { id: today; precision: SystemClock.Hours }
            property int offset: 0
            readonly property date month: new Date(today.date.getFullYear(), today.date.getMonth() + offset, 1)
            // Monday-first grid of 42 days covering the month
            readonly property var days: {
                const first = new Date(month);
                first.setDate(1 - (month.getDay() + 6) % 7);
                return Array.from({ length: 42 }, (_, i) => new Date(first.getFullYear(), first.getMonth(), first.getDate() + i));
            }
            Item {
                width: cal.width
                height: monthTitle.implicitHeight
                Text {
                    id: monthTitle
                    text: Qt.formatDate(cal.month, "MMMM yyyy")
                    color: Theme.bright
                    font.family: Theme.display
                    font.pixelSize: 16 * dw.s
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4 * dw.s
                    Repeater {
                        model: [{ g: "chevron-left", d: -1 }, { g: "chevron-right", d: 1 }]
                        delegate: Rectangle {
                            id: nav
                            required property var modelData
                            width: 24 * dw.s
                            height: 24 * dw.s
                            radius: width / 2
                            color: navArea.containsMouse ? Theme.sheen : "transparent"
                            border.width: 1
                            border.color: navArea.containsMouse ? Theme.accent : Theme.hair
                            GlyphIcon { anchors.centerIn: parent; width: 12 * dw.s; height: 12 * dw.s; name: nav.modelData.g; color: Theme.dim }
                            MouseArea { id: navArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cal.offset += nav.modelData.d }
                        }
                    }
                }
            }
            Grid {
                columns: 7
                width: cal.width
                readonly property real cell: width / 7
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    delegate: Text {
                        required property string modelData
                        width: parent.cell
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 9.5 * dw.s
                    }
                }
                Repeater {
                    model: cal.days
                    delegate: Item {
                        id: day
                        required property var modelData
                        readonly property bool inMonth: modelData.getMonth() === cal.month.getMonth()
                        readonly property bool isToday: modelData.toDateString() === today.date.toDateString()
                        width: parent.cell
                        height: 26 * dw.s
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24 * dw.s
                            height: 24 * dw.s
                            radius: width / 2
                            color: day.isToday ? Theme.accent : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: day.modelData.getDate()
                            color: day.isToday ? Theme.cardBot : day.inMonth ? Theme.bright : Theme.ghost
                            font.family: Theme.mono
                            font.pixelSize: 11 * dw.s
                        }
                    }
                }
            }
        }
    }

    // ---- music ------------------------------------------------------------
    Component {
        id: musicView
        Item {
            id: media
            readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
            height: 72 * dw.s

            Text {
                visible: !media.player
                anchors.verticalCenter: parent.verticalCenter
                text: "Nothing is playing."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12 * dw.s
            }
            Rectangle {
                id: art
                visible: !!media.player
                width: 72 * dw.s
                height: 72 * dw.s
                radius: Motion.rSmall * dw.s
                color: Theme.tileBg
                clip: true
                Image {
                    anchors.fill: parent
                    source: media.player ? media.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                GlyphIcon {
                    visible: !media.player || !media.player.trackArtUrl
                    anchors.centerIn: parent
                    width: 26 * dw.s
                    height: 26 * dw.s
                    name: "music"
                    color: Theme.iconDim
                }
            }
            Column {
                visible: !!media.player
                anchors.left: art.right
                anchors.leftMargin: 14 * dw.s
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3 * dw.s
                Text {
                    width: parent.width
                    text: media.player ? (media.player.trackTitle || media.player.identity) : ""
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 13.5 * dw.s
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: media.player ? (media.player.trackArtist || "") : ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10.5 * dw.s
                    elide: Text.ElideRight
                }
                Row {
                    topPadding: 4 * dw.s
                    spacing: 8 * dw.s
                    Repeater {
                        model: media.player ? [
                            { g: "prev", ok: media.player.canGoPrevious, act: () => media.player.previous() },
                            { g: media.player.isPlaying ? "pause" : "play", ok: media.player.canTogglePlaying, act: () => media.player.togglePlaying(), main: true },
                            { g: "next", ok: media.player.canGoNext, act: () => media.player.next() }
                        ] : []
                        delegate: Rectangle {
                            id: btn
                            required property var modelData
                            width: 28 * dw.s
                            height: 28 * dw.s
                            radius: width / 2
                            opacity: modelData.ok ? 1 : 0.4
                            color: modelData.main ? (btnArea.containsMouse ? Theme.vermLit : Theme.accent)
                                                  : btnArea.containsMouse ? Theme.sheen : "transparent"
                            border.width: modelData.main ? 0 : 1
                            border.color: Theme.hair
                            GlyphIcon {
                                anchors.centerIn: parent
                                width: 11 * dw.s
                                height: 11 * dw.s
                                name: btn.modelData.g
                                color: btn.modelData.main ? Theme.cardBot : Theme.dim
                            }
                            MouseArea {
                                id: btnArea
                                anchors.fill: parent
                                enabled: btn.modelData.ok
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: btn.modelData.act()
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- weather ----------------------------------------------------------
    component WeatherFace: Column {
        id: wf
        property bool compact: false
        readonly property var w: dw.service ? dw.service.weather : null
        readonly property var cur: w && w.current ? w.current : null
        function glyph(code, isDay) {
            if (code === 0) return isDay === false ? "moon" : "sun";
            if (code === 45 || code === 48) return "fog";
            if (code >= 95) return "storm";
            if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
            if (code >= 51) return "rain";
            return "cloud";
        }
        spacing: 10 * dw.s

        Text {
            visible: !wf.cur
            text: wf.w && wf.w.status === "error" ? "Weather is unavailable." : "Loading weather…"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12 * dw.s
        }
        Row {
            visible: !!wf.cur
            spacing: 14 * dw.s
            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: (wf.compact ? 28 : 40) * dw.s
                height: width
                name: wf.cur ? wf.glyph(wf.cur.code, wf.cur.isDay) : "cloud"
                color: Theme.accent
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1 * dw.s
                Text {
                    text: wf.cur ? wf.cur.temperature : ""
                    color: Theme.bright
                    font.family: Theme.display
                    font.pixelSize: (wf.compact ? 22 : 30) * dw.s
                }
                Text {
                    text: wf.cur ? (wf.cur.condition + " · " + (wf.w.city || "")).toLowerCase() : ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10.5 * dw.s
                }
            }
        }
        Text {
            visible: !!wf.cur && !wf.compact
            text: wf.cur ? "feels " + wf.cur.feelsLike + "  ·  ↑ " + wf.cur.high + "  ↓ " + wf.cur.low + "  ·  " + wf.cur.humidity + "% humidity" : ""
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 10 * dw.s
        }
        Row {
            visible: !!wf.cur && !wf.compact
            width: dw.width
            Repeater {
                model: wf.w && wf.w.daily ? wf.w.daily.slice(0, 5) : []
                delegate: Column {
                    id: dayCol
                    required property var modelData
                    width: dw.width / 5
                    spacing: 4 * dw.s
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: dayCol.modelData.weekday; color: Theme.faint; font.family: Theme.mono; font.pixelSize: 9.5 * dw.s }
                    GlyphIcon { anchors.horizontalCenter: parent.horizontalCenter; width: 16 * dw.s; height: 16 * dw.s; name: wf.glyph(dayCol.modelData.code, true); color: Theme.iconDim }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: dayCol.modelData.hi + "° " + dayCol.modelData.lo + "°"; color: Theme.dim; font.family: Theme.mono; font.pixelSize: 10 * dw.s }
                }
            }
        }
    }
    Component { id: weatherView; WeatherFace {} }

    // ---- visualizer -------------------------------------------------------
    component Viz: Item {
        id: vz
        readonly property var bars: dw.service ? dw.service.bars : []
        height: 80 * dw.s
        Component.onCompleted: if (dw.service) dw.service.vizUsers++
        Component.onDestruction: if (dw.service) dw.service.vizUsers--
        Row {
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: 3 * dw.s
            Repeater {
                model: 32
                delegate: Rectangle {
                    required property int index
                    width: (vz.width - 31 * 3 * dw.s) / 32
                    height: Math.max(2 * dw.s, vz.height * (vz.bars[index] || 0))
                    anchors.bottom: parent.bottom
                    radius: Math.min(width / 2, 2 * dw.s)
                    color: Theme.accent
                    opacity: 0.45 + 0.55 * (vz.bars[index] || 0)
                    Behavior on height { NumberAnimation { duration: 60 } }
                }
            }
        }
        Text {
            visible: vz.bars.length === 0
            anchors.centerIn: parent
            text: "Play something to see it move."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 11.5 * dw.s
        }
    }
    Component { id: vizView; Viz {} }

    // ---- all-in-one: clock + weather + visualizer --------------------------
    Component {
        id: aioView
        Column {
            spacing: 14 * dw.s
            Item {
                width: parent.width
                height: Math.max(aioClock.implicitHeight, aioWx.implicitHeight)
                ClockFace { id: aioClock; size: 44 }
                WeatherFace { id: aioWx; compact: true; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
            }
            Viz { width: parent.width; height: 56 * dw.s }
        }
    }

    // ---- system stats -----------------------------------------------------
    Component {
        id: statsView
        Column {
            readonly property var svc: dw.service
            function dur(sec) {
                const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
                return (d ? d + "d " : "") + (d || h ? h + "h " : "") + m + "m";
            }
            spacing: 12 * dw.s
            Stat { label: "CPU"; value: Math.round(parent.svc.cpu * 100) + "%"; frac: parent.svc.cpu }
            Stat { label: "MEMORY"; value: parent.svc.memText; frac: parent.svc.mem }
            Stat { label: "SWAP"; value: Math.round(parent.svc.swap * 100) + "%"; frac: parent.svc.swap }
            Stat { label: "LOAD"; value: parent.svc.load.map(x => x.toFixed(2)).join("  ") }
            Stat { label: "UPTIME"; value: parent.dur(parent.svc.uptime) }
        }
    }

    // ---- notes ------------------------------------------------------------
    Component {
        id: notesView
        Rectangle {
            height: 150 * dw.s
            radius: Motion.rSmall * dw.s
            color: "transparent"
            border.width: 1
            border.color: notesEdit.activeFocus ? Theme.accent : Theme.border
            Flickable {
                id: notesFlick
                anchors.fill: parent
                anchors.margins: 10 * dw.s
                contentHeight: notesEdit.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: notesEdit
                    width: notesFlick.width
                    wrapMode: TextEdit.Wrap
                    color: Theme.bright
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.cardBot
                    font.family: Theme.mono
                    font.pixelSize: 11.5 * dw.s
                    text: dw.service ? dw.service.notes : ""
                    onTextChanged: if (dw.service && activeFocus) dw.service.setNotes(text)
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y < notesFlick.contentY) notesFlick.contentY = cursorRectangle.y;
                        else if (cursorRectangle.y + cursorRectangle.height > notesFlick.contentY + notesFlick.height)
                            notesFlick.contentY = cursorRectangle.y + cursorRectangle.height - notesFlick.height;
                    }
                    Text {
                        visible: !notesEdit.text && !notesEdit.activeFocus
                        text: "Jot something down…"
                        color: Theme.faint
                        font: notesEdit.font
                    }
                }
            }
        }
    }

    // ---- an installed desktop-widget plugin -------------------------------
    Component {
        id: hostedView
        Item {
            id: hosted
            readonly property var plugin: dw.tab ? dw.tab.plugin : null
            readonly property string dir: plugin ? plugin.dir : ""
            height: slot.item ? Math.min(slot.item.implicitHeight || 200 * dw.s, 420 * dw.s) : 0
            clip: true

            // the handle a desktop plugin expects (as the desktop host gives it); its
            // settings fall back to its own defaults, and saveSetting is inert here.
            QtObject {
                id: api
                property var mainInstance: hostedSvc.item
                readonly property var pluginSettings: ({})
                readonly property string pluginDir: hosted.dir
                readonly property string stateDir: hosted.plugin
                    ? (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/plugins/" + hosted.plugin.id : ""
                function saveSetting(key, value) {}
                function saveSettings() {}
            }
            PluginObjectSlot {
                id: hostedSvc
                source: hosted.dir ? "file://" + hosted.dir + "/service/Main.qml" : ""
                configure: (svc) => { svc.pluginApi = api; }
            }
            PluginObjectSlot {
                id: slot
                width: hosted.width
                height: hosted.height
                fill: true
                source: hosted.dir ? "file://" + hosted.dir + "/content/Widget.qml" : ""
                configure: (it) => {
                    try {
                        it.pluginApi = api;
                        it.density = "compact";
                        it.s = dw.s;
                        it.widthBudget = hosted.width;
                        it.active = true;
                    } catch (e) {}
                }
            }
        }
    }
}
