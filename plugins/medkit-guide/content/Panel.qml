pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

Item {
  id: root
  property var pluginApi
  property var screen
  property bool active
  property string density: "full"
  property real s: 1
  property real widthBudget: 480

  readonly property var service: pluginApi && pluginApi.mainInstance ? pluginApi.mainInstance : null
  readonly property real pad: 14 * root.s
  readonly property real contentW: Math.max(280 * root.s, (root.widthBudget > 0 ? root.widthBudget : 480 * root.s) - root.pad * 2)
  implicitWidth: root.contentW + root.pad * 2
  implicitHeight: body.implicitHeight

  property string searchQuery: ""
  property int expandedIndex: -1

  Column {
    id: body
    x: root.pad
    width: root.contentW
    spacing: 12 * root.s

    // Header
    Rectangle {
      width: parent.width
      height: 60 * root.s
      radius: 14 * root.s
      gradient: Gradient {
        GradientStop { position: 0.0; color: "#1e293b" }
        GradientStop { position: 1.0; color: "#0f172a" }
      }
      border.width: 1
      border.color: "#334155"

      Row {
        anchors.centerIn: parent
        spacing: 10 * root.s
        Text { text: "🩺"; font.pixelSize: 24 * root.s }
        Column {
          spacing: 2 * root.s
          Text {
            text: qsTr("Medicine Guide")
            color: "#f1f5f9"
            font.family: Theme.font
            font.pixelSize: 16 * root.s
            font.bold: true
          }
          Text {
            text: root.service ? (root.service.loading ? qsTr("Loading...") : (root.service.medicines.length + " medicines")) : "—"
            color: "#94a3b8"
            font.family: Theme.font
            font.pixelSize: 10 * root.s
          }
        }
      }
    }

    // Search bar
    Rectangle {
      width: parent.width
      height: 36 * root.s
      radius: 10 * root.s
      color: "#0f172a"
      border.width: 1
      border.color: "#334155"

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 12 * root.s
        anchors.verticalCenter: parent.verticalCenter
        visible: searchField.text.length === 0
        text: qsTr("Search medicines...")
        color: "#64748b"
        font.family: Theme.font
        font.pixelSize: 12 * root.s
      }
      TextInput {
        id: searchField
        anchors.fill: parent
        anchors.leftMargin: 12 * root.s
        anchors.rightMargin: 12 * root.s
        verticalAlignment: TextInput.AlignVCenter
        text: root.searchQuery
        onTextChanged: root.searchQuery = text
        color: "#f1f5f9"
        font.family: Theme.font
        font.pixelSize: 12 * root.s
      }
    }

    // Refresh button
    Rectangle {
      width: parent.width
      height: 32 * root.s
      radius: 8 * root.s
      color: refreshTap.containsMouse ? "#334155" : "#1e293b"
      border.width: 1
      border.color: "#334155"
      opacity: root.service && root.service.loading ? 0.55 : 1

      Text {
        anchors.centerIn: parent
        text: root.service && root.service.loading ? qsTr("Refreshing...") : qsTr("🔄 Refresh All")
        color: "#94a3b8"
        font.family: Theme.font
        font.pixelSize: 11 * root.s
      }
      MouseArea {
        id: refreshTap
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.service && !root.service.loading
        onClicked: root.service && root.service.refresh()
      }
    }

    Text {
      width: parent.width
      visible: root.service && root.service.lastError.length > 0
      text: root.service ? root.service.lastError : ""
      color: "#fbbf24"
      font.family: Theme.font
      font.pixelSize: 10 * root.s
      wrapMode: Text.WordWrap
    }

    // Medicine cards
    Repeater {
      model: {
        let meds = root.service ? (root.service.medicines || []) : []
        if (root.searchQuery) {
          const q = root.searchQuery.toLowerCase()
          meds = meds.filter(function(m) {
            return (m.name || "").toLowerCase().indexOf(q) >= 0 ||
                   (m.generic || "").toLowerCase().indexOf(q) >= 0
          })
        }
        return meds
      }
      delegate: Rectangle {
        required property var modelData
        required property int index
        width: parent.width
        height: cardColumn.implicitHeight + 16 * root.s
        radius: 12 * root.s
        color: "#1e293b"
        border.width: 1
        border.color: root.expandedIndex === index ? "#4ade80" : "#334155"

        Column {
          id: cardColumn
          x: 12 * root.s
          y: 8 * root.s
          width: parent.width - 24 * root.s
          spacing: 8 * root.s

          // Medicine header (always visible)
          Row {
            width: parent.width
            spacing: 8 * root.s

            Rectangle {
              width: 36 * root.s
              height: 36 * root.s
              radius: 8 * root.s
              color: "#0f172a"
              Text {
                anchors.centerIn: parent
                text: "💊"
                font.pixelSize: 16 * root.s
              }
            }

            Column {
              spacing: 2 * root.s
              width: parent.width - 44 * root.s
              Text {
                text: modelData.name
                color: "#f1f5f9"
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                font.bold: true
              }
              Text {
                text: (modelData.generic || "—") + " • " + (modelData.dose || "")
                color: "#94a3b8"
                font.family: Theme.font
                font.pixelSize: 10 * root.s
              }
            }
          }

          // Dose info row
          Row {
            width: parent.width
            spacing: 12 * root.s
            Text {
              text: "⏰ " + (modelData.times ? modelData.times.join(", ") : "—")
              color: "#cbd5e1"
              font.family: Theme.font
              font.pixelSize: 10 * root.s
            }
            Text {
              text: "📦 " + (modelData.stock || 0) + " left"
              color: (modelData.stock || 0) <= (modelData.refill_at || 5) ? "#fa3b30" : "#4ade80"
              font.family: Theme.font
              font.pixelSize: 10 * root.s
            }
          }

          // Expand/collapse toggle
          Rectangle {
            width: parent.width
            height: 28 * root.s
            radius: 6 * root.s
            color: toggleTap.containsMouse ? "#334155" : "#273148"

            Text {
              anchors.centerIn: parent
              text: root.expandedIndex === index ? qsTr("▲ Hide details") : qsTr("▼ Show details")
              color: "#94a3b8"
              font.family: Theme.font
              font.pixelSize: 10 * root.s
            }
            MouseArea {
              id: toggleTap
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.expandedIndex = (root.expandedIndex === index ? -1 : index)
            }
          }

          // Expanded details
          Column {
            width: parent.width
            spacing: 8 * root.s
            visible: root.expandedIndex === index

            // Indications
            Rectangle {
              width: parent.width
              height: indCol.implicitHeight + 8 * root.s
              radius: 8 * root.s
              color: "#0f172a"
              border.width: 1
              border.color: "#1e293b"

              Column {
                id: indCol
                x: 8 * root.s
                y: 4 * root.s
                width: parent.width - 16 * root.s
                spacing: 4 * root.s

                Text {
                  text: "📋 Indications"
                  color: "#4ade80"
                  font.family: Theme.font
                  font.pixelSize: 11 * root.s
                  font.bold: true
                }
                Text {
                  width: parent.width
                  text: (modelData.details && modelData.details.indications) ? modelData.details.indications.substring(0, 300) + (modelData.details.indications.length > 300 ? "..." : "") : qsTr("No data available")
                  color: "#cbd5e1"
                  font.family: Theme.font
                  font.pixelSize: 10 * root.s
                  wrapMode: Text.WordWrap
                }
              }
            }

            // Dosage
            Rectangle {
              width: parent.width
              height: doseCol.implicitHeight + 8 * root.s
              radius: 8 * root.s
              color: "#0f172a"
              border.width: 1
              border.color: "#1e293b"

              Column {
                id: doseCol
                x: 8 * root.s
                y: 4 * root.s
                width: parent.width - 16 * root.s
                spacing: 4 * root.s

                Text {
                  text: "💊 Dosage"
                  color: "#60a5fa"
                  font.family: Theme.font
                  font.pixelSize: 11 * root.s
                  font.bold: true
                }
                Text {
                  width: parent.width
                  text: (modelData.details && modelData.details.dosage) ? modelData.details.dosage.substring(0, 300) + (modelData.details.dosage.length > 300 ? "..." : "") : qsTr("No data available")
                  color: "#cbd5e1"
                  font.family: Theme.font
                  font.pixelSize: 10 * root.s
                  wrapMode: Text.WordWrap
                }
              }
            }

            // Warnings
            Rectangle {
              width: parent.width
              height: warnCol.implicitHeight + 8 * root.s
              radius: 8 * root.s
              color: "#0f172a"
              border.width: 1
              border.color: "#1e293b"

              Column {
                id: warnCol
                x: 8 * root.s
                y: 4 * root.s
                width: parent.width - 16 * root.s
                spacing: 4 * root.s

                Text {
                  text: "⚠️ Warnings"
                  color: "#fbbf24"
                  font.family: Theme.font
                  font.pixelSize: 11 * root.s
                  font.bold: true
                }
                Text {
                  width: parent.width
                  text: (modelData.details && modelData.details.warnings) ? modelData.details.warnings.substring(0, 300) + (modelData.details.warnings.length > 300 ? "..." : "") : qsTr("No warnings")
                  color: "#cbd5e1"
                  font.family: Theme.font
                  font.pixelSize: 10 * root.s
                  wrapMode: Text.WordWrap
                }
              }
            }

            // Contraindications
            Rectangle {
              width: parent.width
              height: contraCol.implicitHeight + 8 * root.s
              radius: 8 * root.s
              color: "#0f172a"
              border.width: 1
              border.color: "#1e293b"

              Column {
                id: contraCol
                x: 8 * root.s
                y: 4 * root.s
                width: parent.width - 16 * root.s
                spacing: 4 * root.s

                Text {
                  text: "🚫 Contraindications"
                  color: "#fa3b30"
                  font.family: Theme.font
                  font.pixelSize: 11 * root.s
                  font.bold: true
                }
                Text {
                  width: parent.width
                  text: (modelData.details && modelData.details.contraindications) ? modelData.details.contraindications.substring(0, 300) + (modelData.details.contraindications.length > 300 ? "..." : "") : qsTr("None listed")
                  color: "#cbd5e1"
                  font.family: Theme.font
                  font.pixelSize: 10 * root.s
                  wrapMode: Text.WordWrap
                }
              }
            }

            // Adverse Reactions
            Rectangle {
              width: parent.width
              height: advCol.implicitHeight + 8 * root.s
              radius: 8 * root.s
              color: "#0f172a"
              border.width: 1
              border.color: "#1e293b"

              Column {
                id: advCol
                x: 8 * root.s
                y: 4 * root.s
                width: parent.width - 16 * root.s
                spacing: 4 * root.s

                Text {
                  text: "⚠️ Side Effects"
                  color: "#f472b6"
                  font.family: Theme.font
                  font.pixelSize: 11 * root.s
                  font.bold: true
                }
                Text {
                  width: parent.width
                  text: (modelData.details && modelData.details.adverse_reactions) ? modelData.details.adverse_reactions.substring(0, 300) + (modelData.details.adverse_reactions.length > 300 ? "..." : "") : qsTr("No data")
                  color: "#cbd5e1"
                  font.family: Theme.font
                  font.pixelSize: 10 * root.s
                  wrapMode: Text.WordWrap
                }
              }
            }

            // Drug Interactions
            Rectangle {
              width: parent.width
              height: interCol.implicitHeight + 8 * root.s
              radius: 8 * root.s
              color: "#0f172a"
              border.width: 1
              border.color: "#1e293b"

              Column {
                id: interCol
                x: 8 * root.s
                y: 4 * root.s
                width: parent.width - 16 * root.s
                spacing: 4 * root.s

                Text {
                  text: "🔄 Drug Interactions"
                  color: "#a78bfa"
                  font.family: Theme.font
                  font.pixelSize: 11 * root.s
                  font.bold: true
                }
                Text {
                  width: parent.width
                  text: (modelData.details && modelData.details.drug_interactions) ? modelData.details.drug_interactions.substring(0, 300) + (modelData.details.drug_interactions.length > 300 ? "..." : "") : qsTr("No interactions listed")
                  color: "#cbd5e1"
                  font.family: Theme.font
                  font.pixelSize: 10 * root.s
                  wrapMode: Text.WordWrap
                }
              }
            }

            // Missed dose note (from MedKit)
            Rectangle {
              width: parent.width
              height: missedCol.implicitHeight + 8 * root.s
              radius: 8 * root.s
              color: "#0f172a"
              border.width: 1
              border.color: "#1e293b"

              Column {
                id: missedCol
                x: 8 * root.s
                y: 4 * root.s
                width: parent.width - 16 * root.s
                spacing: 4 * root.s

                Text {
                  text: "⏰ Missed Dose"
                  color: "#60a5fa"
                  font.family: Theme.font
                  font.pixelSize: 11 * root.s
                  font.bold: true
                }
                Text {
                  width: parent.width
                  text: modelData.missed_dose_note || qsTr("No missed-dose guidance is available. Ask your doctor or pharmacist.")
                  color: "#cbd5e1"
                  font.family: Theme.font
                  font.pixelSize: 10 * root.s
                  wrapMode: Text.WordWrap
                }
              }
            }

            // Notes from MedKit
            Rectangle {
              width: parent.width
              height: notesCol.implicitHeight + 8 * root.s
              radius: 8 * root.s
              color: "#0f172a"
              border.width: 1
              border.color: "#1e293b"
              visible: modelData.notes && modelData.notes.length > 0

              Column {
                id: notesCol
                x: 8 * root.s
                y: 4 * root.s
                width: parent.width - 16 * root.s
                spacing: 4 * root.s

                Text {
                  text: "📝 Notes"
                  color: "#94a3b8"
                  font.family: Theme.font
                  font.pixelSize: 11 * root.s
                  font.bold: true
                }
                Text {
                  width: parent.width
                  text: modelData.notes || ""
                  color: "#cbd5e1"
                  font.family: Theme.font
                  font.pixelSize: 10 * root.s
                  wrapMode: Text.WordWrap
                }
              }
            }

            // Last updated
            Text {
              width: parent.width
              text: modelData.details && modelData.details.last_fetched ? qsTr("Last updated: " + new Date(modelData.details.last_fetched).toLocaleDateString()) : ""
              color: "#475569"
              font.family: Theme.font
              font.pixelSize: 9 * root.s
              horizontalAlignment: Text.AlignRight
            }
          }
        }
      }
    }

    // Disclaimer
    Rectangle {
      width: parent.width
      height: discCol.implicitHeight + 12 * root.s
      radius: 10 * root.s
      color: "#1c1917"
      border.width: 1
      border.color: "#44403c"

      Column {
        id: discCol
        x: 10 * root.s
        y: 6 * root.s
        width: parent.width - 20 * root.s
        spacing: 4 * root.s

        Text {
          text: "⚠️ Medical Disclaimer"
          color: "#fbbf24"
          font.family: Theme.font
          font.pixelSize: 10 * root.s
          font.bold: true
        }
        Text {
          width: parent.width
          text: qsTr("This is a wellness information tool, not medical advice. Drug info from public databases (OpenFDA) may not reflect current labeling. Always consult your doctor or pharmacist.")
          color: "#a8a29e"
          font.family: Theme.font
          font.pixelSize: 9 * root.s
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
