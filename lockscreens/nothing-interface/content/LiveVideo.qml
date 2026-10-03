import QtQuick
import QtMultimedia

Item {
    id: root
    property url sourceUrl: ""
    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
    MediaPlayer {
        id: player
        source: root.sourceUrl
        videoOutput: output
        audioOutput: AudioOutput { muted: true }
        loops: MediaPlayer.Infinite
        onSourceChanged: if (source.toString().length) play()
    }
}
