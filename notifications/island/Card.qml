pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Quickshell.Services.Notifications
import Ryoku.Ui.Singletons
import shell.services

// Island: the Dynamic Island's notification card for Ryoku.
//
// A black card, the way the island itself is black, with liquid glass only
// where your hand goes: the close bead and the action pills. Urgent
// notifications carry a "Time Sensitive" line and a red halo, and a timed
// card drains a hairline along its foot.
Item {
    id: root

    required property var notification
    property real us: 1
    property int lifespanMs: 0
    property string position: "Right"
    property bool showImages: true

    // glass controls on this card refract the card itself
    property var glassSource: null
    property Item glassSpace: null
    property color glassBase: card.color

    readonly property bool urgent: notification && notification.urgency === NotificationUrgency.Critical
    readonly property color accent: Tokens.sun
    readonly property real pad: 14 * us

    readonly property var actionList: {
        const src = notification ? (notification.actions || []) : [];
        const out = [];
        for (let i = 0; i < src.length; ++i)
            if (src[i] && src[i].identifier !== "default" && String(src[i].text || "") !== "") out.push(src[i]);
        return out.slice(0, 3);
    }
    readonly property var defaultAction: {
        const src = notification ? (notification.actions || []) : [];
        for (let i = 0; i < src.length; ++i) if (src[i] && src[i].identifier === "default") return src[i];
        return null;
    }

    function iconUrl(s) {
        s = String(s || "");
        if (s === "") return "";
        if (s.startsWith("/")) return "file://" + s;
        if (s.indexOf(":") >= 0) return s;
        return Icons.path(s, true);
    }
    readonly property string appIconUrl: iconUrl(notification ? notification.appIcon : "")
    readonly property string pictureUrl: showImages ? iconUrl(notification ? notification.image : "") : ""

    function run(action) {
        if (action && typeof action.invoke === "function") action.invoke();
        Notifs.dismiss(root.notification);
    }

    implicitHeight: body.implicitHeight + pad * 2 + (actions.visible ? actions.height + 10 * us : 0)

    // ── the card ──
    Rectangle {
        id: halo
        anchors.fill: card
        anchors.margins: -2 * root.us
        radius: card.radius + 2 * root.us
        color: "transparent"
        border.width: 2 * root.us
        border.color: Qt.rgba(1, 0.27, 0.23, 0.55)
        visible: root.urgent
        opacity: 0.8
    }
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 24 * root.us
        color: "#0a0a0b"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
    }

    HoverHandler { id: hover }

    Item {
        id: body
        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        implicitHeight: Math.max(icon.height, textCol.implicitHeight)

        // the body runs the app's default action
        TapHandler { onTapped: root.defaultAction ? root.run(root.defaultAction) : Notifs.dismiss(root.notification) }

        // app icon, or the sender's picture with a small app badge
        Item {
            id: icon
            width: 38 * root.us
            height: width
            ClippingRectangle {
                anchors.fill: parent
                radius: root.pictureUrl !== "" ? width / 2 : width * 0.24
                color: Qt.rgba(1, 1, 1, 0.08)
                Image {
                    anchors.fill: parent
                    source: root.pictureUrl !== "" ? root.pictureUrl : root.appIconUrl
                    fillMode: root.pictureUrl !== "" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    sourceSize.width: 96
                    sourceSize.height: 96
                }
            }
            Rectangle {
                visible: root.pictureUrl !== "" && root.appIconUrl !== ""
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -4 * root.us
                width: 19 * root.us; height: width; radius: 6 * root.us
                color: "#1c1c1e"
                Image {
                    anchors.centerIn: parent
                    width: 15 * root.us; height: width
                    source: root.appIconUrl
                    sourceSize.width: 48
                    sourceSize.height: 48
                }
            }
        }

        Column {
            id: textCol
            anchors.left: icon.right
            anchors.leftMargin: 11 * root.us
            anchors.right: parent.right
            anchors.rightMargin: 4 * root.us
            spacing: 2 * root.us

            Text {
                visible: root.urgent
                text: "TIME SENSITIVE"
                color: "#ff9f0a"
                font.family: Tokens.ui
                font.pixelSize: 10 * root.us
                font.weight: Font.Bold
                font.letterSpacing: 0.5
            }
            Item {
                width: parent.width
                height: titleText.implicitHeight
                Text {
                    id: titleText
                    anchors.left: parent.left
                    anchors.right: timeText.left
                    anchors.rightMargin: 8 * root.us
                    text: root.notification ? (root.notification.summary || root.notification.appName || "Notification") : ""
                    color: "#ffffff"
                    font.family: Tokens.ui
                    font.pixelSize: 14.5 * root.us
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    id: timeText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.notification ? Notifs.timeLabel(root.notification) : ""
                    color: Qt.rgba(235 / 255, 235 / 255, 245 / 255, 0.6)
                    font.family: Tokens.ui
                    font.pixelSize: 12 * root.us
                    opacity: hover.hovered ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Tokens.dur(140) } }
                }
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: root.notification ? (root.notification.body || "") : ""
                textFormat: Text.StyledText
                color: Qt.rgba(1, 1, 1, 0.86)
                font.family: Tokens.ui
                font.pixelSize: 13.5 * root.us
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 4
                elide: Text.ElideRight
                lineHeight: 1.06
            }
        }
    }

    // ── actions: glass pills ──
    Row {
        id: actions
        visible: root.actionList.length > 0
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - root.pad * 2
        height: 34 * root.us
        spacing: 8 * root.us
        Repeater {
            model: root.actionList
            GlassControl {
                id: pill
                required property var modelData
                width: (actions.width - (root.actionList.length - 1) * actions.spacing) / root.actionList.length
                height: actions.height
                hovered: pillHover.hovered
                pressed: pillTap.pressed
                shadow: 0.4
                scale: pillTap.pressed ? 0.96 : 1
                Behavior on scale { NumberAnimation { duration: Tokens.dur(180); easing.type: Easing.OutBack } }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 16 * root.us
                    horizontalAlignment: Text.AlignHCenter
                    text: pill.modelData.text
                    color: "#ffffff"
                    font.family: Tokens.ui
                    font.pixelSize: 13 * root.us
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                HoverHandler { id: pillHover }
                TapHandler { id: pillTap; onTapped: root.run(pill.modelData) }
            }
        }
    }

    // ── close: a glass bead on the corner ──
    GlassControl {
        x: root.width - width - 10 * root.us
        y: 10 * root.us
        width: 24 * root.us
        height: width
        base: "#1c1c1e"
        visible: opacity > 0.01
        opacity: hover.hovered ? 1 : 0
        hovered: closeHover.hovered
        pressed: closeTap.pressed
        Behavior on opacity { NumberAnimation { duration: Tokens.dur(140) } }
        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "#ffffff"
            font.pixelSize: 11 * root.us
            font.weight: Font.Bold
        }
        HoverHandler { id: closeHover }
        TapHandler { id: closeTap; onTapped: Notifs.dismiss(root.notification) }
    }

    // ── the hairline that drains while a timed card waits ──
    Rectangle {
        visible: root.lifespanMs > 0
        anchors.bottom: card.bottom
        anchors.bottomMargin: 1
        x: card.radius
        height: 2 * root.us
        radius: height / 2
        color: root.urgent ? "#ff453a" : root.accent
        opacity: 0.7
        property real remain: 1
        width: Math.max(0, (card.width - card.radius * 2) * remain)
        NumberAnimation on remain {
            running: root.lifespanMs > 0 && !Tokens.reduceMotion
            from: 1; to: 0
            duration: Math.max(1, root.lifespanMs)
        }
    }
}
