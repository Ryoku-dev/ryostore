import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var pluginApi

  readonly property string medkitPath: (Quickshell.env("HOME") || "/home/hatem") + "/.local/share/medkit/medicines.json"
  readonly property string cachePath: (pluginApi && pluginApi.stateDir ? pluginApi.stateDir : (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/plugins/medkit-guide") + "/medicine-cache.json"
  readonly property string scriptPath: pluginApi && pluginApi.pluginDir ? pluginApi.pluginDir + "/bin/fetch-medicine.py" : ""

  property var medicines: []
  property bool loading: false
  property string lastError: ""
  property real now: Date.now()

  function loadMedicines() {
    root.loading = true
    root.lastError = ""
    // Run the helper script
    fetchProcess.command = ["python3", root.scriptPath]
    fetchProcess.running = true
  }

  Process {
    id: fetchProcess
    property string output: ""
    onStarted: { output = "" }
    onReadyRead: { output += readAllStandardOutput() }
    onExited: (code) => {
      root.loading = false
      if (code === 0) {
        try {
          var data = JSON.parse(output)
          if (data.medicines) {
            var meds = []
            for (var key in data.medicines) {
              meds.push(data.medicines[key])
            }
            root.medicines = meds
          }
          if (data.errors && data.errors.length > 0) {
            root.lastError = data.errors.join("; ")
          }
        } catch (e) {
          root.lastError = "Failed to parse medicine data"
        }
      } else {
        root.lastError = "Failed to fetch medicine details"
      }
    }
  }

  function refresh() {
    loadMedicines()
  }

  function getMedicineByName(name) {
    for (var i = 0; i < root.medicines.length; i++) {
      if (root.medicines[i].name === name) return root.medicines[i]
    }
    return null
  }

  Component.onCompleted: {
    loadMedicines()
  }
}
