pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"
import "lib/fuzzy.js" as Fuzzy

/**
 * Shared add-app picker for the class-routing surfaces (Stash, SpaceApps).
 * Closed it renders the dashed "Add app" bar; open it swaps to the launcher's
 * fuzzy search plus result list with keyboard nav. A pick emits picked(entry)
 * and leaves closing to the surface, which owns what "add" means. Also hosts
 * the class↔entry helpers (normalizeClass/resolveEntry) both surfaces use to
 * dress their routed-class rows.
 */
Column {
    id: picker

    property real s: 1
    property bool addOpen: false
    property string query: ""
    property int selectedIndex: 0

    signal picked(var entry)

    spacing: 0

    readonly property var allApps: DesktopEntries.applications.values

    /**
     * Collapse a window-class token to a comparable key: a two-char character
     * class like `[Ss]` keeps its lowercase letter, then everything non-alnum is
     * dropped so `[Ss]potify` and `Ghosttype-app` line up with an entry's
     * StartupWMClass or id.
     */
    function normalizeClass(cls) {
        return String(cls)
            .replace(/\[(.)(.)\]/g, "$2")
            .toLowerCase()
            .replace(/[^a-z0-9]/g, "");
    }

    /**
     * The installed app behind a window class, used only to dress the row with a
     * real name and icon. Normalized equality on StartupWMClass, id or name is
     * preferred (Spotify: `[Ss]potify` → `spotify`); when nothing matches exactly,
     * a normalized substring link is tried (GhostType ships StartupWMClass
     * `GhostType` while its window class is `Ghosttype-app`, so `ghosttypeapp`
     * contains `ghosttype`). Among substring links the longest matched field wins,
     * so `ghosttypeapp` resolves to GhostType (`ghosttype`) and not Ghostty
     * (`ghostty`), and the substring side must be at least four chars so short
     * tokens cannot cross-link unrelated apps. Null when nothing matches.
     */
    function resolveEntry(cls) {
        var want = picker.normalizeClass(cls);
        if (want.length === 0)
            return null;
        var apps = picker.allApps;
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (!e)
                continue;
            var cands = [e.startupClass, e.id, e.name];
            for (var j = 0; j < cands.length; j++)
                if (cands[j] && picker.normalizeClass(cands[j]) === want)
                    return e;
        }
        var best = null;
        var bestLen = 0;
        for (var k = 0; k < apps.length; k++) {
            var e2 = apps[k];
            if (!e2)
                continue;
            var cands2 = [e2.startupClass, e2.id, e2.name];
            for (var n = 0; n < cands2.length; n++) {
                if (!cands2[n])
                    continue;
                var got = picker.normalizeClass(cands2[n]);
                if (got.length < 4)
                    continue;
                var hit = (want.length >= 4 && got.indexOf(want) !== -1) || want.indexOf(got) !== -1;
                if (hit && got.length > bestLen) {
                    best = e2;
                    bestLen = got.length;
                }
            }
        }
        return best;
    }

    readonly property var allEntries: {
        var src = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < src.length; i++)
            if (src[i] && !src[i].noDisplay)
                out.push(src[i]);
        return out;
    }
    readonly property var results: Fuzzy.rank(allEntries, query, ({}))

    /**
     * Window-coordinate position of the last hover event that was allowed to
     * move the selection. Rows sliding under a stationary cursor during
     * keyboard scrolling produce hover events at an unchanged window position,
     * which must not steal the keyboard selection.
     */
    property point lastPointer: Qt.point(-1, -1)

    function pick() {
        if (results.length === 0 || selectedIndex < 0 || selectedIndex >= results.length)
            return;
        var e = results[selectedIndex];
        if (e)
            picker.picked(e);
    }

    /** named to dodge Column's built-in `move` Transition property */
    function moveSel(delta) {
        if (results.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        addList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function openAdd() {
        picker.query = "";
        picker.selectedIndex = 0;
        picker.addOpen = true;
    }

    function closeAdd() {
        picker.addOpen = false;
        picker.query = "";
    }

    onResultsChanged: if (selectedIndex >= results.length) selectedIndex = 0;
    onAddOpenChanged: if (addOpen) Qt.callLater(search.input.forceActiveFocus)

    Item {
        width: parent.width
        height: visible ? 40 * picker.s : 0
        visible: !picker.addOpen

        Canvas {
            id: dash
            anchors.fill: parent
            anchors.topMargin: 4 * picker.s
            anchors.bottomMargin: 4 * picker.s
            property color stroke: Qt.alpha(Theme.vermLit, addArea.containsMouse ? 0.7 : 0.36)
            onStrokeChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var r = 9 * picker.s;
                var w = width;
                var h = height;
                var p = 0.5;
                ctx.lineWidth = 1;
                ctx.strokeStyle = stroke;
                ctx.setLineDash([4 * picker.s, 4 * picker.s]);
                ctx.beginPath();
                ctx.moveTo(p + r, p);
                ctx.lineTo(w - p - r, p);
                ctx.arcTo(w - p, p, w - p, p + r, r);
                ctx.lineTo(w - p, h - p - r);
                ctx.arcTo(w - p, h - p, w - p - r, h - p, r);
                ctx.lineTo(p + r, h - p);
                ctx.arcTo(p, h - p, p, h - p - r, r);
                ctx.lineTo(p, p + r);
                ctx.arcTo(p, p, p + r, p, r);
                ctx.stroke();
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6 * picker.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "+"
                color: Theme.vermLit
                font.family: Theme.font
                font.pixelSize: 14 * picker.s
                font.weight: Font.Bold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Add app"
                color: Theme.vermLit
                font.family: Theme.font
                font.pixelSize: 11 * picker.s
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5 * picker.s
            }
        }

        MouseArea {
            id: addArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: picker.openAdd()
        }
    }

    /** ── add view ── */

    Item {
        width: parent.width
        height: visible ? 22 * picker.s : 0
        visible: picker.addOpen

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7 * picker.s

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * picker.s
                height: 16 * picker.s

                GlyphIcon {
                    anchors.fill: parent
                    name: "chevron-left"
                    color: addBackArea.containsMouse ? Theme.cream : Theme.iconDim
                    stroke: 1.8
                }

                MouseArea {
                    id: addBackArea
                    anchors.fill: parent
                    anchors.margins: -6 * picker.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.closeAdd()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "ADD APP"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 9.5 * picker.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.4 * picker.s
            }
        }
    }

    Item { width: 1; height: visible ? 4 * picker.s : 0; visible: picker.addOpen }

    SearchField {
        id: search
        width: parent.width
        visible: picker.addOpen
        s: picker.s
        kanji: "探"
        placeholder: "Search apps"
        counterText: picker.results.length + ""
        onTextChanged: {
            picker.query = text;
            picker.selectedIndex = 0;
        }
        onMoved: (d) => picker.moveSel(d)
        onAccepted: picker.pick()
        onDismissed: picker.closeAdd()
    }

    Item { width: 1; height: visible ? 6 * picker.s : 0; visible: picker.addOpen }

    Item {
        width: parent.width
        height: visible ? Math.min(addList.contentHeight, 226 * picker.s) : 0
        visible: picker.addOpen

        ListView {
            id: addList
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 4 * picker.s
            model: picker.results.length

            delegate: Item {
                id: appRow
                required property int index
                width: addList.width
                height: 40 * picker.s

                readonly property var entry: picker.results[index]
                readonly property bool selected: index === picker.selectedIndex

                Rectangle {
                    anchors.fill: parent
                    radius: 9 * picker.s
                    visible: appRow.selected || appArea.containsMouse
                    color: appRow.selected ? Theme.frameBg : Qt.rgba(0.94, 0.88, 0.84, 0.03)
                    border.width: appRow.selected ? 1 : 0
                    border.color: Theme.frameBorder
                }

                MouseArea {
                    id: appArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: (m) => {
                        var g = appArea.mapToItem(null, m.x, m.y);
                        if (g.x !== picker.lastPointer.x || g.y !== picker.lastPointer.y) {
                            picker.lastPointer = Qt.point(g.x, g.y);
                            picker.selectedIndex = appRow.index;
                        }
                    }
                    onClicked: {
                        picker.selectedIndex = appRow.index;
                        picker.pick();
                    }
                }

                Rectangle {
                    id: appTileBg
                    anchors.left: parent.left
                    anchors.leftMargin: 11 * picker.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24 * picker.s
                    height: 24 * picker.s
                    radius: 6 * picker.s
                    color: Qt.rgba(1, 1, 1, 0.05)
                    visible: !(appIcon.status === Image.Ready && appIcon.source != "")
                }
                Image {
                    id: appIcon
                    anchors.fill: appTileBg
                    sourceSize.width: Math.round(40 * picker.s)
                    sourceSize.height: Math.round(40 * picker.s)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready && source != ""
                    source: appRow.entry && appRow.entry.icon ? Quickshell.iconPath(appRow.entry.icon, true) : ""
                }

                Text {
                    anchors.left: appTileBg.right
                    anchors.leftMargin: 11 * picker.s
                    anchors.right: parent.right
                    anchors.rightMargin: 12 * picker.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: appRow.entry ? appRow.entry.name : ""
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12.5 * picker.s
                    font.weight: appRow.selected ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
            }
        }

        WheelScroller {
            anchors.fill: parent
            s: picker.s
            flick: addList
        }
    }
}
