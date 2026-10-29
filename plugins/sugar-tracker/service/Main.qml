import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var pluginApi
  property var entries: []
  property real now: Date.now()
  readonly property real dailyGoal: {
    var value = Number(pluginApi?.pluginSettings?.dailyGoal ?? 25)
    return isFinite(value) ? Math.max(1, Math.min(200, value)) : 25
  }
  readonly property var todayEntries: {
    var start = new Date(now)
    start.setHours(0, 0, 0, 0)
    var out = []
    for (var i = 0; i < entries.length; i++)
      if (entries[i].t >= start.getTime()) out.push(entries[i])
    return out
  }
  readonly property real todayGrams: {
    var total = 0
    for (var i = 0; i < todayEntries.length; i++) total += todayEntries[i].grams
    return Math.round(total * 10) / 10
  }
  readonly property bool overGoal: todayGrams > dailyGoal

  function loadLog(raw) {
    var parsed = []
    try {
      var json = JSON.parse(raw || "{}")
      if (json && Array.isArray(json.entries)) parsed = json.entries
    } catch (e) { parsed = [] }

    var cutoff = Date.now() - 14 * 86400000
    var cleaned = []
    for (var i = 0; i < parsed.length; i++) {
      var entry = parsed[i]
      var t = Number(entry && entry.t)
      var grams = Number(entry && entry.grams)
      if (!isFinite(t) || !isFinite(grams) || grams <= 0 || t < cutoff) continue
      cleaned.push({ t: t, grams: Math.round(grams * 10) / 10, name: String(entry.name || "Sugar") })
    }
    cleaned.sort(function(a, b) { return a.t - b.t })
    entries = cleaned
  }

  function saveLog() {
    if (!pluginApi?.stateDir) return
    logFile.path = pluginApi.stateDir + "/sugar-log.json"
    logFile.setText(JSON.stringify({ version: 1, entries: entries }, null, 2) + "\n")
  }

  function addSugar(amount, name) {
    var grams = Number(amount)
    if (!isFinite(grams) || grams <= 0 || grams > 200) return
    var next = entries.slice()
    next.push({ t: Date.now(), grams: Math.round(grams * 10) / 10, name: String(name || "Sugar") })
    entries = next
    now = Date.now()
    saveLog()
  }

  function removeEntryAt(timestamp) {
    var next = entries.slice()
    for (var i = next.length - 1; i >= 0; i--) {
      if (next[i].t === timestamp) {
        next.splice(i, 1)
        entries = next
        saveLog()
        return
      }
    }
  }

  function undoLast() {
    if (todayEntries.length > 0) removeEntryAt(todayEntries[todayEntries.length - 1].t)
  }

  function clearToday() {
    if (todayEntries.length === 0) return
    var start = new Date(now)
    start.setHours(0, 0, 0, 0)
    var cutoff = start.getTime()
    var next = []
    for (var i = 0; i < entries.length; i++)
      if (entries[i].t < cutoff) next.push(entries[i])
    entries = next
    saveLog()
  }

  FileView {
    id: logFile
    path: pluginApi?.stateDir ? pluginApi.stateDir + "/sugar-log.json" : ""
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadLog(text())
    onLoadFailed: root.loadLog("{}")
    onFileChanged: reload()
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.now = Date.now()
  }

  Component.onCompleted: Qt.callLater(function() { logFile.reload() })
}
