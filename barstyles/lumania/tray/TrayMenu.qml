pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import shell.services

Item {
  id: root

  property string service: ""
  property real anchorX: 0
  property real anchorY: 0
  property real anchorW: 0
  property real anchorH: 0
  property bool open: false
  property var expanded: ({})

  signal closed()
  property var targetScreen: null

  readonly property real margin: 8
  readonly property real gap: 6

  readonly property var currentItem: {
    var items = Tray.items
    for (var i = 0; i < items.length; ++i)
      if (items[i] && items[i].service === root.service)
        return items[i]
    return null
  }
  readonly property var menu: root.currentItem ? root.currentItem.menu : null

  onMenuChanged: if (root.open && !root.menu) root.close()

  function openFor(item, slot) {
    if (!item || !slot) return
    var p = slot.mapToGlobal(0, 0)
    root.anchorX = p.x
    root.anchorY = p.y
    root.anchorW = slot.width
    root.anchorH = slot.height
    root.targetScreen = (slot.QsWindow && slot.QsWindow.window)
      ? slot.QsWindow.window.screen : null
    root.service = item.service
    root.expanded = ({})
    Tray.aboutToShow(item.service)
    root.open = true
  }

  function close() {
    if (!root.open) return
    root.open = false
    root.closed()
  }

  function activate(id) {
    Tray.menuEvent(root.service, id)
    root.close()
  }

  function isExpanded(id) { return !!root.expanded[id] }

  function toggleExpand(id) {
    var next = {}
    for (var k in root.expanded) next[k] = root.expanded[k]
    if (next[id]) delete next[id]
    else next[id] = true
    root.expanded = next
  }

  function cleanLabel(text) {
    if (!text) return ""
    return String(text).replace(/_([^_])/g, "$1").replace(/__/g, "_")
  }

  function rowsFor(node, depth, out) {
    var kids = (node && node.children) ? node.children : []
    for (var i = 0; i < kids.length; ++i) {
      var child = kids[i]
      if (!child || child.visible === false) continue
      var sep = child.type === "separator"
      var hasKids = !sep && Array.isArray(child.children) && child.children.length > 0
      out.push({ node: child, depth: depth, sep: sep, hasKids: hasKids })
      if (hasKids && root.isExpanded(child.id)) root.rowsFor(child, depth + 1, out)
    }
    return out
  }

  readonly property var rows: (root.open && root.menu) ? root.rowsFor(root.menu, 0, []) : []

  Loader {
    active: root.open
    sourceComponent: overlayComp
  }

  Component {
    id: overlayComp

    PanelWindow {
      id: menuWin
      color: "transparent"
      screen: root.targetScreen
      exclusionMode: ExclusionMode.Ignore
      exclusiveZone: 0
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
      WlrLayershell.namespace: "ryoku-lumania-tray-menu"

      anchors { top: true; bottom: true; left: true; right: true }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.close()
      }

      Rectangle {
        id: card
        readonly property real bw: Theme.borderWidth
        readonly property real minW: 170
        readonly property real maxW: Math.min(340, menuWin.width - 2 * root.margin)
        readonly property real maxH: menuWin.height - 2 * root.margin
        readonly property real innerW: Math.max(Math.min(body.implicitWidth, maxW), minW)
        property bool grown: false

        width: innerW + bw * 2
        height: Math.min(body.implicitHeight + bw * 2, maxH)
        x: Math.max(root.margin, Math.min(
          root.anchorX + root.anchorW / 2 - width / 2,
          menuWin.width - width - root.margin))
        y: Math.max(root.margin, Math.min(
          root.anchorY + root.anchorH + root.gap,
          menuWin.height - height - root.margin))

        radius: Theme.radiusWindow
        color: Theme.surface
        border.width: bw
        border.color: Theme.outline
        focus: true
        Keys.onEscapePressed: root.close()
        Component.onCompleted: {
          card.forceActiveFocus()
          card.grown = true
        }

        opacity: card.grown ? Theme.windowOpacity : 0
        Behavior on opacity {
          enabled: !Motion.reduce
          NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
        }
        transform: Scale {
          origin.x: card.width / 2
          origin.y: 0
          xScale: card.grown ? 1 : 0.96
          yScale: card.grown ? 1 : 0.96
          Behavior on xScale { enabled: !Motion.reduce; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
          Behavior on yScale { enabled: !Motion.reduce; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Flickable {
          anchors.fill: parent
          anchors.margins: card.bw
          contentWidth: width
          contentHeight: body.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          Column {
            id: body
            width: parent.width
            topPadding: 6
            bottomPadding: 6

            Repeater {
              model: root.rows

              delegate: Item {
                id: row
                required property var modelData
                readonly property var node: modelData.node
                readonly property int depth: modelData.depth
                readonly property bool sep: modelData.sep
                readonly property bool hasKids: modelData.hasKids
                readonly property bool rowEnabled: node.enabled !== false
                readonly property string toggleType: node.toggleType || ""
                readonly property bool toggled: (node.toggleState || 0) === 1
                readonly property string iconName: node.iconName || ""
                readonly property bool hasLead: toggleType.length > 0 || iconName.length > 0
                readonly property string label: root.cleanLabel(node.label)
                readonly property real indent: 10 + depth * 14
                readonly property real leadW: Theme.iconSm + 8
                readonly property real chevW: Theme.iconSm + 12

                width: parent.width
                height: sep ? 9 : 30

                Rectangle {
                  visible: row.sep
                  x: row.indent
                  width: Math.max(0, row.width - row.indent - 10)
                  height: 1
                  anchors.verticalCenter: parent.verticalCenter
                  color: Theme.outlineVariant
                }

                Rectangle {
                  visible: !row.sep
                  anchors.fill: parent
                  anchors.leftMargin: 4
                  anchors.rightMargin: 4
                  anchors.topMargin: 1
                  anchors.bottomMargin: 1
                  radius: Theme.radiusWidget
                  color: (hover.hovered && row.rowEnabled)
                    ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                    : "transparent"
                  Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                }

                Text {
                  visible: !row.sep && row.toggleType.length > 0
                  anchors.left: parent.left
                  anchors.leftMargin: row.indent
                  anchors.verticalCenter: parent.verticalCenter
                  text: row.toggleType === "radio"
                    ? (row.toggled ? "\u25cf" : "\u25cb")
                    : (row.toggled ? "\u2713" : "")
                  font.family: Theme.fontPrimary
                  font.pixelSize: 12
                  color: !row.rowEnabled
                    ? Qt.rgba(Theme.onSurfaceVariant.r, Theme.onSurfaceVariant.g, Theme.onSurfaceVariant.b, 0.38)
                    : (row.toggled ? Theme.onSurface : Theme.onSurfaceVariant)
                }

                Image {
                  visible: !row.sep && row.toggleType.length === 0 && row.iconName.length > 0
                  anchors.left: parent.left
                  anchors.leftMargin: row.indent
                  anchors.verticalCenter: parent.verticalCenter
                  width: Theme.iconSm
                  height: Theme.iconSm
                  sourceSize.width: width
                  sourceSize.height: height
                  smooth: true
                  asynchronous: true
                  source: row.iconName.length > 0 ? Icons.path(row.iconName, "") : ""
                  opacity: row.rowEnabled ? 1 : 0.38
                }

                Text {
                  id: labelText
                  visible: !row.sep
                  anchors.left: parent.left
                  anchors.leftMargin: row.indent + (row.hasLead ? row.leadW : 0)
                  anchors.right: parent.right
                  anchors.rightMargin: row.hasKids ? row.chevW : 10
                  anchors.verticalCenter: parent.verticalCenter
                  text: row.label
                  elide: Text.ElideRight
                  color: row.rowEnabled ? Theme.onSurface
                    : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.38)
                  font.family: Theme.fontPrimary
                  font.pixelSize: 13
                }

                Text {
                  visible: !row.sep && row.hasKids
                  anchors.right: parent.right
                  anchors.rightMargin: 8
                  anchors.verticalCenter: parent.verticalCenter
                  text: "\u203a"
                  rotation: root.isExpanded(row.node.id) ? 90 : 0
                  font.family: Theme.fontPrimary
                  font.pixelSize: 15
                  color: row.rowEnabled ? Theme.onSurfaceVariant
                    : Qt.rgba(Theme.onSurfaceVariant.r, Theme.onSurfaceVariant.g, Theme.onSurfaceVariant.b, 0.38)
                  Behavior on rotation { enabled: !Motion.reduce; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                }

                HoverHandler { id: hover; enabled: row.rowEnabled && !row.sep; cursorShape: Qt.PointingHandCursor }

                MouseArea {
                  anchors.fill: parent
                  enabled: row.rowEnabled && !row.sep
                  acceptedButtons: Qt.LeftButton
                  onClicked: {
                    if (row.hasKids) root.toggleExpand(row.node.id)
                    else root.activate(row.node.id)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
