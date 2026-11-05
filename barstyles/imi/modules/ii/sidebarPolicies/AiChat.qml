import "../../.."
import "../../../services"
import "../../common"
import "../../common/widgets"
import "../../common/functions"
import "aiChat"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import shell.services as RyokuServices

Item {
    id: root
    property real padding: Appearance.spacing.space50
    property int entranceTrigger: -1
    property string draft: ""
    property bool modelMenuOpen: false
    property bool historyMenuOpen: false

    readonly property bool available: RyokuServices.Needle.available
    readonly property var models: RyokuServices.Needle.models || []
    readonly property var sessions: RyokuServices.Needle.sessions || []
    readonly property bool hasConvo: RyokuServices.Needle.convo.count > 0
    readonly property string greeting: Config.options.sidebar.ai.greeting.length > 0
        ? Config.options.sidebar.ai.greeting
        : Translation.tr("Ask Rashin about this machine…")

    function shortModel(value) {
        const text = String(value || "");
        const slash = Math.max(text.lastIndexOf("/"), text.lastIndexOf(":"));
        return slash >= 0 ? text.slice(slash + 1) : text;
    }

    function scrollEnd() {
        Qt.callLater(() => transcript.positionViewAtEnd());
    }

    function send() {
        const text = root.draft.trim();
        if (text.length === 0 || RyokuServices.Needle.busy)
            return;
        RyokuServices.Needle.send(text);
        root.draft = "";
    }

    Component.onCompleted: {
        RyokuServices.Needle.loadSessions();
        RyokuServices.Needle.noteOpened();
        RyokuServices.Needle.agentSurfaceOpened();
        root.scrollEnd();
    }

    // The host holds its streaming bridge only while a surface is registered.
    Component.onDestruction: RyokuServices.Needle.agentSurfaceClosed()

    onEntranceTriggerChanged: root.scrollEnd()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Control || event.key === Qt.Key_Shift
                || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta)
            return;
        composer.forceActiveFocus();
    }

    Connections {
        target: RyokuServices.Needle
        function onTouched() { root.scrollEnd(); }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Appearance.spacing.space100

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.space50
            visible: root.available

            RippleButton {
                implicitWidth: modelChipRow.implicitWidth + Appearance.spacing.space200
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: {
                    root.historyMenuOpen = false;
                    root.modelMenuOpen = !root.modelMenuOpen;
                }

                contentItem: RowLayout {
                    id: modelChipRow
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.space50

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: "neurology"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.shortModel(RyokuServices.Needle.currentModel)
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 140
                    }
                }
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: {
                    root.modelMenuOpen = false;
                    root.historyMenuOpen = !root.historyMenuOpen;
                    RyokuServices.Needle.loadSessions();
                }

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "history"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2
                }
            }

            RippleButton {
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: {
                    root.modelMenuOpen = false;
                    root.historyMenuOpen = false;
                    RyokuServices.Needle.newChat();
                    root.draft = "";
                }

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "add_comment"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.modelMenuOpen
            implicitHeight: Math.min(220, modelList.contentHeight + Appearance.spacing.space100 * 2)
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer3
            border.width: Appearance.borderWidth.standard
            border.color: Appearance.colors.colOutlineVariant

            ListView {
                id: modelList
                anchors {
                    fill: parent
                    margins: Appearance.spacing.space50
                }
                model: root.models
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 2

                delegate: RippleButton {
                    required property var modelData
                    width: modelList.width
                    implicitHeight: 30
                    buttonRadius: Appearance.rounding.verysmall
                    readonly property bool current: RyokuServices.Needle.currentModel === String(modelData.id || "")
                    colBackground: current ? Appearance.colors.colPrimaryContainer : "transparent"
                    colBackgroundHover: current ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer3Hover
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    onClicked: {
                        RyokuServices.Needle.setModel(modelData.id);
                        root.modelMenuOpen = false;
                    }

                    contentItem: StyledText {
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: Appearance.spacing.space100
                            rightMargin: Appearance.spacing.space100
                            verticalCenter: parent.verticalCenter
                        }
                        text: String(modelData.name || root.shortModel(modelData.id))
                        color: parent.current ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer3
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideMiddle
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.historyMenuOpen
            implicitHeight: Math.min(260, Math.max(48, historyList.contentHeight + Appearance.spacing.space100 * 2))
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer3
            border.width: Appearance.borderWidth.standard
            border.color: Appearance.colors.colOutlineVariant

            ListView {
                id: historyList
                anchors {
                    fill: parent
                    margins: Appearance.spacing.space50
                }
                model: root.sessions
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 2

                delegate: RippleButton {
                    required property var modelData
                    width: historyList.width
                    implicitHeight: 34
                    buttonRadius: Appearance.rounding.verysmall
                    readonly property bool current: String(modelData.id || "") === RyokuServices.Needle.currentSession
                    colBackground: current ? Appearance.colors.colPrimaryContainer : "transparent"
                    colBackgroundHover: current ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer3Hover
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    onClicked: {
                        RyokuServices.Needle.switchSession(modelData.id);
                        root.historyMenuOpen = false;
                    }

                    contentItem: StyledText {
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: Appearance.spacing.space100
                            rightMargin: Appearance.spacing.space100
                            verticalCenter: parent.verticalCenter
                        }
                        text: String(modelData.title || modelData.id || "")
                        color: parent.current ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer3
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.sessions.length === 0
                text: Translation.tr("No saved chats yet")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.available && !root.hasConvo

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width, 320)
                spacing: Appearance.spacing.space150

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "star_shine"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.greeting
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.normal
                    wrapMode: Text.Wrap
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("Enter sends · Shift+Enter for a new line · Escape stops")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.available

            StyledText {
                anchors.centerIn: parent
                width: Math.min(parent.width, 320)
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Rashin is not running. Enable it in Ryoku Hub → Rashin to chat here.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.Wrap
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.available && root.hasConvo

            ListView {
                id: transcript
                anchors.fill: parent
                clip: true
                model: RyokuServices.Needle.convo
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 3200
                spacing: Appearance.spacing.space100
                onCountChanged: root.scrollEnd()
                onContentHeightChanged: if (RyokuServices.Needle.busy || atYEnd) root.scrollEnd()

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: NeedleMessage {}

                footer: Column {
                    width: transcript.width
                    spacing: Appearance.spacing.space100

                    Repeater {
                        model: RyokuServices.Needle.standalonePerms
                        delegate: Rectangle {
                            required property var modelData
                            width: transcript.width
                            implicitHeight: standaloneColumn.implicitHeight + Appearance.spacing.space150 * 2
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colWarningContainer
                            border.width: Appearance.borderWidth.emphasis
                            border.color: Appearance.colors.colWarning

                            ColumnLayout {
                                id: standaloneColumn
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
                                    text: String(modelData.input || modelData.title || "")
                                    color: Appearance.colors.colOnWarningContainer
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.family: Appearance.font.family.monospace
                                    wrapMode: Text.WrapAnywhere
                                }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.space100

                                    Repeater {
                                        model: {
                                            const options = modelData.options || [];
                                            const kept = options.filter(option => String(option.kind || "") !== "reject_always");
                                            const hasReject = kept.some(option => String(option.kind || "").indexOf("reject") >= 0);
                                            return hasReject ? kept : kept.concat([{ id: "", name: Translation.tr("Decline") }]);
                                        }
                                        delegate: RippleButton {
                                            required property var modelData
                                            implicitWidth: standaloneLabel.implicitWidth + Appearance.spacing.space300
                                            implicitHeight: 28
                                            buttonRadius: Appearance.rounding.verysmall
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            colRipple: Appearance.colors.colLayer1Active
                                            onClicked: RyokuServices.Needle.answerPermission(modelData.requestId, modelData.id)

                                            contentItem: StyledText {
                                                id: standaloneLabel
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
            }

            ScrollToBottomButton {
                target: transcript
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: RyokuServices.Needle.busy
            text: RyokuServices.Needle.activity.length > 0
                ? RyokuServices.Needle.activity : Translation.tr("working")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller

            SequentialAnimation on opacity {
                running: RyokuServices.Needle.busy
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.6; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.6; to: 1; duration: 900; easing.type: Easing.InOutSine }
                onStopped: parent.opacity = 1
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: composerColumn.implicitHeight + Appearance.spacing.space100 * 2
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            border.width: composer.activeFocus ? Appearance.borderWidth.emphasis : Appearance.borderWidth.standard
            border.color: composer.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

            ColumnLayout {
                id: composerColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Appearance.spacing.space100
                }
                spacing: Appearance.spacing.space50

                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(root.height * 2 / 5, composer.implicitHeight)
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    StyledTextArea {
                        id: composer
                        anchors.fill: parent
                        text: root.draft
                        wrapMode: TextArea.Wrap
                        padding: Appearance.spacing.space100
                        color: Appearance.colors.colOnLayer2
                        placeholderText: Translation.tr("Message Rashin…")
                        background: null

                        onTextChanged: root.draft = composer.text

                        Keys.onPressed: event => {
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                    && !(event.modifiers & Qt.ShiftModifier)) {
                                root.send();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape && RyokuServices.Needle.busy) {
                                RyokuServices.Needle.cancel();
                                event.accepted = true;
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.space50

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        implicitWidth: 30
                        implicitHeight: 30
                        buttonRadius: Appearance.rounding.full
                        enabled: RyokuServices.Needle.busy || root.draft.trim().length > 0
                        colBackground: RyokuServices.Needle.busy
                            ? Appearance.colors.colErrorContainer
                            : root.draft.trim().length > 0 ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                        colBackgroundHover: RyokuServices.Needle.busy
                            ? Appearance.colors.colErrorContainerHover
                            : root.draft.trim().length > 0 ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer3Hover
                        colRipple: Appearance.colors.colPrimaryActive
                        onClicked: RyokuServices.Needle.busy ? RyokuServices.Needle.cancel() : root.send()

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: RyokuServices.Needle.busy ? "stop" : "arrow_upward"
                            iconSize: Appearance.font.pixelSize.normal
                            color: RyokuServices.Needle.busy
                                ? Appearance.colors.colOnErrorContainer
                                : root.draft.trim().length > 0 ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }
}
