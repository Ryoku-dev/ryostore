import QtQuick

// AudioBars provides spectrum levels without tempo tracking; keep C++'s initial 120 BPM.
QtObject {
    readonly property real bpm: 120

    signal beat(real bpm)

    function ref(sender: QtObject): void {}

    function unref(sender: QtObject): void {}
}
