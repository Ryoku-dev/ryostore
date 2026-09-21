import QtQuick
import Ryoku.PluginKit.Singletons

// Qt has no ruby-text layout and the CJK fonts' OpenType `ruby` feature does
// not help, so furigana is laid out by hand: the whole-word reading set above
// the word in a lighter weight at half the size. Per-character okurigana
// alignment is out of scope - whole-word is what flashcards show anyway.
Column {
    id: ruby

    property string base: ""
    property string reading: ""
    property bool showReading: true
    property real size: 34
    property color baseColor: Theme.bright
    property color rubyColor: Theme.dim

    // Nothing to set above a word that is already its own reading.
    readonly property bool hasRuby: ruby.showReading
        && ruby.reading.length > 0
        && ruby.reading !== ruby.base

    spacing: 3 * (ruby.size / 34)

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: ruby.hasRuby
        height: visible ? implicitHeight : 0
        text: ruby.reading
        color: ruby.rubyColor
        // Pin the JP family explicitly: fontconfig otherwise resolves shared
        // Han codepoints to SC/TC variants, which draw wrong Japanese forms.
        font.family: Theme.fontJp
        font.pixelSize: Math.round(ruby.size * 0.42)
        font.weight: Font.Light
        font.letterSpacing: 1.5 * (ruby.size / 34)
        renderType: Text.NativeRendering
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: ruby.base
        color: ruby.baseColor
        font.family: Theme.fontJp
        font.pixelSize: ruby.size
        font.weight: Font.Normal
        renderType: Text.NativeRendering
    }
}
