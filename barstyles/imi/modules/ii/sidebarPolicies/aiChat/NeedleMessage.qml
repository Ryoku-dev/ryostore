import "../../../.."
import "../../../../services"
import "../../../common"
import "../../../common/widgets"
import "../../../common/functions"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    required property int index
    required property string kind
    required property string role
    required property string body
    required property string thought
    required property bool live
    required property bool cont
    required property bool failed
    required property string imagesJson
    required property string title
    required property string tkind
    required property string status
    required property string input
    required property string output
    required property string permJson

    property bool outputOpen: false
    property real contentSpacing: Appearance.spacing.space50

    readonly property bool isTool: root.kind === "tool"
    readonly property bool isUser: root.role === "user"
    readonly property var permission: {
        if (!root.permJson) return null;
        try { return JSON.parse(root.permJson); } catch (error) { return null; }
    }
    readonly property var images: {
        try { return JSON.parse(root.imagesJson) || []; } catch (error) { return []; }
    }
    readonly property string toolIcon: root.tkind === "execute" ? "terminal"
        : root.tkind === "search" ? "search"
        : root.tkind === "read" ? "description" : "build"
    readonly property string statusIcon: root.output.trim().length > 0
        ? (root.outputOpen ? "expand_less" : "expand_more")
        : root.status === "completed" ? "check" : root.status === "failed" ? "error" : "progress_activity"

    readonly property var permissionOptions: {
        if (!root.permission || !root.permission.options)
            return [{ id: "", name: Translation.tr("Decline") }];
        const options = root.permission.options.filter(option => String(option.kind || "") !== "reject_always");
        const hasReject = options.some(option => String(option.kind || "").indexOf("reject") >= 0);
        return hasReject ? options : options.concat([{ id: "", name: Translation.tr("Decline") }]);
    }

    width: ListView.view ? ListView.view.width : implicitWidth
    implicitHeight: rowLayout.implicitHeight + Appearance.spacing.space100

    ColumnLayout {
        id: rowLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: Appearance.spacing.space100
        }
        spacing: root.contentSpacing

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Appearance.spacing.space100
            visible: !root.isTool && !root.cont
            horizontalAlignment: root.isUser ? Text.AlignRight : Text.AlignLeft
            text: root.isUser ? Translation.tr("You") : Translation.tr("Rashin")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
        }

        Rectangle {
            visible: root.isUser
            Layout.alignment: Qt.AlignRight
            Layout.maximumWidth: root.width * 0.82
            implicitWidth: userText.implicitWidth + Appearance.spacing.space200 * 2
            implicitHeight: userText.implicitHeight + Appearance.spacing.space150 * 2
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSecondaryContainer

            StyledText {
                id: userText
                anchors {
                    fill: parent
                    margins: Appearance.spacing.space150
                    leftMargin: Appearance.spacing.space200
                    rightMargin: Appearance.spacing.space200
                }
                text: root.body
                color: Appearance.colors.colOnSecondaryContainer
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.Wrap
                textFormat: TextEdit.MarkdownText
                onLinkActivated: url => Qt.openUrlExternally(url)
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: !root.isTool && root.images.length > 0
            spacing: Appearance.spacing.space50

            Repeater {
                model: root.images
                delegate: Rectangle {
                    required property string modelData
                    width: 72
                    height: 72
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: "file://" + parent.modelData
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }
        }

        MessageThinkBlock {
            Layout.fillWidth: true
            visible: !root.isTool && !root.isUser && root.thought.length > 0
            segmentContent: root.thought
            messageData: root
            done: !root.live
            completed: !root.live
        }

        Repeater {
            Layout.fillWidth: true
            model: ScriptModel {
                values: root.isTool || root.isUser ? [] : StringUtils.splitMarkdownBlocks(root.body)
            }
            delegate: DelegateChooser {
                id: blockChooser
                role: "type"

                DelegateChoice {
                    roleValue: "code"
                    MessageCodeBlock {
                        segmentContent: modelData.content
                        segmentLang: modelData.lang || "txt"
                        messageData: root
                        enableMouseSelection: true
                    }
                }
                DelegateChoice {
                    roleValue: "text"
                    MessageTextBlock {
                        segmentContent: modelData.content
                        messageData: root
                        done: !root.live
                        enableMouseSelection: true
                        forceDisableChunkSplitting: true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.isTool
            implicitHeight: toolColumn.implicitHeight + Appearance.spacing.space150 * 2
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2
            border.width: Appearance.borderWidth.standard
            border.color: root.status === "failed" ? Appearance.colors.colError : Appearance.colors.colOutlineVariant

            MouseArea {
                anchors.fill: parent
                enabled: root.output.trim().length > 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.outputOpen = !root.outputOpen
            }

            ColumnLayout {
                id: toolColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Appearance.spacing.space150
                }
                spacing: Appearance.spacing.space25

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.space100

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.toolIcon
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: root.title.length > 0 ? root.title : root.tkind
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.statusIcon
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext

                        RotationAnimation on rotation {
                            running: root.output.trim().length === 0
                                && root.status !== "completed" && root.status !== "failed"
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: Appearance.animation.elementMove.duration * 2
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.outputOpen && root.output.trim().length > 0
                    text: root.output
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.monospace
                    wrapMode: Text.WrapAnywhere
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.permission !== null
            implicitHeight: permissionColumn.implicitHeight + Appearance.spacing.space150 * 2
            radius: Appearance.rounding.small
            color: Appearance.colors.colWarningContainer
            border.width: Appearance.borderWidth.emphasis
            border.color: Appearance.colors.colWarning

            ColumnLayout {
                id: permissionColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Appearance.spacing.space150
                }
                spacing: Appearance.spacing.space100

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Needs your approval")
                    color: Appearance.colors.colOnWarningContainer
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.permission ? String(root.permission.input || root.permission.title || "") : ""
                    color: Appearance.colors.colOnWarningContainer
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.monospace
                    wrapMode: Text.WrapAnywhere
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.space100

                    Repeater {
                        model: root.permissionOptions
                        delegate: RippleButton {
                            required property var modelData
                            implicitWidth: permissionLabel.implicitWidth + Appearance.spacing.space300
                            implicitHeight: 28
                            buttonRadius: Appearance.rounding.verysmall
                            colBackground: Appearance.colors.colLayer1
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            colRipple: Appearance.colors.colLayer1Active

                            onClicked: Needle.answerPermission(root.permission.requestId, modelData.id)

                            contentItem: StyledText {
                                id: permissionLabel
                                anchors.centerIn: parent
                                text: String(modelData.name || modelData.id || Translation.tr("Decline"))
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }
                    }
                }
            }
        }
    }
}
