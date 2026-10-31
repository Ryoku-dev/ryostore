import QtQuick
import QtQuick.Shapes
import Quickshell
import Ryoku.Ui.Singletons
import shell.services

// App dock: a tab growing out of the bottom bar. Pinned apps first, then the
// windows open on this output. Click focuses or launches, right click pins.
Item {
  id: root

  required property var frameConfig
  property var settings: null
  property int borderThickness: frameConfig ? frameConfig.borderThickness : 5
  property color notchColor: frameConfig ? frameConfig.activeBorderColor : "#ba5f58"
  property color textColor: frameConfig ? frameConfig.activeTextColor : "#ffffff"
  property color mutedColor: frameConfig ? frameConfig.mutedColor : Qt.rgba(1, 1, 1, 0.6)
  property string fontFamily: "Adwaita Sans, Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  property string screenName: ""

  readonly property var store: root.settings ? root.settings.settings : ({})
  readonly property bool pinned: root.frameConfig.railMode("dock") === "always"
  property bool preview: false
  readonly property var pinnedApps: {
    const list = root.store.pinnedApps
    return Array.isArray(list) ? list : []
  }

  readonly property real iconSize: root.frameConfig.dockIconSize
  readonly property real itemWidth: root.iconSize + 16
  readonly property real itemHeight: root.iconSize + 12
  readonly property real pinSize: root.iconSize + 2
  readonly property real spacing: root.frameConfig.dockItemSpacing
  readonly property real sidePadding: root.frameConfig.dockSidePadding
  readonly property real flareRadius: root.frameConfig.dockFlareRadius
  readonly property real cornerRadius: root.frameConfig.dockCornerRadius

  function norm(id) {
    return String(id || "").replace(/\.desktop$/, "").trim().toLowerCase()
  }

  readonly property var desktopMap: {
    const out = {}
    const raw = DesktopEntries.applications.values || []
    for (let i = 0; i < raw.length; i++) {
      const app = raw[i]
      if (!app || !app.id) continue
      out[root.norm(app.id)] = app
    }
    return out
  }

  // One entry per app on this output, in the order the windows appear.
  readonly property var running: {
    const wins = Wm.windows || []
    const order = []
    const groups = {}
    for (let i = 0; i < wins.length; i++) {
      const w = wins[i]
      if (!w || !w.appId) continue
      if (root.screenName && w.output && String(w.output) !== root.screenName) continue
      const key = root.norm(w.appId)
      if (!groups[key]) {
        groups[key] = { key: key, windows: [] }
        order.push(key)
      }
      groups[key].windows.push(w)
    }
    return { order: order, groups: groups }
  }

  readonly property var items: {
    const out = []
    const seen = {}
    const groups = root.running.groups
    const focused = Wm.focusedWindow
    const focusedId = focused ? String(focused.id) : ""

    function add(key) {
      if (!key || seen[key]) return
      seen[key] = true
      const group = groups[key] || null
      const entry = root.desktopMap[key] || null
      let focusedHere = false
      if (group) {
        for (let i = 0; i < group.windows.length; i++) {
          if (String(group.windows[i].id) === focusedId) { focusedHere = true; break }
        }
      }
      out.push({
        appId: key,
        name: entry ? String(entry.name || key) : (group ? String(group.windows[0].title || key) : key),
        icon: entry ? String(entry.icon || "") : key,
        entry: entry,
        count: group ? group.windows.length : 0,
        running: group !== null,
        focused: focusedHere,
        pinned: root.pinnedApps.indexOf(key) >= 0
      })
    }

    for (let i = 0; i < root.pinnedApps.length; i++) add(root.norm(root.pinnedApps[i]))
    for (let i = 0; i < root.running.order.length; i++) add(root.running.order[i])
    return out
  }

  readonly property int itemCount: root.items.length

  readonly property real targetWidth: root.itemCount === 0 ? 0
    : root.sidePadding * 2 + root.flareRadius * 2
      + root.pinSize + 1
      + root.itemCount * root.itemWidth
      + (root.itemCount + 1) * root.spacing
  readonly property real targetHeight: root.borderThickness + root.itemHeight + root.frameConfig.dockVerticalPadding * 2

  property real animatedWidth: root.targetWidth
  Behavior on animatedWidth {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  readonly property bool isHovered: Boolean(dockHover.hovered) || Boolean(wakeHover.hovered)
  property bool menuOpen: false
  readonly property real targetReveal: (root.itemCount > 0
    && (root.preview || root.isHovered || root.pinned || root.menuOpen)) ? 1.0 : 0.0
  property real revealProgress: root.targetReveal

  Behavior on revealProgress {
    NumberAnimation {
      duration: root.revealProgress > 0 ? 260 : 200
      easing.type: root.revealProgress > 0 ? Easing.OutBack : Easing.OutCubic
      easing.overshoot: root.revealProgress > 0 ? 1.06 : 1.0
    }
  }

  readonly property real currentHeight: root.borderThickness
    + (root.revealProgress * (root.targetHeight - root.borderThickness))
    + (Math.sin(Math.min(1.0, Math.max(0.0, root.revealProgress)) * Math.PI) * 4.0)

  readonly property real effectiveFlare: Math.min(root.flareRadius,
    Math.max(0, (root.currentHeight - root.borderThickness) * 0.35))
  readonly property real effectiveCorner: Math.min(root.cornerRadius,
    Math.max(0, (root.currentHeight - root.borderThickness) - root.effectiveFlare))

  property alias maskItem: dockContainer
  property alias wakeItem: wakeZone

  function iconSource(item) {
    if (!item) return ""
    const name = item.icon && item.icon.length > 0 ? item.icon : item.appId
    return Icons.path(name, "application-x-executable")
  }

  function activate(item) {
    if (!item) return
    const group = root.running.groups[item.appId] || null
    if (group && group.windows.length > 0) {
      let target = group.windows[0]
      const focused = Wm.focusedWindow
      if (focused) {
        for (let i = 0; i < group.windows.length; i++) {
          if (String(group.windows[i].id) === String(focused.id)) {
            target = group.windows[(i + 1) % group.windows.length]
            break
          }
        }
      }
      Wm.focusWindow(target.id)
      return
    }
    if (item.entry) AppLaunch.run(item.entry, null)
  }

  function togglePin(item) {
    if (!item || !root.settings) return
    const next = root.pinnedApps.slice()
    const at = next.indexOf(item.appId)
    if (at >= 0) next.splice(at, 1)
    else next.push(item.appId)
    root.settings.update("pinnedApps", next)
  }

  function togglePinned() {
    if (!root.settings) return
    root.settings.setRail("dock", root.pinned ? "auto" : "always")
  }

  function openMenu(item, slot) {
    if (!item) return
    const actions = [{
      label: item.pinned ? "Unpin from dock" : "Pin to dock",
      run: function() { root.togglePin(item) }
    }]
    if (item.entry) actions.push({
      label: "New window",
      run: function() { AppLaunch.run(item.entry, null) }
    })
    if (item.running) actions.push({
      label: item.count > 1 ? "Close all windows" : "Close window",
      run: function() {
        const group = root.running.groups[item.appId]
        if (!group) return
        for (let i = 0; i < group.windows.length; i++) Wm.closeWindow(group.windows[i].id)
      }
    })
    root.menuOpen = true
    dockMenu.openFor(slot, actions)
  }

  DockMenu {
    id: dockMenu
    onClosed: root.menuOpen = false
  }

  Item {
    id: wakeZone
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    width: root.itemCount === 0 ? 0
      : Math.max(root.animatedWidth, root.frameConfig.dockWakeWidth)
    height: root.borderThickness + root.frameConfig.dockWakeHeight

    HoverHandler {
      id: wakeHover
    }
  }

  Item {
    id: dockContainer
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    width: root.animatedWidth
    height: root.currentHeight

    HoverHandler {
      id: dockHover
      cursorShape: Qt.ArrowCursor
    }

    Shape {
      id: dockShape
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      visible: root.animatedWidth > root.borderThickness + 2

      readonly property real w: dockContainer.width
      readonly property real h: dockContainer.height
      readonly property real b: root.borderThickness
      readonly property real rf: root.effectiveFlare
      readonly property real rc: root.effectiveCorner
      readonly property real bleed: 2

      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.notchColor
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        startX: 0
        startY: dockShape.h + dockShape.bleed

        PathLine {
          x: dockShape.w
          y: dockShape.h + dockShape.bleed
        }

        PathLine {
          x: dockShape.w
          y: dockShape.h - dockShape.b
        }

        PathCubic {
          x: dockShape.w - dockShape.rf
          y: dockShape.h - dockShape.b - dockShape.rf
          control1X: dockShape.w - (dockShape.rf * 0.5)
          control1Y: dockShape.h - dockShape.b
          control2X: dockShape.w - dockShape.rf
          control2Y: dockShape.h - dockShape.b - (dockShape.rf * 0.5)
        }

        PathLine {
          x: dockShape.w - dockShape.rf
          y: dockShape.rc
        }

        PathArc {
          x: dockShape.w - dockShape.rf - dockShape.rc
          y: 0
          radiusX: Math.max(1, dockShape.rc)
          radiusY: Math.max(1, dockShape.rc)
          direction: PathArc.Counterclockwise
        }

        PathLine {
          x: dockShape.rf + dockShape.rc
          y: 0
        }

        PathArc {
          x: dockShape.rf
          y: dockShape.rc
          radiusX: Math.max(1, dockShape.rc)
          radiusY: Math.max(1, dockShape.rc)
          direction: PathArc.Counterclockwise
        }

        PathLine {
          x: dockShape.rf
          y: dockShape.h - dockShape.b - dockShape.rf
        }

        PathCubic {
          x: 0
          y: dockShape.h - dockShape.b
          control1X: dockShape.rf
          control1Y: dockShape.h - dockShape.b - (dockShape.rf * 0.5)
          control2X: dockShape.rf * 0.5
          control2Y: dockShape.h - dockShape.b
        }

        PathLine {
          x: 0
          y: dockShape.h + dockShape.bleed
        }
      }
    }

    Row {
      id: itemRow
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: root.borderThickness / 2
      spacing: root.spacing

      opacity: Math.max(0.0, (root.revealProgress - 0.35) / 0.65)
      visible: opacity > 0.01

      Item {
        id: pinButton
        width: root.pinSize
        height: root.itemHeight

        Rectangle {
          anchors.centerIn: parent
          width: root.pinSize
          height: root.pinSize
          radius: root.frameConfig.dockItemRadius
          color: root.pinned
            ? Qt.rgba(root.frameConfig.accentColor.r, root.frameConfig.accentColor.g,
                      root.frameConfig.accentColor.b, 0.22)
            : (pinHover.hovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)
                                : "transparent")
          Behavior on color { ColorAnimation { duration: 140 } }
        }

        Text {
          anchors.centerIn: parent
          text: "\uf08d"
          font.family: Theme.mono
          font.pixelSize: Math.round(root.iconSize * 0.42)
          color: root.pinned
            ? root.frameConfig.accentColor
            : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.45)
          Behavior on color { ColorAnimation { duration: 140 } }
        }

        HoverHandler {
          id: pinHover
          cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
          onTapped: root.togglePinned()
        }
      }

      Item {
        width: 1
        height: root.itemHeight

        Rectangle {
          anchors.centerIn: parent
          width: 1
          height: Math.round(root.itemHeight * 0.52)
          color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.16)
        }
      }

      Repeater {
        model: root.items

        delegate: Item {
          id: dockItem
          required property var modelData

          readonly property bool hovered: Boolean(itemHover.hovered)

          width: root.itemWidth
          height: root.itemHeight

          Image {
            id: itemIcon
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: root.iconSize
            height: root.iconSize
            sourceSize.width: root.iconSize * 2
            sourceSize.height: root.iconSize * 2
            source: root.iconSource(dockItem.modelData)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            opacity: (dockItem.modelData.running || dockItem.hovered) ? 1.0 : 0.72
          }

          Text {
            anchors.centerIn: itemIcon
            visible: itemIcon.status !== Image.Ready
            text: dockItem.modelData.name.length > 0
              ? dockItem.modelData.name.charAt(0).toUpperCase()
              : "?"
            font.family: root.fontFamily
            font.pixelSize: Math.round(root.iconSize * 0.5)
            font.bold: true
            color: root.textColor
          }

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: 4
            height: 4
            radius: 2
            visible: dockItem.modelData.running
            color: dockItem.modelData.focused
              ? root.textColor
              : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.5)
          }

          HoverHandler {
            id: itemHover
            cursorShape: Qt.PointingHandCursor
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
              if (mouse.button === Qt.RightButton) root.openMenu(dockItem.modelData, dockItem)
              else root.activate(dockItem.modelData)
            }
          }
        }
      }
    }
  }
}
