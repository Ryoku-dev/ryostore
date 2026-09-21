import QtQuick
import Ryoku.PluginKit.Singletons

// Everything that is not a card: first load, all caught up, no decks, error.
Column {
    id: st

    property real s: 1
    property string phase: "init"
    property real nextDueIn: 0
    property string errorText: ""
    property int reviewsToday: 0
    // Cards due RIGHT NOW. "All caught up" is a lie whenever this is non-zero;
    // what is actually true is that the pacing interval has not elapsed yet.
    property int dueCount: 0
    property real nextCardIn: 0

    signal reviewNow()

    readonly property bool holding: st.dueCount > 0
        && (st.phase === "caught-up" || st.phase === "waiting")

    spacing: 8 * st.s

    function humanGap(seconds) {
        if (seconds <= 0) return "now";
        const m = Math.round(seconds / 60);
        if (m < 60) return m + "m";
        const h = Math.floor(m / 60);
        if (h < 24) return h + "h " + (m % 60) + "m";
        return Math.round(h / 24) + "d";
    }

    readonly property string headline: {
        if (st.holding)
            return st.dueCount + (st.dueCount === 1 ? " card due" : " cards due");
        switch (st.phase) {
        case "init":      return "Loading decks";
        case "caught-up": return "All caught up";
        case "empty":     return "No cards yet";
        case "error":     return "Something went wrong";
        default:          return "";
        }
    }

    readonly property string detail: {
        if (st.holding)
            return "next card in " + st.humanGap(st.nextCardIn);
        switch (st.phase) {
        case "init":
            return "Building the card store";
        case "caught-up":
            return st.nextDueIn > 0
                ? "Next review in " + st.humanGap(st.nextDueIn)
                : "Nothing scheduled";
        case "empty":
            return "Enable a script, or point the deck folder at your own cards";
        case "error":
            return st.errorText;
        default:
            return "";
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: st.headline
        color: st.phase === "error" ? Theme.accent : Theme.bright
        font.family: Theme.font
        font.pixelSize: 16 * st.s
        font.weight: Font.Medium
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, 260 * st.s)
        horizontalAlignment: Text.AlignHCenter
        text: st.detail
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 11 * st.s
        wrapMode: Text.WordWrap
    }

    // The interval governs what arrives unprompted; this is how you ask for a
    // card early without changing the setting.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: st.holding
        height: visible ? 26 * st.s : 0
        width: nowLabel.implicitWidth + 24 * st.s
        radius: 7 * st.s
        readonly property color rest: Scheme.role("primaryContainer", Theme.threadBg)
        color: nowHover.containsPress ? Qt.darker(rest, 1.18)
             : nowHover.hovered       ? Qt.lighter(rest, 1.14)
                                      : rest
        border.width: 1
        border.color: Scheme.line
        scale: nowHover.containsPress ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        Text {
            id: nowLabel
            anchors.centerIn: parent
            text: "review now"
            color: Scheme.role("onPrimaryContainer", Theme.bright)
            font.family: Theme.font
            font.pixelSize: 11 * st.s
            font.weight: Font.Medium
        }

        HoverHandler { id: nowHover }
        TapHandler { onTapped: st.reviewNow() }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: st.phase === "caught-up" && !st.holding && st.reviewsToday > 0
        text: st.reviewsToday + " reviewed today"
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 10 * st.s
        font.letterSpacing: 1.2 * st.s
    }
}
