import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "."

Item {
    id: root
    Layout.fillHeight: true
    readonly property bool compactMode: parent ? (parent.width < 550) : true
    Layout.preferredWidth: compactMode ? 54 : 200

    property string activeTab
    property real spacing: 8

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.normal
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
    }

    // Build the nav button list dynamically
    property var _navButtons: {
        var list = EmailService.navOrder;
        var visibilityMap = {
            "all_inboxes": EmailService.enableAllInboxes,
            "inbox": true,
            "spam": EmailService.enableSpam,
            "sent": EmailService.enableSent,
            "trash": EmailService.enableTrash,
            "starred": EmailService.enableStarred,
            "important": EmailService.enableImportant,
            "purchases": EmailService.enablePurchases
        };
        return list.filter(item => visibilityMap[item.tab] !== false);
    }

    // Build the labels list
    property var _labelButtons: {
        var arr = EmailService.enabledLabels;
        var list = [];
        for (var i = 0; i < EmailService.labels.count; i++) {
            var lbl = EmailService.labels.get(i);
            if (lbl && arr.includes(lbl.id)) {
                list.push({
                    id: lbl.id,
                    name: lbl.name,
                    unread: lbl.messagesUnread
                });
            }
        }
        return list;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12

        // ── Header: Section Pip + Title (Ryoku Signature) ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            visible: !root.compactMode

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 4
                    height: 4
                    color: Appearance.colors.colPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "GMAIL"
                    color: Appearance.colors.colOnSurface
                    font.family: Appearance.font.family.main
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ── Compose Button (Ryoku Industrial Action Style) ──
        Rectangle {
            id: composeBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Appearance.rounding.normal
            color: composeMouse.pressed ? Appearance.colors.colPrimaryActive
                : (composeMouse.containsMouse ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary)
            border.width: 1
            border.color: Appearance.colors.colPrimaryActive
            enabled: EmailService.authenticated
            opacity: enabled ? 1.0 : 0.5

            Behavior on color { ColorAnimation { duration: 100 } }

            MouseArea {
                id: composeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = "compose"
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    text: "edit"
                    iconSize: 16
                    color: Appearance.colors.colOnPrimary
                }

                StyledText {
                    visible: !root.compactMode
                    text: Translation.tr("Compose")
                    font.family: Appearance.font.family.main
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimary
                }
            }
        }

        // ── Navigation Buttons List ──
        StyledFlickable {
            id: navFlickable
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(scrollContent.implicitHeight, 200)
            clip: true
            contentHeight: scrollContent.implicitHeight

            ColumnLayout {
                id: scrollContent
                width: navFlickable.width
                spacing: 4

                Repeater {
                    model: root._navButtons
                    delegate: EmailNavButton {
                        compact: root.compactMode
                        Layout.fillWidth: true
                        enabled: EmailService.authenticated
                        toggled: root.activeTab === modelData.tab
                        onClicked: root.activeTab = modelData.tab
                        iconName: modelData.icon
                        label: modelData.label

                        badgeText: {
                            if (!EmailService.enableUnreadBadges)
                                return "";
                            var count = 0;
                            if (modelData.tab === "all_inboxes") {
                                for (let i = 0; i < EmailService.allInboxesMessages.count; i++) {
                                    if (EmailService.allInboxesMessages.get(i).unread) count++;
                                }
                            } else if (modelData.tab === "inbox")
                                count = EmailService.inboxUnreadCount;
                            else if (modelData.tab === "spam")
                                count = EmailService.spamUnreadCount;
                            else if (modelData.tab === "sent")
                                count = EmailService.sentUnreadCount;
                            else if (modelData.tab === "trash")
                                count = EmailService.trashUnreadCount;
                            else if (modelData.tab === "starred")
                                count = EmailService.starredUnreadCount;
                            else if (modelData.tab === "important")
                                count = EmailService.importantUnreadCount;
                            else if (modelData.tab === "purchases")
                                count = EmailService.purchasesUnreadCount;
                            return count > 0 ? count.toString() : "";
                        }
                    }
                }

                // Labels Header & List
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    visible: !root.compactMode && root._labelButtons.length > 0
                    Layout.topMargin: 8

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: "LABELS"
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Appearance.font.family.main
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        font.letterSpacing: 1.5
                    }
                }

                Repeater {
                    model: root._labelButtons
                    delegate: EmailNavButton {
                        compact: root.compactMode
                        Layout.fillWidth: true
                        enabled: EmailService.authenticated
                        toggled: root.activeTab === "label_" + modelData.id
                        onClicked: root.activeTab = "label_" + modelData.id
                        iconName: "label"
                        label: modelData.name
                        badgeText: (EmailService.enableUnreadBadges && modelData.unread > 0) ? modelData.unread.toString() : ""
                    }
                }
            }
        }

        // ── Rail Specimen Poster (Fills Dead Space in Left Tab) ──
        RyokuDecor {
            visible: !root.compactMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 110
            mode: "vertical"
            art: "wave.gif"
            artRotation: 90
            artScale: 1.0
            artFillMode: Image.PreserveAspectCrop
            code: "CLIENT"
            title: "通信監視"
            sub: "RYOKU DAEMON"
            caption: EmailService.authenticated ? "Gmail sync active on localhost:42069." : "Waiting for Google authentication."
            readout: EmailService.authenticated ? ["NET|ONLINE", "SYNC|IDLE"] : ["AUTH|PENDING", "PORT|42069"]
            seal: "便"
        }

        // ── Search & Settings Footer ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            // Sleek Search Input
            Rectangle {
                id: searchBox
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.normal
                border.width: 1
                border.color: searchInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                Behavior on border.color { ColorAnimation { duration: 100 } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: searchInput.forceActiveFocus()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.compactMode ? 0 : 8
                    anchors.rightMargin: 6
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: "search"
                        iconSize: 16
                        color: searchInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    }

                    TextInput {
                        id: searchInput
                        visible: !root.compactMode
                        Layout.fillWidth: true
                        font.family: Appearance.font.family.main
                        font.pixelSize: 12
                        color: Appearance.colors.colOnSurface
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Translation.tr("Search...")
                            font.pixelSize: 12
                            font.family: Appearance.font.family.main
                            color: Appearance.colors.colOnSurfaceVariant
                            visible: searchInput.text.length === 0 && !searchInput.activeFocus
                        }

                        Keys.onReturnPressed: {
                            if (searchInput.text.trim().length > 0) {
                                EmailService.searchMessages(searchInput.text);
                                root.activeTab = "search";
                            }
                        }
                    }

                    Rectangle {
                        visible: searchInput.text.length > 0 && !root.compactMode
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 4
                        color: Appearance.colors.colPrimary

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "arrow_forward"
                            iconSize: 12
                            color: Appearance.colors.colOnPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (searchInput.text.trim().length > 0) {
                                    EmailService.searchMessages(searchInput.text);
                                    root.activeTab = "search";
                                }
                            }
                        }
                    }
                }
            }

            // Settings Nav Button
            EmailNavButton {
                compact: root.compactMode
                Layout.fillWidth: true
                enabled: EmailService.authenticated
                toggled: root.activeTab === "settings"
                onClicked: root.activeTab = "settings"
                iconName: "settings"
                label: Translation.tr("Settings")
            }
        }
    }
}
