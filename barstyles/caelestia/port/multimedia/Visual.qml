import QtQuick
import QtMultimedia

Item {
    id: root

    enum Type { Unknown, Image, Animated, Live }

    property url source
    property int fillMode: Image.PreserveAspectCrop
    property bool playing: true
    property bool animate: true
    readonly property int type: videoSuffixes.includes(suffix) ? Visual.Live : animatedSuffixes.includes(suffix) ? Visual.Animated : source ? Visual.Image : Visual.Unknown
    readonly property bool ready: type === Visual.Live ? player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia : image.status === Image.Ready
    readonly property string suffix: source.toString().split(/[?#]/)[0].split(".").pop().toLowerCase()
    readonly property var videoSuffixes: ["mp4", "webm", "mkv", "avi", "mov", "wmv"]
    readonly property var animatedSuffixes: ["gif", "webp"]

    opacity: !animate || ready ? 1 : 0

    AnimatedImage {
        id: image
        anchors.fill: parent
        source: root.type === Visual.Live ? "" : root.source
        fillMode: root.fillMode
        asynchronous: true
        playing: root.playing
    }

    MediaPlayer {
        id: player
        source: root.type === Visual.Live ? root.source : ""
        loops: MediaPlayer.Infinite
        videoOutput: output
        audioOutput: AudioOutput { muted: true }
        onSourceChanged: root.playing ? play() : stop()
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        visible: root.type === Visual.Live
        fillMode: root.fillMode
    }

    onPlayingChanged: {
        if (type === Visual.Live)
            playing ? player.play() : player.pause();
    }
}
