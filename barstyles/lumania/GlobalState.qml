import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string path: (Quickshell.env("XDG_CONFIG_HOME")
    || (Quickshell.env("HOME") + "/.config")) + "/ryoku/barstyle-lumania.json"

  readonly property var defaults: ({
    borderThickness: 5,
    radius: 16,
    cornerStyle: "squircle",
    islandWidth: 206,
    wallpaperThumbs: 7,
    reduceMotion: false,
    islandNotifications: true
  })

  property var settings: root.defaults
  property bool loaded: false

  function read(text) {
    var data = {}
    try { data = JSON.parse(text) } catch (e) { data = {} }
    if (!data || typeof data !== "object") data = {}
    root.settings = Object.assign({}, root.defaults, data)
    root.loaded = true
  }

  function update(key, value) {
    var next = Object.assign({}, root.settings)
    next[key] = value
    root.settings = next
    root.persist()
  }

  function reset() {
    root.settings = root.defaults
    root.persist()
  }

  // Dragging a slider fires on every pixel, so the file is written once the
  // value settles.
  function persist() {
    writeTimer.restart()
  }

  Timer {
    id: writeTimer
    interval: 200
    onTriggered: {
      writeProc.command = ["sh", "-c",
        "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
        "lumania-settings", root.path, JSON.stringify(root.settings)]
      writeProc.running = false
      writeProc.running = true
    }
  }

  Process { id: writeProc }

  FileView {
    id: file
    path: root.path
    watchChanges: true
    blockLoading: true
    printErrors: false
    onLoaded: root.read(file.text())
    onFileChanged: file.reload()
  }
}
