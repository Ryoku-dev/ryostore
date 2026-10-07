import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    readonly property string themeDir: Quickshell.env("QS_THEME_PATH") || ""
    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryogami.sock"
    property string wallpaperPath: ""
    property string videoPath: ""
    property int wallpaperRevision: 0
    property string fit: "Cover"
    readonly property string wallpaperUrl: wallpaperPath.length ? "file://" + wallpaperPath + "?v=" + wallpaperRevision : ""
    readonly property string videoUrl: videoPath.length ? "file://" + videoPath : ""
    property var battery: ({level: -1, charging: false, plugged: false})
    property var activity: ({seconds: 0, available: false})
    property var media: ({playing: false, available: false, title: "", artist: "", position: 0, length: 0})

    function applyWallpaper(line) {
        try {
            const frame = JSON.parse(line)
            const output = Screen.name || ""
            const entry = (frame.outputs && frame.outputs[output]) || frame.default
            if (!entry) return
            wallpaperPath = entry.path || ""
            videoPath = entry.videoPath || ""
            wallpaperRevision = Number(entry.revision || 0)
            fit = entry.fit || "Cover"
        } catch (error) {
            console.warn("nothing-interface: invalid wallpaper frame", error)
        }
    }

    function readJson(raw, target) {
        if (!raw || !raw.trim()) return
        try { root[target] = JSON.parse(raw) }
        catch (error) { console.warn("nothing-interface: invalid " + target + " data", error) }
    }
    function refresh() {
        if (!batteryProbe.running) batteryProbe.running = true
        if (!activityProbe.running) activityProbe.running = true
        if (!mediaProbe.running) mediaProbe.running = true
    }

    Socket {
        id: wallpaperSocket
        path: root.socketPath
        parser: SplitParser { onRead: line => root.applyWallpaper(line) }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe wallpaper\n")
                flush()
            } else retry.restart()
        }
        onError: {
            connected = false
            retry.restart()
        }
    }
    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!wallpaperSocket.connected) wallpaperSocket.connected = true
    }
    Process {
        id: batteryProbe
        command: ["python3", root.themeDir + "/bin/status.py"]
        stdout: StdioCollector { onStreamFinished: root.readJson(this.text, "battery") }
    }
    Process {
        id: activityProbe
        command: ["python3", root.themeDir + "/bin/activity.py"]
        stdout: StdioCollector { onStreamFinished: root.readJson(this.text, "activity") }
    }
    Process {
        id: mediaProbe
        command: ["python3", root.themeDir + "/bin/media.py"]
        stdout: StdioCollector { onStreamFinished: root.readJson(this.text, "media") }
    }
    Process {
        id: playback
        command: ["playerctl", "play-pause"]
        onExited: mediaProbe.running = true
    }
    function togglePlayback() {
        if (media.available && !playback.running) playback.running = true
    }
    Timer { interval: 10000; repeat: true; running: true; onTriggered: root.refresh() }
    Timer { interval: 2000; repeat: true; running: true; onTriggered: if (!mediaProbe.running) mediaProbe.running = true }
    Component.onCompleted: Qt.callLater(refresh)
}
