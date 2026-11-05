pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import shell.services

// Small dropdown for a dock item, anchored above the icon.
Item {
  id: root

  property bool open: false
  property real anchorX: 0
  property real anchorY: 0
  property real anchorW: 0
  property var targetScreen: null
  property var actions: []

  signal closed()

  readonly property real margin: 8
  readonly property real gap: 8
  readonly property real cardWidth: 164

  function openFor(slot, list) {
    if (!slot) return
    var win = (slot.QsWindow && slot.QsWindow.window) ? slot.QsWindow.window : null
    var scr = win ? win.screen : null
    // Layer shell windows do not expose their position, so place the card from
    // the dock window, which is anchored to the bottom centre of the screen.
    var p = slot.mapToItem(null, 0, 0)
    var winW = win ? win.width : 0
    var winH = win ? win.height : 0
    var offX = scr ? Math.round((scr.width - winW) / 2) : 0
    var offY = scr ? scr.height - winH : 0
    root.anchorX = offX + p.x
    root.anchorY = offY + p.y
    root.anchorW = slot.width
    root.targetScreen = scr
    root.actions = list || []
    root.open = true
  }

  function close() {
    if (!root.open) return
    root.open = false
    root.closed()
  }

  function run(index) {
    var action = root.actions[index]
    if (!action || action.enabled === false) return
    root.close()
    if (typeof action.run === "function") action.run()
  }

  PanelWindow {
    id: menuWin
    visible: root.open
    color: "transparent"
    screen: root.targetScreen
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "ryoku-lumania-dock-menu"

    anchors { top: true; bottom: true; left: true; right: true }

    onVisibleChanged: if (visible) card.forceActiveFocus()

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onPressed: root.close()
    }

    Rectangle {
      id: card
      readonly property real bw: Theme.borderWidth

      width: root.cardWidth + bw * 2
      height: body.implicitHeight + bw * 2
      x: Math.max(root.margin, Math.min(
        root.anchorX + root.anchorW / 2 - width / 2,
        menuWin.width - width - root.margin))
      y: Math.max(root.margin, root.anchorY - height - root.gap)

      radius: Theme.radiusWindow
      color: Theme.surface
      border.width: bw
      border.color: Theme.outline
      focus: true
      Keys.onEscapePressed: root.close()

      MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

      Column {
        id: body
        anchors.centerIn: parent
        width: parent.width - card.bw * 2
        topPadding: 5
        bottomPadding: 5

        Repeater {
          model: root.actions

          delegate: Item {
            id: row
            required property var modelData
            required property int index

            readonly property bool rowEnabled: modelData.enabled !== false

            width: body.width
            height: 28

            Rectangle {
              anchors.fill: parent
              anchors.leftMargin: 3
              anchors.rightMargin: 3
              anchors.topMargin: 1
              anchors.bottomMargin: 1
              radius: Theme.radiusWidget
              color: (rowHover.hovered && row.rowEnabled)
                ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                : "transparent"
              Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 11
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: row.modelData.label || ""
              elide: Text.ElideRight
              color: row.rowEnabled ? Theme.onSurface
                : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.38)
              font.family: Theme.fontPrimary
              font.pixelSize: 12
            }

            HoverHandler {
              id: rowHover
              enabled: row.rowEnabled
              cursorShape: Qt.PointingHandCursor
            }

            MouseArea {
              anchors.fill: parent
              enabled: row.rowEnabled
              acceptedButtons: Qt.LeftButton
              onClicked: root.run(row.index)
            }
          }
        }
      }
    }
  }
}
