import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: root

    // "horizontal" (wide plate) or "vertical" (tall column specimen)
    property string mode: "horizontal"
    property string art: "earth.gif"
    property string code: "GMAIL-01"
    property string title: "受信箱"
    property string sub: "GMAIL CLIENT"
    property string caption: ""
    property var readout: []
    property string seal: "便"
    property string barcodeText: "RYOKU"
    property real artScale: 1.0
    property int artFillMode: -1
    property real artRotation: 0

    readonly property string artSource: {
        if (!root.art || root.art.length === 0)
            return "";
        if (root.art.indexOf("://") !== -1 || root.art.indexOf("/") === 0)
            return root.art;
        var home = (typeof Quickshell !== "undefined" && Quickshell.env && Quickshell.env("HOME"))
            ? Quickshell.env("HOME")
            : ((typeof Directories !== "undefined" && Directories.home) ? Directories.home : "");
        return "file://" + home + "/Pictures/ryodecors/" + root.art;
    }

    implicitWidth: mode === "vertical" ? 220 : 400
    implicitHeight: mode === "vertical" ? 360 : 140

    Rectangle {
        id: bgCard
        anchors.fill: parent
        color: (typeof Appearance !== "undefined" && Appearance.colors) ? (root.mode === "horizontal" ? Appearance.colors.colLayer0 : Appearance.colors.colLayer1) : "#121216"
        border.width: 1
        border.color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOutlineVariant : "#2a2a32"
        radius: (typeof Appearance !== "undefined" && Appearance.rounding) ? Appearance.rounding.normal : 6
        clip: true

        // ═══════════════════════════════════════════════════════════════════
        // HORIZONTAL MODE (Ryoku Decor style)
        // ═══════════════════════════════════════════════════════════════════
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12
            visible: root.mode === "horizontal"

            // Art Pane (left ~40%)
            Rectangle {
                Layout.preferredWidth: Math.min(150, Math.max(110, parent.height - 16))
                Layout.fillHeight: true
                color: "#000000"
                border.width: 1
                border.color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOutlineVariant : "#2a2a32"
                radius: 4
                clip: true

                AnimatedImage {
                    anchors.centerIn: parent
                    readonly property bool isQuarterTurn: Math.abs(Math.round(root.artRotation) % 180) === 90
                    width: (isQuarterTurn ? parent.height : parent.width) * Math.max(1.0, root.artScale)
                    height: (isQuarterTurn ? parent.width : parent.height) * Math.max(1.0, root.artScale)
                    rotation: root.artRotation
                    source: root.artSource
                    fillMode: (root.artFillMode !== -1)
                        ? root.artFillMode
                        : (isQuarterTurn ? Image.PreserveAspectCrop : ((root.artScale > 1.0 || root.art === "bounce.gif") ? Image.PreserveAspectCrop : Image.PreserveAspectFit))
                    playing: true
                    asynchronous: true
                }

                // Corner ticks
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 6; height: 1; color: Appearance.colors.colOutline }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1; height: 6; color: Appearance.colors.colOutline }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 6; height: 1; color: Appearance.colors.colOutline }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1; height: 6; color: Appearance.colors.colOutline }
                Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 6; height: 1; color: Appearance.colors.colOutline }
                Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 1; height: 6; color: Appearance.colors.colOutline }
                Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 6; height: 1; color: Appearance.colors.colOutline }
                Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 1; height: 6; color: Appearance.colors.colOutline }
            }

            // Editorial Data Pane (right ~60%)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                // // CODE
                Text {
                    text: "// " + root.code
                    color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colSubtext : "#777782"
                    font.family: (typeof Appearance !== "undefined" && Appearance.font) ? Appearance.font.family.mono : "JetBrains Mono"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                }

                // Japanese Display Title + Subtitle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: root.title
                        color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOnSurface : Appearance.colors.colOutline
                        font.family: (typeof Appearance !== "undefined" && Appearance.font) ? Appearance.font.family.main : "Space Grotesk"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.sub
                        color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOnSurfaceVariant : "#9999a4"
                        font.family: (typeof Appearance !== "undefined" && Appearance.font) ? Appearance.font.family.main : "Space Grotesk"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.letterSpacing: 1.5
                        elide: Text.ElideRight
                    }

                    // Kanji Seal Stamp
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 2
                        color: "transparent"
                        border.width: 1
                        border.color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colPrimary : Appearance.colors.colPrimary

                        Text {
                            anchors.centerIn: parent
                            text: root.seal
                            color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colPrimary : Appearance.colors.colPrimary
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                }

                // Caption
                Text {
                    visible: root.caption !== ""
                    Layout.fillWidth: true
                    text: root.caption
                    color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOnSurfaceVariant : "#888892"
                    font.family: (typeof Appearance !== "undefined" && Appearance.font) ? Appearance.font.family.main : "Space Grotesk"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }

                // Readout Badges
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: root.readout && root.readout.length > 0

                    Repeater {
                        model: root.readout
                        Rectangle {
                            height: 18
                            width: chipText.implicitWidth + 8
                            radius: 3
                            color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colLayer2 : "#1c1c22"
                            border.width: 1
                            border.color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOutlineVariant : "#2a2a32"

                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: modelData
                                color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOnSurfaceVariant : "#9999a4"
                                font.family: (typeof Appearance !== "undefined" && Appearance.font) ? Appearance.font.family.mono : "JetBrains Mono"
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════
        // VERTICAL MODE (Ryoku Placard style)
        // ═══════════════════════════════════════════════════════════════════
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            visible: root.mode === "vertical"

            // Header
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "// " + root.code
                    color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colSubtext : "#777782"
                    font.family: (typeof Appearance !== "undefined" && Appearance.font) ? Appearance.font.family.mono : "JetBrains Mono"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                }

                // Seal
                Rectangle {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 2
                    color: "transparent"
                    border.width: 1
                    border.color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colPrimary : Appearance.colors.colPrimary
                    Text {
                        anchors.centerIn: parent
                        text: root.seal
                        color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colPrimary : Appearance.colors.colPrimary
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }

            Text {
                text: root.title
                color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOnSurface : Appearance.colors.colOutline
                font.family: (typeof Appearance !== "undefined" && Appearance.font) ? Appearance.font.family.main : "Space Grotesk"
                font.pixelSize: 18
                font.weight: Font.Bold
            }

            Text {
                text: root.sub
                color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOnSurfaceVariant : "#9999a4"
                font.family: (typeof Appearance !== "undefined" && Appearance.font) ? Appearance.font.family.main : "Space Grotesk"
                font.pixelSize: 9
                font.weight: Font.Medium
                font.letterSpacing: 1.5
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOutlineVariant : "#2a2a32"
            }

            // Art Frame (Center)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#000000"
                border.width: 1
                border.color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOutlineVariant : "#2a2a32"
                radius: 4
                clip: true

                AnimatedImage {
                    anchors.centerIn: parent
                    readonly property bool isQuarterTurn: Math.abs(Math.round(root.artRotation) % 180) === 90
                    width: (isQuarterTurn ? parent.height : parent.width) * Math.max(1.0, root.artScale)
                    height: (isQuarterTurn ? parent.width : parent.height) * Math.max(1.0, root.artScale)
                    rotation: root.artRotation
                    source: root.artSource
                    fillMode: (root.artFillMode !== -1)
                        ? root.artFillMode
                        : (isQuarterTurn ? Image.PreserveAspectCrop : ((root.artScale > 1.0 || root.art === "bounce.gif") ? Image.PreserveAspectCrop : Image.PreserveAspectFit))
                    playing: true
                    asynchronous: true
                }

                // Corner ticks
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 6; height: 1; color: Appearance.colors.colOutline }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1; height: 6; color: Appearance.colors.colOutline }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 6; height: 1; color: Appearance.colors.colOutline }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1; height: 6; color: Appearance.colors.colOutline }
                Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 6; height: 1; color: Appearance.colors.colOutline }
                Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 1; height: 6; color: Appearance.colors.colOutline }
                Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 6; height: 1; color: Appearance.colors.colOutline }
                Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 1; height: 6; color: Appearance.colors.colOutline }
            }

            // Caption
            Text {
                visible: root.caption !== ""
                Layout.fillWidth: true
                text: root.caption
                color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOnSurfaceVariant : "#888892"
                font.family: (typeof Appearance !== "undefined" && Appearance.font) ? Appearance.font.family.main : "Space Grotesk"
                font.pixelSize: 10
                wrapMode: Text.Wrap
            }

            // Readout chips at footer
            Flow {
                Layout.fillWidth: true
                spacing: 4
                visible: root.readout && root.readout.length > 0

                Repeater {
                    model: root.readout
                    Rectangle {
                        height: 16
                        width: vchipText.implicitWidth + 6
                        radius: 2
                        color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colLayer2 : "#1c1c22"
                        border.width: 1
                        border.color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOutlineVariant : "#2a2a32"

                        Text {
                            id: vchipText
                            anchors.centerIn: parent
                            text: modelData
                            color: (typeof Appearance !== "undefined" && Appearance.colors) ? Appearance.colors.colOnSurfaceVariant : "#9999a4"
                            font.family: (typeof Appearance !== "undefined" && Appearance.font) ? Appearance.font.family.mono : "JetBrains Mono"
                            font.pixelSize: 8
                        }
                    }
                }
            }
        }
    }
}
