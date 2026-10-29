pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

Item {
  id: root
  property var pluginApi
  property var screen
  property bool active
  property string density: "full"
  property real s: 1
  property real widthBudget: 360

  readonly property var service: pluginApi ? pluginApi.mainInstance : null
  readonly property real contentW: Math.min(widthBudget > 0 ? widthBudget : 360 * s, 496 * s)
  property real customGrams: 4
  property bool quickAddExpanded: false
  implicitWidth: contentW
  implicitHeight: body.implicitHeight

  Column {
    id: body
    width: root.contentW
    spacing: 12 * root.s

    Row {
      width: root.contentW
      spacing: 10 * root.s
      Column {
        width: root.contentW - 118 * root.s
        spacing: 3 * root.s
        MicroLabel { label: qsTr("SWEETENER TODAY"); s: root.s }
        Text {
          width: parent.width
          text: root.service ? root.service.todayGrams + " g" : "—"
          color: root.service?.overGoal ? Theme.brand : Theme.cream
          font.family: Theme.font
          font.pixelSize: 28 * root.s
          font.bold: true
        }
      }
      Column {
        width: 108 * root.s
        spacing: 3 * root.s
        anchors.bottom: parent.bottom
        MicroLabel { label: qsTr("DAILY GOAL"); s: root.s }
        Text {
          width: parent.width
          text: root.service ? root.service.dailyGoal + " g" : "25 g"
          color: Theme.subtle
          font.family: Theme.font
          font.pixelSize: 15 * root.s
        }
      }
    }

    Rectangle {
      width: root.contentW
      height: 5 * root.s
      radius: 3 * root.s
      color: Theme.tileBg
      Rectangle {
        width: parent.width * Math.min(1, root.service ? root.service.todayGrams / root.service.dailyGoal : 0)
        height: parent.height
        radius: parent.radius
        color: root.service?.overGoal ? Theme.brand : Theme.cream
      }
    }

    Item {
      width: root.contentW
      height: 42 * root.s
      Rectangle {
        anchors.fill: parent
        radius: Motion.rSmall * root.s
        color: toggleTap.containsMouse ? Theme.brand : Theme.tileBg
        border.width: 1
        border.color: Theme.border
        Behavior on color { ColorAnimation { duration: Motion.fast } }
      }
      Row {
        anchors.fill: parent
        anchors.leftMargin: 12 * root.s
        anchors.rightMargin: 12 * root.s
        spacing: 8 * root.s
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: qsTr("Quick add")
          color: Theme.cream
          font.family: Theme.font
          font.pixelSize: 12 * root.s
          font.bold: true
        }
        Item { width: root.contentW - 132 * root.s; height: 1 }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.quickAddExpanded ? "−" : "+"
          color: Theme.cream
          font.family: Theme.font
          font.pixelSize: 18 * root.s
          font.bold: true
        }
      }
      MouseArea {
        id: toggleTap
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.quickAddExpanded = !root.quickAddExpanded
      }
    }

    Column {
      width: root.contentW
      spacing: 8 * root.s
      visible: root.quickAddExpanded
      opacity: visible ? 1 : 0
      Repeater {
        model: [
          { label: qsTr("Sugar (white)"), grams: Number(root.pluginApi?.pluginSettings?.whiteSugarGrams ?? 4) },
          { label: qsTr("Brown sugar"), grams: Number(root.pluginApi?.pluginSettings?.brownSugarGrams ?? 4) },
          { label: qsTr("Stevia"), grams: Number(root.pluginApi?.pluginSettings?.steviaGrams ?? 1) },
        ]
        delegate: Item {
          required property var modelData
          width: root.contentW
          height: 38 * root.s
          Rectangle {
            anchors.fill: parent
            radius: Motion.rSmall * root.s
            color: tap.containsMouse ? Theme.brand : Theme.tileBg
            border.width: 1
            border.color: Theme.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }
          }
          Row {
            anchors.fill: parent
            anchors.leftMargin: 10 * root.s
            anchors.rightMargin: 10 * root.s
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: Theme.cream
              font.family: Theme.font
              font.pixelSize: 12 * root.s
            }
            Item { width: root.contentW - 116 * root.s; height: 1 }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "+" + modelData.grams + " g"
              color: Theme.cream
              font.family: Theme.font
              font.pixelSize: 12 * root.s
              font.bold: true
            }
          }
          MouseArea {
            id: tap
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.service?.addSugar(modelData.grams, modelData.label)
          }
        }
      }
    }

    Row {
      width: root.contentW
      spacing: 8 * root.s
      Rectangle {
        width: root.contentW - 100 * root.s
        height: 38 * root.s
        radius: Motion.rSmall * root.s
        color: Theme.tileBg
        border.width: 1
        border.color: Theme.border
        TextInput {
          id: customField
          anchors.fill: parent
          anchors.leftMargin: 10 * root.s
          anchors.rightMargin: 10 * root.s
          verticalAlignment: TextInput.AlignVCenter
          text: String(root.customGrams)
          color: Theme.cream
          font.family: Theme.font
          font.pixelSize: 13 * root.s
          inputMethodHints: Qt.ImhDigitsOnly
          validator: DoubleValidator { bottom: 0.1; top: 200; decimals: 1 }
          onTextChanged: {
            var amount = Number(text)
            if (isFinite(amount) && amount > 0 && amount <= 200) root.customGrams = amount
          }
        }
      }
      Item {
        width: 92 * root.s
        height: 38 * root.s
        Rectangle {
          anchors.fill: parent
          radius: Motion.rSmall * root.s
          color: addMouse.containsMouse ? Theme.brand : "transparent"
          border.width: 1
          border.color: Theme.brand
        }
        Text {
          anchors.centerIn: parent
          text: qsTr("Add amount")
          color: Theme.cream
          font.family: Theme.font
          font.pixelSize: 11 * root.s
          font.bold: true
        }
        MouseArea {
          id: addMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.service?.addSugar(root.customGrams, qsTr("Custom sugar"))
        }
      }
    }

    Rectangle { width: root.contentW; height: 1; color: Theme.border }

    Row {
      width: root.contentW
      MicroLabel { label: qsTr("TODAY'S LOG"); s: root.s }
      Item { width: root.contentW - 160 * root.s; height: 1 }
      Text {
        text: qsTr("Undo")
        color: root.service?.todayEntries.length > 0 ? Theme.subtle : Theme.border
        font.family: Theme.font
        font.pixelSize: 11 * root.s
        MouseArea {
          anchors.fill: parent
          enabled: root.service?.todayEntries.length > 0
          cursorShape: Qt.PointingHandCursor
          onClicked: root.service?.undoLast()
        }
      }
      Text {
        text: qsTr("Clear")
        color: root.service?.todayEntries.length > 0 ? Theme.brand : Theme.border
        font.family: Theme.font
        font.pixelSize: 11 * root.s
        MouseArea {
          anchors.fill: parent
          enabled: root.service?.todayEntries.length > 0
          cursorShape: Qt.PointingHandCursor
          onClicked: root.service?.clearToday()
        }
      }
    }

    Text {
      width: root.contentW
      visible: !root.service || root.service.todayEntries.length === 0
      text: qsTr("Nothing logged today.")
      color: Theme.subtle
      font.family: Theme.font
      font.pixelSize: 12 * root.s
    }

    Column {
      width: root.contentW
      spacing: 4 * root.s
      Repeater {
        model: {
          var rows = root.service ? root.service.todayEntries.slice() : []
          rows.reverse()
          return rows.slice(0, 8)
        }
        delegate: Row {
          required property var modelData
          width: root.contentW
          spacing: 6 * root.s
          Text {
            width: root.contentW - 68 * root.s
            text: Qt.formatTime(new Date(modelData.t), "hh:mm") + "  ·  " + modelData.name
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            elide: Text.ElideRight
          }
          Text {
            width: 62 * root.s
            horizontalAlignment: Text.AlignRight
            text: modelData.grams + " g"
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 12 * root.s
          }
        }
      }
    }

    Rectangle { width: root.contentW; height: 1; color: Theme.border }

    Column {
      width: root.contentW
      spacing: 4 * root.s
      MicroLabel { label: qsTr("DAILY SWEETENER GOAL · GRAMS"); s: root.s }
      Text {
        width: root.contentW
        text: root.service
          ? (root.service.todayGrams <= root.service.dailyGoal
            ? (root.service.dailyGoal - root.service.todayGrams).toFixed(1) + " g remaining"
            : (root.service.todayGrams - root.service.dailyGoal).toFixed(1) + " g over goal")
          : ""
        color: Theme.subtle
        font.family: Theme.font
        font.pixelSize: 12 * root.s
      }
      Text {
        width: root.contentW
        text: qsTr("Set your daily target and tap amounts in Ryoku Settings → Plugins → Sugar Tracker.")
        color: Theme.subtle
        font.family: Theme.font
        font.pixelSize: 10 * root.s
        wrapMode: Text.WordWrap
      }
    }
  }
}
