import QtQuick
import Quickshell.Io

Item {
  id: root
  property var pluginApi

  readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
  readonly property string scriptPath: pluginApi && pluginApi.pluginDir ? pluginApi.pluginDir + "/bin/fetch-medicine.py" : ""
  readonly property bool autoRefresh: settings ? (settings.autoRefresh ?? true) : true
  readonly property int cacheDays: Math.max(1, Math.min(30, Number(settings ? (settings.cacheDays ?? 7) : 7)))

  property var medicines: []
  property bool loading: false
  property string lastError: ""

  function loadMedicines(forceNetwork) {
    if (!root.scriptPath || fetchProcess.running)
      return
    root.loading = true
    root.lastError = ""
    var argv = ["python3", root.scriptPath, "--cache-days", String(root.cacheDays)]
    if (forceNetwork)
      argv.push("--force")
    else if (!root.autoRefresh)
      argv.push("--offline")
    fetchProcess.command = argv
    fetchProcess.running = true
  }

  Process {
    id: fetchProcess
    stdout: StdioCollector { id: fetchOutput; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: (code) => {
      root.loading = false
      if (code !== 0) {
        root.lastError = "Failed to load medicine details"
        return
      }
      try {
        var data = JSON.parse(fetchOutput.text || "{}")
        if (data.error)
          root.lastError = String(data.error)
        var meds = []
        var values = data.medicines || {}
        for (var key in values)
          meds.push(values[key])
        root.medicines = meds
        if (data.errors && data.errors.length > 0)
          root.lastError = data.errors.join("; ")
      } catch (e) {
        root.lastError = "Failed to parse medicine data"
      }
    }
  }

  function refresh() {
    root.loadMedicines(true)
  }

  onScriptPathChanged: {
    if (root.scriptPath)
      root.loadMedicines(false)
  }

  Component.onCompleted: root.loadMedicines(false)
}
