pragma ComponentBehavior: Bound

import "../../../../services"
import "../../../common"
import "../../../common/widgets"
import "../../../common/functions"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import org.kde.syntaxhighlighting

ColumnLayout {
    id: root
    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ({})
    property var segmentLang: "txt"
    property var messageData: {}
    property bool isCommandRequest: segmentLang === "command"
    property bool isMutationRequest: segmentLang === "mutation"
    property var displayLang: (isCommandRequest ? "bash" : isMutationRequest ? "plaintext" : segmentLang)

    property real codeBlockBackgroundRounding: Appearance.rounding.small
    property real codeBlockHeaderPadding: Appearance.spacing.space50
    property real codeBlockComponentSpacing: Appearance.spacing.space25

    spacing: codeBlockComponentSpacing

    Rectangle {
        Layout.fillWidth: true
        topLeftRadius: codeBlockBackgroundRounding
        topRightRadius: codeBlockBackgroundRounding
        bottomLeftRadius: Appearance.rounding.unsharpen
        bottomRightRadius: Appearance.rounding.unsharpen
        color: Appearance.colors.colSurfaceContainerHighest
        implicitHeight: codeBlockTitleBarRowLayout.implicitHeight + codeBlockHeaderPadding * 2

        RowLayout {
            id: codeBlockTitleBarRowLayout
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: codeBlockHeaderPadding
            anchors.rightMargin: codeBlockHeaderPadding
            spacing: Appearance.spacing.space100

            StyledText {
                id: codeBlockLanguage
                Layout.alignment: Qt.AlignLeft
                Layout.fillWidth: false
                Layout.topMargin: Appearance.spacing.space100
                Layout.bottomMargin: Appearance.spacing.space100
                Layout.leftMargin: Appearance.spacing.space150
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer2
                text: root.displayLang ? Repository.definitionForName(root.displayLang).name : "plain"
            }

            Item { Layout.fillWidth: true }

            ButtonGroup {
                AiMessageControlButton {
                    id: copyCodeButton
                    buttonIcon: activated ? "inventory" : "content_copy"

                    onClicked: {
                        Quickshell.clipboardText = segmentContent
                        copyCodeButton.activated = true
                        copyIconTimer.restart()
                    }

                    Timer {
                        id: copyIconTimer
                        interval: 1500
                        repeat: false
                        onTriggered: {
                            copyCodeButton.activated = false
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Copy code")
                    }
                }
                AiMessageControlButton {
                    id: saveCodeButton
                    buttonIcon: activated ? "check" : "save"

                    onClicked: {
                        const downloadPath = FileUtils.trimFileProtocol(Directories.downloads)
                        Quickshell.execDetached(["bash", "-c", 
                            `echo '${StringUtils.shellSingleQuoteEscape(segmentContent)}' > '${downloadPath}/code.${segmentLang || "txt"}'`
                        ])
                        Quickshell.execDetached(["notify-send", 
                            Translation.tr("Code saved to file"), 
                            Translation.tr("Saved to %1").arg(`${downloadPath}/code.${segmentLang || "txt"}`),
                            "-a", "Shell"
                        ])
                        saveCodeButton.activated = true
                        saveIconTimer.restart()
                    }

                    Timer {
                        id: saveIconTimer
                        interval: 1500
                        repeat: false
                        onTriggered: {
                            saveCodeButton.activated = false
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Save to Downloads")
                    }
                }
            }
        }
    }

    RowLayout {
        spacing: codeBlockComponentSpacing

        Rectangle {
            implicitWidth: 40
            implicitHeight: lineNumberColumnLayout.implicitHeight
            Layout.fillHeight: true
            Layout.fillWidth: false
            topLeftRadius: Appearance.rounding.unsharpen
            bottomLeftRadius: codeBlockBackgroundRounding
            topRightRadius: Appearance.rounding.unsharpen
            bottomRightRadius: Appearance.rounding.unsharpen
            color: Appearance.colors.colLayer2

            ColumnLayout {
                id: lineNumberColumnLayout
                anchors {
                    left: parent.left
                    right: parent.right
                    rightMargin: Appearance.spacing.space100
                    top: parent.top
                    topMargin: Appearance.spacing.space100
                }
                spacing: 0
                
                Repeater {
                    model: codeTextArea.text.split("\n").length
                    Text {
                        required property int index
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        horizontalAlignment: Text.AlignRight
                        text: index + 1
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            topLeftRadius: Appearance.rounding.unsharpen
            bottomLeftRadius: Appearance.rounding.unsharpen
            topRightRadius: Appearance.rounding.unsharpen
            bottomRightRadius: codeBlockBackgroundRounding
            color: Appearance.colors.colLayer2
            implicitHeight: codeColumnLayout.implicitHeight

            ColumnLayout {
                id: codeColumnLayout
                anchors.fill: parent
                spacing: 0
                Flickable {
                    id: codeScrollView
                    Layout.fillWidth: true
                    implicitHeight: codeTextArea.implicitHeight + 1
                    contentWidth: codeTextArea.implicitWidth
                    contentHeight: codeTextArea.implicitHeight
                    clip: true
                    interactive: false
                    
                    ScrollBar.horizontal: StyledScrollBar {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        policy: ScrollBar.AsNeeded
                        topPadding: Appearance.spacing.space100
                        bottomPadding: Appearance.spacing.space100
                        leftPadding: Appearance.spacing.space100
                        rightPadding: Appearance.spacing.space100
                        implicitHeight: 4 + topPadding + bottomPadding
                        active: true
                        visible: visualSize < 1
                    }

                    TextArea {
                        id: codeTextArea
                        width: Math.max(implicitWidth, codeScrollView.width)
                        readOnly: !editing
                        selectByMouse: enableMouseSelection || editing
                        renderType: Text.NativeRendering
                        font.family: Appearance.font.family.monospace
                        font.hintingPreference: Font.PreferNoHinting
                        font.pixelSize: Appearance.font.pixelSize.small
                        selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                        selectionColor: Appearance.colors.colSecondaryContainer
                        color: messageData.thinking ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1

                        text: segmentContent
                        onTextChanged: {
                            segmentContent = text
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Tab) {
                                const cursor = codeTextArea.cursorPosition;
                                codeTextArea.insert(cursor, "    ");
                                codeTextArea.cursorPosition = cursor + 4;
                                event.accepted = true;
                            } else if ((event.key === Qt.Key_C) && event.modifiers == Qt.ControlModifier) {
                                codeTextArea.copy();
                                event.accepted = true;
                            }
                        }

                        SyntaxHighlighter {
                            id: highlighter
                            textEdit: codeTextArea
                            repository: Repository
                            definition: Repository.definitionForName(root.displayLang || "plaintext")
                            theme: Appearance.syntaxHighlightingTheme
                        }
                    }
                }
            }

        }
    }
}