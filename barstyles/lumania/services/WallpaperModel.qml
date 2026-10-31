import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string indexPath: (Quickshell.env("XDG_CACHE_HOME")
    || (root.home + "/.cache")) + "/ryogami/wallpaper/index.json"
  readonly property string outputsPath: (Quickshell.env("XDG_CACHE_HOME")
    || (root.home + "/.cache")) + "/ryogami/outputs.json"

  property var index: ({})
  property var entries: []
  property string currentPath: ""

  function expand(path) {
    var p = String(path || "")
    if (p === "~") return root.home
    if (p.indexOf("~/") === 0) return root.home + p.slice(1)
    return p
  }

  function readIndex(text) {
    var data = {}
    try { data = JSON.parse(text) } catch (e) { data = {} }
    var list = []
    var map = {}
    for (var key in data) {
      var v = data[key]
      if (!v || !v.path) continue
      var rec = {
        path: root.expand(v.path),
        name: String(v.name || v.key || key),
        type: String(v.type || "static"),
        thumb: root.expand(v.thumb || ""),
        thumbSm: root.expand(v.thumb_sm || "")
      }
      list.push(rec)
      map[rec.path] = rec
    }
    list.sort(function(a, b) { return a.name.localeCompare(b.name) })
    root.index = map
    root.entries = list
  }

  function readOutputs(text) {
    var data = {}
    try { data = JSON.parse(text) } catch (e) { data = {} }
    var rec = data["*"] || data[Object.keys(data)[0]]
    if (rec && rec.path) root.currentPath = root.expand(rec.path)
  }

  function thumbUrl(path) {
    var rec = root.index[path]
    if (rec) {
      var t = rec.thumbSm !== "" ? rec.thumbSm : rec.thumb
      if (t !== "") return "file://" + t
    }
    return "file://" + String(path || "")
  }

  function setWallpaper(path) {
    if (!path) return
    root.currentPath = path
    Quickshell.execDetached(["ryogami", "wallpaper", "set", path])
  }

  FileView {
    id: indexFile
    path: root.indexPath
    watchChanges: true
    blockLoading: true
    printErrors: false
    onLoaded: root.readIndex(indexFile.text())
    onFileChanged: indexFile.reload()
  }

  FileView {
    id: outputsFile
    path: root.outputsPath
    watchChanges: true
    blockLoading: true
    printErrors: false
    onLoaded: root.readOutputs(outputsFile.text())
    onFileChanged: outputsFile.reload()
  }
}
