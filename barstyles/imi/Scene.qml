pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "modules/imi/bar" as ImiBar
import "modules/common"
import "modules/common/widgets"
import "modules/common/plugins"
import "modules/common/functions/layout_ops.js" as LayoutOps

Scope {
    id: root

    property var modelData: null

    PanelWindow {
        id: win
        screen: root.modelData

        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 48
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ryoku-imi"

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 48

        ImiBar.BarContent {
            id: barContent
            anchors.fill: parent

            TapHandler {
                acceptedButtons: Qt.LeftButton
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onDoubleTapped: GlobalStates.editMode = !GlobalStates.editMode
            }
        }
    }

    // Edit mode buttons (separate window below the bar)
    PanelWindow {
        id: editButtons
        screen: root.modelData
        visible: GlobalStates.editMode
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ryoku-imi-edit-buttons"

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 36
        WlrLayershell.margins.top: 48

        Row {
            spacing: 8
            x: (parent.width - width) / 2
            y: 4

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: Appearance.m3colors.m3secondaryContainer

                Text {
                    text: "add"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: Appearance.m3colors.m3onSecondaryContainer
                    anchors.centerIn: parent
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: widgetPicker.visible = !widgetPicker.visible
                }
            }

            Rectangle {
                width: doneRow.width + 16
                height: 28
                radius: 14
                color: Appearance.m3colors.m3primary

                Row {
                    id: doneRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "Done"
                        color: Appearance.m3colors.m3onPrimary
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: GlobalStates.editMode = false
                }
            }
        }
    }

    // Widget picker popup (below the edit buttons)
    PanelWindow {
        id: widgetPicker
        screen: root.modelData
        visible: false
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ryoku-imi-widget-picker"

        anchors {
            top: true
        }

        implicitWidth: 260
        implicitHeight: pickerColumn.height + 24

        // Center horizontally
        WlrLayershell.margins.left: (root.modelData ? root.modelData.width / 2 - 130 : 400)
        WlrLayershell.margins.top: 90

        Connections {
            target: GlobalStates
            function onEditModeChanged() {
                if (!GlobalStates.editMode) widgetPicker.visible = false
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 12
            color: Appearance.m3colors.m3surface
            border.color: Appearance.m3colors.m3outlineVariant
            border.width: 1

            Column {
                id: pickerColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 2

                Text {
                    text: "Add Widget"
                    color: Appearance.m3colors.m3onSurface
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    bottomPadding: 4
                }

                Repeater {
                    model: BarWidgets.offerFor(
                        Config.options.bar.layouts.leftLayout
                            .concat(Config.options.bar.layouts.middleLayout)
                            .concat(Config.options.bar.layouts.rightLayout),
                        Config.options.bar.borderless
                    )

                    Rectangle {
                        required property var modelData
                        width: pickerColumn.width
                        height: 32
                        radius: 8
                        color: pickHover.hovered ? Appearance.m3colors.m3surfaceContainerHigh : "transparent"

                        HoverHandler { id: pickHover }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 8

                            Text {
                                text: modelData.icon
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 18
                                color: Appearance.m3colors.m3onSurfaceVariant
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.name
                                color: Appearance.m3colors.m3onSurface
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let layout = Config.options.bar.layouts.middleLayout.slice()
                                layout.push(modelData.id)
                                Config.options.bar.layouts.middleLayout = layout
                                widgetPicker.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    ImiBar.PopoutOverlay {
        modelData: root.modelData
    }

    // Click outside bar to dismiss edit mode
    PanelWindow {
        id: editDismiss
        screen: root.modelData
        visible: GlobalStates.editMode
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ryoku-imi-edit-dismiss"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: GlobalStates.editMode = false
        }
    }
}
