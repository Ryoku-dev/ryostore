pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

// Desktop tile: pin any URL as a QR over the wallpaper. When pinned, the
// widget is exactly square (same side as the code). Edit chrome overlays on
// hover so it does not stretch the card. Exposes `editing` so the desktop
// layer grabs the keyboard while the field is focused.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0
    property bool open: false
    property real reveal: 0
    property bool tabActive: false
    signal requestClose()

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool hasPin: service ? service.hasPin : false
    readonly property string url: service ? service.url : ""
    readonly property string displayHost: service ? service.displayHost : ""
    readonly property string imagePath: service ? service.imagePath : ""
    readonly property int imageGen: service ? service.imageGen : 0
    readonly property string error: service ? service.error : ""
    readonly property bool busy: service ? service.busy : false

    // Explicit editing flag — a hidden urlField cannot take focus, so EDIT
    // must show the editor before forceActiveFocus.
    property bool editing: false
    readonly property bool showEditor: !root.hasPin || root.editing || root.error.length > 0

    // One side length — width and height match so the host card stays square.
    readonly property real side: {
        if (widthBudget > 0)
            return widthBudget;
        return 200 * s;
    }

    function fileUrl(path) {
        var parts = String(path).split("/");
        var out = [];
        for (var i = 0; i < parts.length; i++)
            out.push(encodeURIComponent(parts[i]));
        return "file://" + out.join("/");
    }

    implicitWidth: side
    implicitHeight: side

    // --- pinned: square QR fills the tile ---
    Rectangle {
        id: qrPlate
        anchors.fill: parent
        visible: root.hasPin
        radius: Theme.radius
        color: Theme.cream

        Image {
            anchors.fill: parent
            anchors.margins: 10 * root.s
            source: root.imagePath.length > 0
                ? (root.fileUrl(root.imagePath) + "?v=" + root.imageGen)
                : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: false
        }

        // Hover strip: edit / clear without growing the tile.
        Rectangle {
            id: hoverBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8 * root.s
            height: 32 * root.s
            radius: Theme.radius
            color: Qt.rgba(0, 0, 0, 0.55)
            opacity: (qrHover.hovered || root.editing) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Row {
                anchors.centerIn: parent
                spacing: 12 * root.s

                Text {
                    text: "EDIT"
                    color: Theme.cream
                    font.family: Theme.mono
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.4 * root.s
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            urlField.text = root.url;
                            root.editing = true;
                            urlField.forceActiveFocus();
                            urlField.selectAll();
                        }
                    }
                }
                Text {
                    text: "CLEAR"
                    color: Theme.cream
                    font.family: Theme.mono
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.4 * root.s
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            urlField.text = "";
                            if (root.service)
                                root.service.clear();
                        }
                    }
                }
            }
        }

        HoverHandler { id: qrHover }
    }

    // --- empty / editing: square composer ---
    Item {
        anchors.fill: parent
        visible: root.showEditor

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.sheen
            border.width: 1
            border.color: Theme.lineStrong
            visible: !root.hasPin
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12 * root.s
            spacing: 10 * root.s

            Text {
                width: parent.width
                text: "QR PIN"
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 15 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.4 * root.s
            }

            Text {
                width: parent.width
                text: root.busy ? "encoding…" : (root.error.length > 0 ? root.error : "paste or type a url")
                color: root.error.length > 0 ? Theme.accent : Theme.faint
                font.family: Theme.mono
                font.pixelSize: 12 * root.s
                font.letterSpacing: 1.0 * root.s
                font.capitalization: Font.AllUppercase
                wrapMode: Text.Wrap
            }

            // Fill the middle of the square so the field sits in a QR-sized area.
            Item {
                width: parent.width
                height: parent.height - 12 * root.s - 15 * root.s - 12 * root.s
                    - 34 * root.s - 28 * root.s - 44 * root.s

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    radius: Theme.radius
                    color: root.hasPin ? "transparent" : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Theme.lineStrong
                    visible: !root.hasPin

                    Text {
                        anchors.centerIn: parent
                        text: "qr_code_2"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 48 * root.s
                        font.weight: 400
                        renderType: Text.QtRendering
                        color: Theme.dim
                    }
                }
            }

            Rectangle {
                id: urlBox
                width: parent.width
                height: 34 * root.s
                radius: Theme.radius
                color: urlField.activeFocus ? Theme.sheen : "transparent"
                border.width: 1
                border.color: Theme.lineStrong

                TextInput {
                    id: urlField
                    anchors.fill: parent
                    anchors.leftMargin: 10 * root.s
                    anchors.rightMargin: 10 * root.s
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.cream
                    selectedTextColor: Theme.ink
                    selectionColor: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 14 * root.s
                    clip: true
                    selectByMouse: true
                    text: root.service ? root.service.draft : ""
                    onTextChanged: {
                        if (root.service && root.service.draft !== text)
                            root.service.draft = text;
                    }
                    onActiveFocusChanged: {
                        if (!activeFocus && root.hasPin)
                            root.editing = false;
                    }
                    Keys.onReturnPressed: urlBox.commitUrl()
                    Keys.onEnterPressed: urlBox.commitUrl()
                    Keys.onEscapePressed: {
                        urlField.text = root.url;
                        root.editing = false;
                        urlField.focus = false;
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: urlField.text.length === 0 && !urlField.activeFocus
                        text: "link or paste…"
                        color: Theme.dim
                        font: urlField.font
                    }
                }

                function commitUrl() {
                    if (!root.service)
                        return;
                    root.service.setUrl(urlField.text);
                    root.editing = false;
                    urlField.focus = false;
                }

                TapHandler { onTapped: urlField.forceActiveFocus() }
            }

            Row {
                width: parent.width
                spacing: 8 * root.s

                Rectangle {
                    width: pasteText.implicitWidth + 20 * root.s
                    height: 28 * root.s
                    radius: Theme.radius
                    color: pasteHover.hovered ? Theme.sheen : "transparent"
                    border.width: 1
                    border.color: Theme.lineStrong

                    Text {
                        id: pasteText
                        anchors.centerIn: parent
                        text: "PASTE"
                        color: Theme.accent
                        font.family: Theme.mono
                        font.pixelSize: 12 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.4 * root.s
                    }
                    HoverHandler { id: pasteHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: if (root.service) root.service.paste() }
                }

                Rectangle {
                    width: pinText.implicitWidth + 20 * root.s
                    height: 28 * root.s
                    radius: Theme.radius
                    color: pinHover.hovered ? Theme.sheen : "transparent"
                    border.width: 1
                    border.color: Theme.lineStrong

                    Text {
                        id: pinText
                        anchors.centerIn: parent
                        text: "PIN"
                        color: Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: 12 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.4 * root.s
                    }
                    HoverHandler { id: pinHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (!root.service)
                                return;
                            root.service.setUrl(urlField.text);
                            root.editing = false;
                            urlField.focus = false;
                        }
                    }
                }

                Rectangle {
                    width: clearText.implicitWidth + 20 * root.s
                    height: 28 * root.s
                    radius: Theme.radius
                    visible: root.hasPin || (urlField.text && urlField.text.length > 0)
                    color: clearHover.hovered ? Theme.sheen : "transparent"
                    border.width: 1
                    border.color: Theme.lineStrong

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: "CLEAR"
                        color: Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: 12 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.4 * root.s
                    }
                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            urlField.text = "";
                            if (root.service)
                                root.service.clear();
                        }
                    }
                }
            }
        }
    }
}
