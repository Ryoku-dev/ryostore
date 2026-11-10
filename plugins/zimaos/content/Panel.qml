pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// ZimaOS device card. Same facts as the Zima client card: name, link rates,
// address, dashboard, storage, backup, and PeerDrop.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 380
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property real w: widthBudget > 0 ? widthBudget : 380

    implicitWidth: root.w
    implicitHeight: col.implicitHeight

    I18n { id: i18n }

    property string formError: ""

    // The shell already draws the card: the same stroked glass as the
    // now-playing panel. These are the chip tints that sit on it.
    readonly property color ink: Theme.cream
    readonly property color sumi: Theme.dim
    readonly property color seal: Theme.accent
    readonly property color sep: Theme.border
    readonly property color fillIdle: Qt.rgba(0, 0, 0, 0.12)
    readonly property color fillHover: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
    readonly property color fillActive: Theme.accent

    onActiveChanged: {
        if (!root.active) {
            passField.text = "";
            root.formError = "";
        } else {
            root.fillAddress();
        }
    }

    component Card: Rectangle {
        property real pad: 12
        radius: 16
        color: root.fillIdle
        border.width: 1
        border.color: root.sep
    }

    // Gear and the PeerDrop person are not in the shell glyph set.
    component LineIcon: Item {
        id: mark
        property string name: ""
        property color color: Theme.iconDim
        property real stroke: 1.6

        readonly property var paths: ({
            "peer": "M10.4 8.3a2.2 2.2 0 1 1-4.4 0 2.2 2.2 0 0 1 4.4 0 M4.1 18c.6-2.6 2-3.9 4.1-3.9s3.5 1.3 4.1 3.9 M14.4 9.2a2.6 2.6 0 0 1 0 3.8 M16.6 7.1a5.4 5.4 0 0 1 0 8",
            "globe": "M12 3.2a8.8 8.8 0 1 0 0 17.6 8.8 8.8 0 0 0 0-17.6z M3.2 12h17.6 M12 3.2c2.3 2.5 3.5 5.6 3.5 8.8s-1.2 6.3-3.5 8.8c-2.3-2.5-3.5-5.6-3.5-8.8s1.2-6.3 3.5-8.8z",
            "bolt": "M13.2 2.8 6 13.2h5.2L10 21.2 18.4 10.2h-5.5z",
            "gear": "M12 15.2a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4z M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"
        })
        readonly property string d: mark.paths[mark.name] !== undefined ? mark.paths[mark.name] : ""
        readonly property real u: Math.min(width, height) / 24

        Shape {
            width: 24
            height: 24
            scale: mark.u
            transformOrigin: Item.TopLeft
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: mark.color
                fillColor: "transparent"
                strokeWidth: mark.stroke
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: mark.d }
            }
        }
    }

    // Remote, Wi-Fi, Ethernet, Thunderbolt. Accent is the path in use.
    component PathMark: Item {
        id: path
        property string line: ""
        property string glyph: ""
        property string pathName: ""
        property string title: ""

        readonly property string activeName: root.service ? root.service.linkActive : ""
        readonly property bool onPath: path.activeName === path.pathName
                || (path.activeName === "lan" && (path.pathName === "wifi" || path.pathName === "ethernet"))
        readonly property bool up: {
            if (!root.service)
                return false;
            if (path.pathName === "remote")
                return root.service.linkRemote;
            if (path.pathName === "wifi")
                return root.service.linkWifi;
            if (path.pathName === "ethernet")
                return root.service.linkEthernet;
            return root.service.linkThunderbolt;
        }

        width: 14 * root.s
        height: 14 * root.s

        LineIcon {
            anchors.fill: parent
            visible: path.line.length > 0
            name: path.line
            color: path.onPath ? root.seal : (path.up ? root.ink : root.sumi)
            opacity: path.onPath ? 1 : (path.up ? 0.85 : 0.34)
            stroke: 1.6
        }
        GlyphIcon {
            anchors.fill: parent
            visible: path.glyph.length > 0
            name: path.glyph
            color: path.onPath ? root.seal : (path.up ? root.ink : root.sumi)
            opacity: path.onPath ? 1 : (path.up ? 0.85 : 0.34)
            stroke: 1.6
        }

        MouseArea {
            id: pathHover
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            ToolTip.visible: pathHover.containsMouse
            ToolTip.delay: 350
            ToolTip.text: {
                var label = i18n.tr(path.title);
                if (path.onPath)
                    return label + " · " + i18n.tr("In use");
                if (path.up)
                    return label + " · " + i18n.tr("Available");
                return label;
            }
        }
    }

    Column {
        id: col
        width: root.w
        spacing: 14 * root.s

        Item {
            width: parent.width
            implicitHeight: nameText.implicitHeight

            Text {
                id: nameText
                anchors.left: parent.left
                anchors.right: logoutMark.left
                anchors.rightMargin: 12 * root.s
                text: {
                    if (!root.service || !root.service.authed)
                        return "ZimaOS";
                    if (root.service.deviceName.length > 0)
                        return root.service.deviceName;
                    return root.service.online ? "ZimaOS" : i18n.tr("Offline");
                }
                color: root.ink
                font.family: Theme.mono
                font.pixelSize: 18 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            GlyphIcon {
                id: logoutMark
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.service && root.service.authed
                width: 16 * root.s
                height: 16 * root.s
                name: "logout"
                color: logoutMa.containsMouse ? root.ink : root.sumi
                stroke: 1.6

                MouseArea {
                    id: logoutMa
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.service) root.service.logout()
                }
            }
        }

        Item {
            visible: root.service && root.service.deviceImage.length > 0
            width: parent.width
            implicitHeight: 148 * root.s

            Image {
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.72, 210 * root.s)
                height: 132 * root.s
                source: root.service && root.service.deviceImage.length > 0
                        ? ("file://" + root.service.deviceImage) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
        }

        Text {
            visible: root.service && root.service.authed && root.service.errorText.length > 0
            width: parent.width
            text: root.service ? root.service.errorText : ""
            color: Theme.sun
            font.family: Theme.mono
            font.pixelSize: 11 * root.s
            wrapMode: Text.WordWrap
        }

        Column {
            visible: root.service && root.service.authed
            width: parent.width
            spacing: 8 * root.s

            Item {
                width: parent.width
                implicitHeight: lanText.implicitHeight

                Text {
                    id: lanText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: i18n.tr(root.service && root.service.ifaceLabel.length > 0
                                  ? root.service.ifaceLabel : "LAN")
                    color: root.ink
                    font.family: Theme.mono
                    font.pixelSize: 12 * root.s
                    font.weight: Font.Medium
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10 * root.s

                    PathMark { line: "globe"; pathName: "remote"; title: "Remote" }
                    PathMark { glyph: "wifi"; pathName: "wifi"; title: "Wi-Fi" }
                    PathMark { glyph: "reboot"; pathName: "ethernet"; title: "Ethernet" }
                    PathMark { line: "bolt"; pathName: "thunderbolt"; title: "Thunderbolt" }
                }
            }

            Item {
                width: parent.width
                implicitHeight: Math.max(ipText.implicitHeight, dashBtn.height)

                Text {
                    id: ipText
                    anchors.left: parent.left
                    anchors.right: dashBtn.left
                    anchors.rightMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.service && root.service.ipAddress.length > 0 ? root.service.ipAddress : ""
                    color: root.sumi
                    font.family: Theme.mono
                    font.pixelSize: 12 * root.s
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: dashBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: dashLabel.implicitWidth + 16 * root.s
                    height: dashLabel.implicitHeight + 10 * root.s
                    radius: height / 2
                    color: dashMa.containsMouse ? Theme.vermDeep : root.seal
                    border.width: 0

                    Text {
                        id: dashLabel
                        anchors.centerIn: parent
                        text: i18n.tr("Go to Dashboard")
                        color: Theme.cardBot
                        font.family: Theme.mono
                        font.pixelSize: 10 * root.s
                        font.weight: Font.Medium
                        font.letterSpacing: 0.4
                    }

                    MouseArea {
                        id: dashMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openLink(root.service ? root.service.dashboardUrl : "")
                    }
                }
            }
        }

        Card {
            id: diskCard
            visible: root.service && root.service.authed
            width: parent.width
            implicitHeight: 104 * root.s
            color: diskMa.containsMouse ? root.fillHover : root.fillIdle
            border.color: diskMa.containsMouse ? root.seal : root.sep

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.right: folderMark.left
                anchors.leftMargin: 16 * root.s
                anchors.topMargin: 14 * root.s
                anchors.rightMargin: 8 * root.s
                text: i18n.tr("Open") + " " + (root.service && root.service.storageTitle.length > 0
                      ? root.service.storageTitle
                      : i18n.tr("storage"))
                color: root.ink
                font.family: Theme.mono
                font.pixelSize: 13 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            LineIcon {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16 * root.s
                anchors.bottomMargin: 14 * root.s
                width: 18 * root.s
                height: 18 * root.s
                name: "gear"
                color: root.sumi
                stroke: 1.6
            }

            GlyphIcon {
                id: folderMark
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 18 * root.s
                width: 36 * root.s
                height: 36 * root.s
                name: "folder"
                color: diskMa.containsMouse ? root.ink : root.sumi
                stroke: 1.5
            }

            MouseArea {
                id: diskMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openLink(root.service ? root.service.filesUrl : "")
            }
        }

        Row {
            visible: root.service && root.service.authed
            width: parent.width
            spacing: 10 * root.s

            Card {
                id: backupCard
                width: (parent.width - parent.spacing) / 2
                implicitHeight: 108 * root.s
                color: backupMa.containsMouse ? root.fillHover : root.fillIdle
                border.color: backupMa.containsMouse ? root.seal : root.sep

                GlyphIcon {
                    x: 16 * root.s
                    y: 16 * root.s
                    width: 20 * root.s
                    height: 20 * root.s
                    name: "reboot"
                    color: backupMa.containsMouse ? root.ink : root.sumi
                    stroke: 1.6
                }

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 16 * root.s
                    anchors.bottomMargin: 14 * root.s
                    text: i18n.tr("Backup")
                    color: root.ink
                    font.family: Theme.mono
                    font.pixelSize: 12 * root.s
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: backupMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.service)
                            return;
                        var url = root.service.backupUrl.length > 0
                                ? root.service.backupUrl
                                : root.service.dashboardUrl;
                        root.openLink(url);
                    }
                }
            }

            Card {
                id: peerCard
                width: (parent.width - parent.spacing) / 2
                implicitHeight: 108 * root.s
                color: peerMa.containsMouse ? root.fillHover : root.fillIdle
                border.color: peerMa.containsMouse ? root.seal : root.sep

                LineIcon {
                    x: 16 * root.s
                    y: 16 * root.s
                    width: 20 * root.s
                    height: 20 * root.s
                    name: "peer"
                    color: peerMa.containsMouse ? root.ink : root.sumi
                    stroke: 1.6
                }

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 16 * root.s
                    anchors.bottomMargin: 14 * root.s
                    text: i18n.tr("PeerDrop")
                    color: root.ink
                    font.family: Theme.mono
                    font.pixelSize: 12 * root.s
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: peerMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openLink(root.service ? root.service.peerDropUrl : "")
                }
            }
        }

        Column {
            width: parent.width
            spacing: 8 * root.s
            visible: root.service && !root.service.authed

            Text {
                width: parent.width
                text: {
                    if (root.formError.length > 0)
                        return root.formError;
                    if (!root.service)
                        return "";
                    if (root.service.authError === "session expired")
                        return i18n.tr("Session expired");
                    if (root.service.authError === "username and password are required")
                        return i18n.tr("Enter the username and the password.");
                    if (root.service.authError === "login failed" || root.service.authError === "invalid login payload")
                        return i18n.tr("Could not sign in.");
                    if (root.service.authError.length > 0)
                        return root.service.authError;
                    return root.service.errorText;
                }
                visible: text.length > 0
                color: Theme.sun
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
                wrapMode: Text.WordWrap
            }

            Text {
                text: i18n.tr("IP")
                color: root.sumi
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1
                font.capitalization: Font.AllUppercase
            }

            TextField {
                id: ipField
                width: parent.width
                placeholderText: "192.168.0.180"
                color: root.ink
                placeholderTextColor: root.sumi
                font.family: Theme.mono
                font.pixelSize: 12 * root.s
                padding: 8 * root.s
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                background: Rectangle {
                    radius: 6
                    color: root.fillIdle
                    border.width: 1
                    border.color: ipField.activeFocus ? root.seal : root.sep
                }
                onAccepted: root.submitLogin()
            }

            Text {
                text: i18n.tr("Username")
                color: root.sumi
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1
                font.capitalization: Font.AllUppercase
            }

            TextField {
                id: userField
                width: parent.width
                placeholderText: i18n.tr("Username")
                color: root.ink
                placeholderTextColor: root.sumi
                font.family: Theme.mono
                font.pixelSize: 12 * root.s
                padding: 8 * root.s
                background: Rectangle {
                    radius: 6
                    color: root.fillIdle
                    border.width: 1
                    border.color: userField.activeFocus ? root.seal : root.sep
                }
            }

            Text {
                text: i18n.tr("Password")
                color: root.sumi
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1
                font.capitalization: Font.AllUppercase
            }

            TextField {
                id: passField
                width: parent.width
                placeholderText: i18n.tr("Password")
                echoMode: TextInput.Password
                color: root.ink
                placeholderTextColor: root.sumi
                font.family: Theme.mono
                font.pixelSize: 12 * root.s
                padding: 8 * root.s
                background: Rectangle {
                    radius: 6
                    color: root.fillIdle
                    border.width: 1
                    border.color: passField.activeFocus ? root.seal : root.sep
                }
                onAccepted: root.submitLogin()
            }

            Rectangle {
                width: parent.width
                height: signLabel.implicitHeight + 12 * root.s
                radius: 6
                color: signMa.containsMouse ? Theme.vermDeep : Theme.accent
                border.width: 0

                Text {
                    id: signLabel
                    anchors.centerIn: parent
                    text: root.service && root.service.busy ? i18n.tr("Connecting") : i18n.tr("Sign in")
                    color: Theme.cardBot
                    font.family: Theme.mono
                    font.pixelSize: 11 * root.s
                    font.weight: Font.Medium
                    font.letterSpacing: 1
                }

                MouseArea {
                    id: signMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitLogin()
                }
            }
        }

        Row {
            width: parent.width
            visible: root.service && root.service.authed
            spacing: 8 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - signOut.implicitWidth - 8 * root.s
                text: root.service ? root.service.username : ""
                color: root.sumi
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1
                elide: Text.ElideRight
            }

            Text {
                id: signOut
                anchors.verticalCenter: parent.verticalCenter
                text: i18n.tr("Sign out")
                color: signOutMa.containsMouse ? root.ink : root.sumi
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1

                MouseArea {
                    id: signOutMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        passField.text = "";
                        if (root.service)
                            root.service.logout();
                    }
                }
            }
        }
    }

    readonly property string watchedHost: root.service && root.service.host ? root.service.host : ""
    readonly property string watchedUser: root.service && root.service.username ? root.service.username : ""
    onWatchedHostChanged: root.fillAddress()
    onWatchedUserChanged: {
        if (userField.text.length === 0 && root.watchedUser.length > 0)
            userField.text = root.watchedUser;
    }

    function openLink(url) {
        if (!root.service || !url)
            return;
        if (url.indexOf("http://") !== 0 && url.indexOf("https://") !== 0)
            return;
        root.service.openUrl(url);
        if (root.pluginApi)
            root.pluginApi.closePanel();
    }

    function fillAddress() {
        if (ipField.text.length === 0 && root.service && root.service.host.length > 0)
            ipField.text = root.service.host;
    }

    function submitLogin() {
        if (!root.service || root.service.busy)
            return;
        var addr = ipField.text.trim();
        if (addr.length === 0) {
            root.formError = i18n.tr("Enter the ZimaOS address.");
            return;
        }
        if (root.service.normalizeHost(addr) === "") {
            root.formError = i18n.tr("That address is not valid. Use a hostname or IPv4, with an optional port.");
            return;
        }
        if (userField.text.trim().length === 0 || passField.text.length === 0) {
            root.formError = i18n.tr("Enter the username and the password.");
            return;
        }
        root.formError = "";
        if (!root.service.useHost(addr))
            return;
        root.service.login(userField.text.trim(), passField.text);
        passField.text = "";
    }
}
