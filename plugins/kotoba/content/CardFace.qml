import QtQuick
import Ryoku.PluginKit.Singletons

// One card, front and back. What the four types ask:
//
//   recog    猫  -> cat          the meaning
//   reading  猫  -> ねこ         the reading. Furigana is suppressed on the
//                                front here, because it IS the answer.
//   recall   cat -> 猫 / ねこ    produce the word
//   kana     ツ  -> tsu          script drill
Column {
    id: face

    property var card: null
    property bool revealed: false
    property bool showRomaji: true
    property bool showFurigana: true
    property real s: 1
    property real fontScale: 1.0

    readonly property string ctype: card ? (card.ctype || "recog") : "recog"
    readonly property real jpSize: 38 * face.s * face.fontScale
    readonly property real enSize: 17 * face.s * face.fontScale

    // The front of a reading card must never leak the reading.
    readonly property bool rubyOnFront: face.showFurigana && face.ctype !== "reading"

    property bool firstRun: false

    // A question, not a category: there should never be doubt about what
    // answer you are reaching for.
    readonly property string askLabel: {
        switch (face.ctype) {
        case "reading": return "how is it read?";
        case "recall":  return "write this in Japanese";
        case "kana":    return "which sound is this?";
        default:        return "what does this mean?";
        }
    }

    spacing: 10 * face.s

    // --- the prompt --------------------------------------------------------

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: face.askLabel
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 9 * face.s
        font.letterSpacing: 2.2 * face.s
        font.capitalization: Font.AllUppercase
    }

    // English front, for recall cards
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: face.ctype === "recall"
        height: visible ? implicitHeight : 0
        text: face.card ? face.card.en : ""
        color: Theme.bright
        font.family: Theme.font
        font.pixelSize: face.enSize * 1.25
        font.weight: Font.Medium
    }

    // Japanese front, for every other type
    Furigana {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: face.ctype !== "recall"
        height: visible ? implicitHeight : 0
        base: face.card ? face.card.jp : ""
        reading: face.card ? face.card.kana : ""
        showReading: face.rubyOnFront
        size: face.jpSize
        baseColor: Theme.bright
        rubyColor: Theme.dim
    }

    // First few cards only: say what to do. Disappears after five reviews.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: face.firstRun && !face.revealed
        height: visible ? implicitHeight : 0
        text: "tap the card to reveal"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10 * face.s
        font.italic: true
    }

    // --- the divider, which only exists once there is an answer -------------

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: face.revealed
        height: visible ? 1 : 0
        width: 92 * face.s
        color: Scheme.line
    }

    // --- the back ----------------------------------------------------------

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: face.revealed && (face.ctype === "recog" || face.ctype === "kana")
        height: visible ? implicitHeight : 0
        text: face.card ? face.card.en : ""
        color: Theme.bright
        font.family: Theme.font
        font.pixelSize: face.enSize
        font.weight: Font.Medium
    }

    // the reading, as the answer to a reading card
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: face.revealed && face.ctype === "reading"
        height: visible ? implicitHeight : 0
        text: face.card ? face.card.kana : ""
        color: Theme.bright
        font.family: Theme.fontJp
        font.pixelSize: face.jpSize * 0.7
        renderType: Text.NativeRendering
    }

    // the whole word, as the answer to a recall card
    Furigana {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: face.revealed && face.ctype === "recall"
        height: visible ? implicitHeight : 0
        base: face.card ? face.card.jp : ""
        reading: face.card ? face.card.kana : ""
        showReading: face.showFurigana
        size: face.jpSize * 0.85
        baseColor: Theme.bright
        rubyColor: Theme.dim
    }

    // romaji, when the user wants it. A kana drill's answer is already romaji,
    // so it is not repeated underneath itself.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: face.revealed && face.showRomaji && face.ctype !== "kana"
                 && !!face.card && !!face.card.romaji
        height: visible ? implicitHeight : 0
        text: face.card ? face.card.romaji : ""
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 12 * face.s * face.fontScale
        font.italic: true
    }
}
