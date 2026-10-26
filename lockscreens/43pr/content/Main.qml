import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width: 1280
    height: 720
    color: "#050505"
    readonly property real s: Math.max(0.6, Math.min(width / 1280, height / 720))
    property date now: new Date()
    property bool authenticating: false
    property string errorMessage: ""

    function submit() {
        if (authenticating || password.text.length === 0)
            return;
        if (typeof sddm === "undefined") {
            errorMessage = "Preview only — authentication unavailable";
            password.clear();
            return;
        }
        authenticating = true;
        errorMessage = "";
        const secret = password.text;
        password.clear();
        sddm.login(typeof userModel !== "undefined" ? userModel.lastUser : "", secret, 0);
    }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Component.onCompleted: password.forceActiveFocus()

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 85 * root.s
        spacing: 20 * root.s
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "HH:mm")
            color: "white"
            font.family: "monospace"
            font.pixelSize: 60 * root.s
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, dd MMMM yyyy")
            color: "white"
            font.family: "monospace"
            font.pixelSize: 16 * root.s
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(root.width - 40, 320 * root.s)
        height: 48 * root.s
        radius: 25 * root.s
        color: "transparent"
        border.color: root.errorMessage ? "#ff6b81" : "white"
        border.width: 3 * root.s

        TextField {
            id: password
            objectName: "password"
            anchors.fill: parent
            anchors.margins: 4 * root.s
            background: Item {}
            color: "#c8c8c8"
            placeholderText: root.authenticating ? "Authenticating…" : "Password"
            placeholderTextColor: "#c8c8c8"
            echoMode: TextInput.Password
            font.family: "monospace"
            font.pixelSize: 16 * root.s
            horizontalAlignment: Text.AlignHCenter
            enabled: !root.authenticating
            Accessible.name: "Password"
            onAccepted: root.submit()
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 + 45 * root.s
        width: parent.width - 40
        text: root.errorMessage
        color: "#ff6b81"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        font.pixelSize: 14 * root.s
        Accessible.role: Accessible.AlertMessage
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            root.authenticating = false;
            root.errorMessage = "Authentication failed. Try again.";
            password.clear();
            password.forceActiveFocus();
        }
    }
}
