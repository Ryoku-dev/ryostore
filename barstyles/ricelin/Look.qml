pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"

/**
 * 飾 LOOK sub-surface: the pill's own geometry and translucency -- the gap above
 * the pill, the gap it leaves for windows below, and how see-through it sits.
 * These are Ricelin's own settings (Flags), so editing them never touches host
 * Hyprland config.
 *
 * Window-decoration knobs (gaps, rounding, border, blur, shadow, opacity, tiling
 * layout) belong to Ryoku, which owns ~/.config/hypr/modules and edits them from
 * Ryoku Settings > Appearance. This surface hands off to that page rather than
 * rewriting the compositor's modules behind its back. Reached from the settings
 * index; morphs back on the back chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    /**
     * Row registry, rebound whenever a group folds so keyboard navigation never
     * lands on a hidden line. Scrub rows expose a bump that steps their ScrubValue
     * one increment; the window row hands off to Ryoku Settings.
     */
    rows: {
        var r = [];
        if (pillGrp.open) {
            r.push({ item: pillGapRow, kind: "scrub", bump: function (d) { pillGapScrub.bump(d); } });
            r.push({ item: appGapRow, kind: "scrub", bump: function (d) { appGapScrub.bump(d); } });
            r.push({ item: pillOpRow, kind: "scrub", bump: function (d) { pillOpScrub.bump(d); } });
        }
        r.push({ item: windowRow, kind: "action", act: function () { root.openWindowSettings(); } });
        return r;
    }

    /** Per-field values captured on each open; the ScrubValue undo glyphs revert to these. */
    property var base: ({})

    onActiveChanged: {
        if (active) {
            seed();
        } else {
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    /** Snapshots the pill-local baseline the ScrubValue undo glyphs revert to. */
    function seed() {
        root.base = {
            pillOpacity: Flags.pillOpacity,
            topGap: Flags.topGap,
            appGap: Flags.appGap
        };
    }

    /**
     * Hands window-decoration editing to Ryoku Settings > Appearance, the owner of
     * gaps, rounding, borders, blur, shadow and opacity. Ricelin never writes the
     * managed hypr modules itself.
     */
    function openWindowSettings() {
        Quickshell.execDetached(["ryoku-shell", "hub", "open", "appearance"]);
    }

    component GroupLabel: Text {
        topPadding: 16 * root.s
        bottomPadding: 6 * root.s
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 8.5 * root.s
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2 * root.s
    }

    /**
     * Collapsible settings group: a tappable header (the group label plus a
     * chevron) over a body of rows that animates between zero and its content
     * height, so a long tab shows only the group headers until one is opened.
     * `open` is the initial state; tapping the header toggles it.
     */
    component Group: Column {
        id: grp
        property string title: ""
        property bool open: false
        default property alias rows: body.data

        width: parent ? parent.width : 0
        spacing: 0

        Item {
            width: parent.width
            height: gl.implicitHeight

            GroupLabel { id: gl; text: grp.title }

            GlyphIcon {
                anchors.right: parent.right
                anchors.verticalCenter: gl.verticalCenter
                width: 15 * root.s
                height: 15 * root.s
                name: "chevron-down"
                color: Theme.faint
                stroke: 2.0
                rotation: grp.open ? 0 : -90
                Behavior on rotation { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: grp.open = !grp.open
            }
        }

        Item {
            width: parent.width
            height: grp.open ? body.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

            Column {
                id: body
                width: parent.width
            }
        }
    }

    /**
     * One settings line. At rest it is a label + control row; hovering or
     * keyboard-focusing the row folds its grey caption open below the label so a
     * long tab stays compact by default. The row feeds the surface registry: hover
     * moves the soul seam and a click anywhere on the line drives its control via
     * activateRow.
     */
    component FieldRow: Item {
        id: frow
        property string label: ""
        property string caption: ""
        property bool collapsed: false
        default property alias control: ctrl.data

        readonly property bool focused: root.focusRowItem === frow
        readonly property bool expanded: !frow.collapsed && (fhover.hovered || frow.focused)
        readonly property real rowH: 30 * root.s
        readonly property real capH: 14 * root.s

        width: parent ? parent.width : 0
        height: frow.collapsed ? 0 : (frow.rowH + (frow.expanded ? frow.capH : 0))
        clip: true
        Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: fhover
            onHoveredChanged: if (!frow.collapsed) root.reportRowHover(frow, hovered)
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3 * root.s
            anchors.bottomMargin: 3 * root.s
            radius: 9 * root.s
            color: (fhover.hovered || frow.focused) ? Theme.frameBg : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activateRow(frow)
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 9 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * root.s

            Text {
                text: frow.label
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12.5 * root.s
                font.weight: Font.Medium
            }

            Text {
                visible: frow.expanded && frow.caption.length > 0
                text: frow.caption
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Medium
            }
        }

        Item {
            id: ctrl
            anchors.right: parent.right
            anchors.rightMargin: 9 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    Column {
        id: content
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0
        height: root.height + root.mBottom * root.s
        clip: true

        SettingsHeader {
            s: root.s
            glyph: "飾"
            title: "LOOK"
            showBack: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 0

            Group { id: pillGrp; title: "Pill"; open: true

            FieldRow {
                id: pillGapRow
                label: "Pill gap"
                caption: "Space above the pill. Lower pulls windows up with it."
                ScrubValue {
                    id: pillGapScrub
                    s: root.s
                    value: Flags.topGap
                    openValue: root.base.topGap
                    from: 0; to: 2; step: 0.1; decimals: 1
                    onEdited: v => Flags.topGap = v
                }
            }

            FieldRow {
                id: appGapRow
                label: "App gap"
                caption: "Space under the pill. Lower pulls windows up."
                ScrubValue {
                    id: appGapScrub
                    s: root.s
                    value: Flags.appGap
                    openValue: root.base.appGap
                    from: 0; to: 2; step: 0.1; decimals: 1
                    onEdited: v => Flags.appGap = v
                }
            }

            FieldRow {
                id: pillOpRow
                label: "Pill opacity"
                caption: "How see-through the pill sits"
                ScrubValue {
                    id: pillOpScrub
                    s: root.s
                    value: Flags.pillOpacity
                    openValue: root.base.pillOpacity
                    from: 0.55; to: 1.0; step: 0.05; decimals: 2
                    onEdited: v => Flags.pillOpacity = v
                }
            }

            }

            GroupLabel { text: "Windows" }

            FieldRow {
                id: windowRow
                label: "Window appearance"
                caption: "Gaps, rounding, borders, blur, shadow and opacity — edit in Ryoku Settings"
                GlyphIcon {
                    width: 16 * root.s
                    height: 16 * root.s
                    name: "chevron-right"
                    color: root.focusRowItem === windowRow ? Theme.cream : Theme.iconDim
                    stroke: 2.0
                }
            }

            Item { width: 1; height: 10 * root.s }
        }
    }
}
