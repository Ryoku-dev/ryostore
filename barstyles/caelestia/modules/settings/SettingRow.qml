pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../components/controls"
import "../../services"
// One setting: its label and description, the control its schema row asks for
// (sw, step, slid, seg, chips, text) and a reset to the style's default.
RowLayout {
    id: root

    required property var row
    required property var value

    signal edited(var value)

    readonly property real lo: row.lo ?? row.from ?? 0
    readonly property real hi: row.hi ?? row.to ?? 100
    readonly property bool isDefault: JSON.stringify(value) === JSON.stringify(row.def)

    function label(opt: var): string {
        return row.optLabels?.[String(opt)] ?? String(opt);
    }

    spacing: Tokens.spacing.large

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            text: root.row.label
            font: Tokens.font.body.medium
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.row.desc ?? ""
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }
    }

    StyledSwitch {
        visible: root.row.ctl === "sw"
        checked: root.value === true
        onToggled: root.edited(checked)
    }

    RowLayout {
        visible: root.row.ctl === "step"
        spacing: Tokens.spacing.small

        IconButton {
            icon: "remove"
            type: IconButton.Tonal
            disabled: root.value <= root.lo
            onClicked: root.edited(Math.max(root.lo, Math.round(root.value) - 1))
        }

        StyledText {
            Layout.minimumWidth: 36
            horizontalAlignment: Text.AlignHCenter
            text: Math.round(root.value)
        }

        IconButton {
            icon: "add"
            type: IconButton.Tonal
            disabled: root.value >= root.hi
            onClicked: root.edited(Math.min(root.hi, Math.round(root.value) + 1))
        }
    }

    RowLayout {
        visible: root.row.ctl === "slid"
        spacing: Tokens.spacing.small

        // StyledSlider works in 0..1 positions; the row's range maps onto them
        StyledSlider {
            id: slider

            property real dragValue

            function toValue(v: real): real {
                return Math.round((root.lo + v * (root.hi - root.lo)) * 100) / 100;
            }

            Layout.preferredWidth: 180
            implicitHeight: 24
            value: (root.value - root.lo) / (root.hi - root.lo)
            onInteraction: v => dragValue = toValue(v)
            onReleased: v => root.edited(toValue(v))
        }

        StyledText {
            readonly property real shown: slider.dragging ? slider.dragValue : root.value

            Layout.minimumWidth: 44
            text: root.row.pct ? `${Math.round(shown * 100)}%` : shown.toFixed(2)
        }
    }

    Flow {
        visible: root.row.ctl === "seg" || root.row.ctl === "chips"
        Layout.maximumWidth: 360
        spacing: Tokens.spacing.small

        Repeater {
            model: root.row.opts ?? []

            TextButton {
                required property var modelData

                text: root.label(modelData)
                type: root.value === modelData ? TextButton.Filled : TextButton.Tonal
                onClicked: root.edited(modelData)
            }
        }
    }

    StyledTextField {
        visible: root.row.ctl === "text"
        Layout.preferredWidth: 220
        text: root.value ?? ""
        onEditingFinished: if (text !== root.value) root.edited(text)
    }

    IconButton {
        icon: "restart_alt"
        type: IconButton.Text
        opacity: root.isDefault ? 0 : 1
        disabled: root.isDefault
        onClicked: root.edited(root.row.def)
    }
}
