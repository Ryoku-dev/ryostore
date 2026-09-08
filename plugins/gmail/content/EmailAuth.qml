import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root

    readonly property bool configured: EmailService.credentialsConfigured && !root.forceEditMode
    property bool forceEditMode: false

    Component.onCompleted: {
        if (!EmailService.gmailCredentialsTempLoaded) {
            loadGmailCredentialsProc.running = true;
        }
    }

    Process {
        id: loadGmailCredentialsProc
        command: ["python3", (EmailService.instance ? EmailService.instance.binDir : Qt.resolvedUrl("../bin").toString().replace(/^file:\/\//, "")) + "/get_gmail_credentials.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text);
                    EmailService.tempGmailClientId = data.client_id || "";
                    EmailService.tempGmailClientSecret = data.client_secret || "";
                    EmailService.gmailCredentialsTempLoaded = true;
                } catch(e) {
                    console.error("[EmailAuth] Failed to parse existing Gmail credentials");
                }
            }
        }
    }

    property string saveError: ""
    property bool isSaving: false

    Process {
        id: saveGmailCredentialsProc
        onExited: (code) => {
            root.isSaving = false;
            console.log("[EmailAuth] Gmail credentials backup finished with code:", code);
            if (code === 0) {
                EmailService.gmailCredentialsTempLoaded = false;
                root.forceEditMode = false;
                root.saveError = "";
                EmailService.checkCredentials();
            } else {
                root.saveError = Translation.tr("Failed to save credentials file");
            }
        }
    }

    function saveGmailCredentials() {
        root.saveError = "";
        var cid = (clientIdInput ? clientIdInput.inputText : "").trim();
        var sec = (clientSecretInput ? clientSecretInput.inputText : "").trim();

        if (!cid) {
            root.saveError = Translation.tr("Please enter your Client ID");
            return;
        }
        if (!sec) {
            root.saveError = Translation.tr("Please enter your Client Secret");
            return;
        }

        EmailService.tempGmailClientId = cid;
        EmailService.tempGmailClientSecret = sec;
        root.isSaving = true;

        if (typeof KeyringStorage !== "undefined" && KeyringStorage) {
            try {
                KeyringStorage.setNestedFields([
                    { path: ["apiKeys", "gmail_client_id"], value: cid },
                    { path: ["apiKeys", "gmail_client_secret"], value: sec }
                ]);
            } catch(e) {}
        }

        var bin = (EmailService.instance ? EmailService.instance.binDir : Qt.resolvedUrl("../bin").toString().replace(/^file:\/\//, ""));
        saveGmailCredentialsProc.command = ["python3", bin + "/backup_gmail_env.py", cid, sec];
        saveGmailCredentialsProc.running = false;
        saveGmailCredentialsProc.running = true;
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.normal
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STATE 1: CONFIGURED -> READY TO CONNECT WITH GOOGLE
    // ═══════════════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        anchors.margins: 16
        visible: root.configured && !EmailService.loading && !EmailService.checkingCredentials

        RowLayout {
            anchors.fill: parent
            spacing: 14

            // Left Side: Action Card
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 320
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 36, 340)
                    spacing: 16

                    // App Icon Badge
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 48
                        height: 48
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colPrimaryContainer
                        border.width: 1
                        border.color: Appearance.colors.colPrimary

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "mail"
                            iconSize: 24
                            color: Appearance.colors.colPrimary
                        }
                    }

                    // Section Pip + Title
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6

                            Rectangle {
                                width: 4
                                height: 4
                                color: Appearance.colors.colPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: EmailService.authenticating ? "WAITING FOR BROWSER" : "CONNECT ACCOUNT"
                                color: Appearance.colors.colOnSurface
                                font.family: Appearance.font.family.main
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.letterSpacing: 2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: EmailService.authenticating
                                ? Translation.tr("Complete Google sign-in in your web browser")
                                : Translation.tr("Sign in to sync your inbox, tags and threads")
                            font.family: Appearance.font.family.main
                            font.pixelSize: 12
                            color: Appearance.colors.colOnSurfaceVariant
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Connect Action Button
                    Rectangle {
                        id: connectBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: Appearance.rounding.normal
                        color: EmailService.authenticating
                            ? Appearance.colors.colLayer2
                            : (readyMouseArea.pressed ? Appearance.colors.colPrimaryActive
                                : (readyMouseArea.containsMouse ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary))
                        border.width: 1
                        border.color: EmailService.authenticating ? Appearance.colors.colOutline : Appearance.colors.colPrimaryActive
                        enabled: !EmailService.authenticating

                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            MaterialSymbol {
                                text: EmailService.authenticating ? "hourglass_empty" : "open_in_browser"
                                iconSize: 16
                                color: EmailService.authenticating ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnPrimary

                                RotationAnimation on rotation {
                                    running: EmailService.authenticating
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                }
                            }

                            StyledText {
                                text: EmailService.authenticating ? Translation.tr("Authorizing...") : Translation.tr("Connect with Google")
                                font.family: Appearance.font.family.main
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: EmailService.authenticating ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnPrimary
                            }
                        }

                        MouseArea {
                            id: readyMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: EmailService.startOAuth()
                        }
                    }

                    // Edit Credentials Link
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                text: "edit"
                                iconSize: 13
                                color: Appearance.colors.colOnSurfaceVariant
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: Translation.tr("Edit API credentials")
                                font.family: Appearance.font.family.main
                                font.pixelSize: 11
                                color: editMouse.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: editMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.forceEditMode = true
                        }
                    }

                    // Browser Warning Guidance Card
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: browserTipCol.implicitHeight + 14
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        ColumnLayout {
                            id: browserTipCol
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            RowLayout {
                                spacing: 6
                                MaterialSymbol {
                                    text: "info"
                                    iconSize: 14
                                    color: Appearance.colors.colPrimary
                                }
                                Text {
                                    text: "BROWSER SIGN-IN TIP"
                                    color: Appearance.colors.colPrimary
                                    font.family: Appearance.font.family.mono
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "When Google displays 'Google hasn't verified this app' in your browser: click 'Show advanced' → 'Go to [Project Name] (unsafe)', and grant all requested permissions to complete setup."
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Appearance.font.family.main
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Standby Telemetry Plate (Full Container & Border Intact)
                    RyokuDecor {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        implicitHeight: 140
                        mode: "horizontal"
                        art: "wave.gif"
                        code: "NET-01"
                        title: "通信待機"
                        sub: "LISTENER STANDBY"
                        caption: "Local server active on 127.0.0.1:42069. Complete sign-in in browser."
                        readout: ["PORT|42069", "CIPHER|TLS 1.3", "STATE|READY"]
                        seal: "便"
                    }
                }
            }

            // Right Side: Signature Ryoku Specimen Poster
            RyokuDecor {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.round(parent.width * 0.45)
                mode: "vertical"
                art: "earth.gif"
                code: "AUTH-01"
                title: "交信"
                sub: "AUTHENTICATION"
                caption: "OAuth 2.0 PKCE handshake active on 127.0.0.1:42069. Tokens remain strictly local."
                readout: ["PORT|42069 PKCE", "CIPHER|TLS 1.3", "STATE|READY", "STORE|LOCAL 0600"]
                seal: "便"
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STATE 2: UNCONFIGURED (OR EDIT MODE) -> SETUP CREDENTIALS
    // ═══════════════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        anchors.margins: 12
        visible: (!root.configured || root.forceEditMode) && !EmailService.loading && !EmailService.checkingCredentials

        RowLayout {
            anchors.fill: parent
            spacing: 12

            // Left Side: Step-by-Step Instructions, Inputs & Vault Filler
            StyledFlickable {
                id: setupFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: setupCol.implicitHeight + 24
                clip: true

                ScrollBar.vertical: StyledScrollBar {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }

                ColumnLayout {
                    id: setupCol
                    width: setupFlickable.width - 14
                    spacing: 10

                    // Header with Ryoku Pip
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: 4
                            height: 4
                            color: Appearance.colors.colPrimary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: "GOOGLE OAUTH SETUP GUIDE"
                            color: Appearance.colors.colOnSurface
                            font.family: Appearance.font.family.main
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.letterSpacing: 2
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "7 STEPS"
                            color: Appearance.colors.colPrimary
                            font.family: Appearance.font.family.mono
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Rectangle {
                            visible: EmailService.authenticated
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: backText.implicitWidth + 14
                            radius: 3
                            color: backMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                            border.width: 1
                            border.color: Appearance.colors.colOutlineVariant

                            Text {
                                id: backText
                                anchors.centerIn: parent
                                text: "← Back to Mailbox"
                                color: Appearance.colors.colPrimary
                                font.family: Appearance.font.family.main
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: backMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.forceEditMode = false;
                                    root.parent.parent.activeTab = "inbox";
                                }
                            }
                        }
                    }

                    // Detailed Steps Card
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: stepsCol.implicitHeight + 16
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        ColumnLayout {
                            id: stepsCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Repeater {
                                model: [
                                    {
                                        "step": "1",
                                        "title": "Create a Google Cloud Project",
                                        "desc": "Go to the Google Cloud Console. Click the 'Select a project' dropdown at the top of the page, click 'New Project', give it a name (e.g. 'Ryoku Mail'), and click Create.",
                                        "url": "https://console.cloud.google.com/projectcreate",
                                        "urlText": "Console ↗"
                                    },
                                    {
                                        "step": "2",
                                        "title": "Enable the Gmail API",
                                        "desc": "In the left panel, select APIs & Services → Library. Search for 'Gmail API' and click Enable.",
                                        "url": "https://console.cloud.google.com/apis/library/gmail.googleapis.com",
                                        "urlText": "Gmail API ↗"
                                    },
                                    {
                                        "step": "3",
                                        "title": "Start OAuth Consent Screen Setup",
                                        "desc": "On the same Gmail API screen, click 'Credentials' (in the center page, not the left panel). Click 'Create Credentials' → 'OAuth client ID' → 'Configure consent screen' > 'Get started'.",
                                        "url": "https://console.cloud.google.com/apis/credentials/consent",
                                        "urlText": "Consent ↗"
                                    },
                                    {
                                        "step": "4",
                                        "title": "Fill App Information & Create",
                                        "desc": "Fill in the required fields: App name, User support email, and Developer contact information. Click 'Save and Continue', agree to the policy, and click 'Create'.",
                                        "url": "https://console.cloud.google.com/apis/credentials/consent",
                                        "urlText": "Details ↗"
                                    },
                                    {
                                        "step": "5",
                                        "title": "Create Desktop App Credentials",
                                        "desc": "Return to the main dashboard and select Gmail API → Manage → Credentials (center page, not left panel). Click 'Create Credentials' → 'OAuth client ID'. Choose 'Desktop App' type from the dropdown, enter a client name, and click Create.",
                                        "url": "https://console.cloud.google.com/apis/credentials/oauthclient",
                                        "urlText": "Create Keys ↗"
                                    },
                                    {
                                        "step": "6",
                                        "title": "Save Your Keys Below",
                                        "desc": "A popup will appear displaying your Client ID and Client Secret. Copy and paste them into the input fields below, then click 'Save Credentials & Continue'.",
                                        "url": "https://console.cloud.google.com/apis/credentials",
                                        "urlText": "Credentials ↗"
                                    },
                                    {
                                        "step": "7",
                                        "title": "Authorize & Grant Permissions in Browser",
                                        "desc": "Click 'Connect with Google'. The setup screen will open in your browser. Select your Gmail account. When Google displays a warning ('Google hasn't verified this app'), click 'Show advanced' → 'Go to [Your Project Name] (unsafe)', grant all requested permissions, and that will set it up!",
                                        "url": "",
                                        "urlText": ""
                                    }
                                ]

                                delegate: RowLayout {
                                    spacing: 8
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    Layout.bottomMargin: 2

                                    Rectangle {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.topMargin: 2
                                        width: 18
                                        height: 18
                                        radius: 3
                                        color: Appearance.colors.colPrimaryContainer
                                        border.width: 1
                                        border.color: Appearance.colors.colPrimary

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: modelData.step
                                            color: Appearance.colors.colPrimary
                                            font.family: Appearance.font.family.mono
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text {
                                                text: modelData.title
                                                color: Appearance.colors.colOnSurface
                                                font.family: Appearance.font.family.main
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                visible: modelData.url !== ""
                                                text: modelData.urlText
                                                color: Appearance.colors.colPrimary
                                                font.family: Appearance.font.family.mono
                                                font.pixelSize: 9
                                                font.weight: Font.Medium

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Qt.openUrlExternally(modelData.url)
                                                }
                                            }
                                        }

                                        Text {
                                            text: modelData.desc
                                            color: Appearance.colors.colOnSurfaceVariant
                                            font.family: Appearance.font.family.main
                                            font.pixelSize: 10
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Input Fields Card
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: inputsCol.implicitHeight + 14
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        ColumnLayout {
                            id: inputsCol
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            ConfigTextField {
                                id: clientIdInput
                                text: Translation.tr("Client ID")
                                icon: "key"
                                placeholderText: Translation.tr("Paste Client ID (ends with .apps.googleusercontent.com)")
                                inputText: EmailService.tempGmailClientId
                                onInputTextChanged: {
                                    EmailService.tempGmailClientId = clientIdInput.inputText;
                                    root.saveError = "";
                                }
                            }

                            ConfigTextField {
                                id: clientSecretInput
                                text: Translation.tr("Client Secret")
                                icon: "lock"
                                placeholderText: Translation.tr("Paste Client Secret (starts with GOCSPX-)")
                                inputText: EmailService.tempGmailClientSecret
                                onInputTextChanged: {
                                    EmailService.tempGmailClientSecret = clientSecretInput.inputText;
                                    root.saveError = "";
                                }
                            }

                            // Error validation feedback
                            Text {
                                visible: root.saveError !== ""
                                text: root.saveError
                                color: Appearance.colors.colError
                                font.family: Appearance.font.family.main
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    visible: root.forceEditMode
                                    Layout.preferredWidth: 80
                                    Layout.preferredHeight: 32
                                    radius: Appearance.rounding.normal
                                    color: Appearance.colors.colLayer2
                                    border.width: 1
                                    border.color: Appearance.colors.colOutlineVariant

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: Translation.tr("Cancel")
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: 11
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.forceEditMode = false
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: Appearance.rounding.normal
                                    color: root.isSaving ? Appearance.colors.colLayer2
                                        : (saveMouse.pressed ? Appearance.colors.colPrimaryActive
                                            : (saveMouse.containsMouse ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary))
                                    border.width: 1
                                    border.color: root.isSaving ? Appearance.colors.colOutline : Appearance.colors.colPrimaryActive
                                    enabled: !root.isSaving

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MaterialSymbol {
                                            text: root.isSaving ? "hourglass_empty" : "save"
                                            iconSize: 14
                                            color: root.isSaving ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnPrimary

                                            RotationAnimation on rotation {
                                                running: root.isSaving
                                                from: 0
                                                to: 360
                                                duration: 1000
                                                loops: Animation.Infinite
                                            }
                                        }

                                        StyledText {
                                            text: root.isSaving ? Translation.tr("Saving Credentials...") : Translation.tr("Save Credentials & Continue")
                                            font.family: Appearance.font.family.main
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: root.isSaving ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnPrimary
                                        }
                                    }

                                    MouseArea {
                                        id: saveMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.saveGmailCredentials()
                                    }
                                }
                            }
                        }
                    }

                    // Vault & Privacy Plate (Full GIF & Full Container)
                    RyokuDecor {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        implicitHeight: 140
                        mode: "horizontal"
                        art: "render.gif"
                        code: "VAULT-01"
                        title: "安全性"
                        sub: "LOCAL CREDENTIAL VAULT"
                        caption: "API credentials are saved to ~/.config/ryoku/gmail.env (0600 permissions). Zero cloud relays or telemetry."
                        readout: ["STORAGE|LOCAL ONLY", "SECURITY|PKCE", "PERM|0600"]
                        seal: "護"
                    }
                }
            }

            // Right Side: Ryoku Placard Specimen Poster for Setup
            RyokuDecor {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.round(parent.width * 0.42)
                mode: "vertical"
                art: "compass.gif"
                code: "SETUP-00"
                title: "初期設定"
                sub: "GOOGLE CLOUD"
                caption: "Provide desktop app OAuth keys to communicate with Gmail API. Keys are written to ~/.config/ryoku/gmail.env."
                readout: ["API|GMAIL v1", "AUTH|UNCONFIGURED", "STORE|LOCAL", "FLOW|PKCE"]
                seal: "鍵"
            }
        }
    }
}
