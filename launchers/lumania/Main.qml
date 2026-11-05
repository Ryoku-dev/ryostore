pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import shell.services
import Ryoku.Ui.Singletons
import "components"

Scope {
  id: root

  property bool openRequested: false
  property string monitor: ""
  property bool closing: false
  readonly property bool shown: root.openRequested || root.closing

  readonly property var hostScreen: {
    const list = Quickshell.screens
    if (root.monitor) {
      for (const s of list) {
        if (s.name === root.monitor) return s
      }
    }
    return Quickshell.primaryScreen ?? (list.length > 0 ? list[0] : null)
  }

  function show(mon) {
    if (mon) root.monitor = mon
    root.closing = false
    root.openRequested = true
  }

  function hide() {
    if (!root.openRequested && !root.closing) return
    root.closing = true
    root.openRequested = false
  }

  function toggle(mon) {
    if (root.openRequested || root.closing) root.hide()
    else root.show(mon)
  }

  function stateDump() {
    return {
      open: root.openRequested,
      query: root.query,
      resultCount: root.filteredApps.length
    }
  }

  // Frame geometry, mirrored from the bar style so the panel grows out of the
  // bottom-left corner it is opened from.
  readonly property int frameThickness: 5
  readonly property real collapsedWidth: 110
  readonly property real collapsedHeight: 105
  readonly property real expandedWidth: 660
  readonly property real expandedHeight: 645

  readonly property color accentColor: Theme.primary
  readonly property color cardColor: Theme.surface
  readonly property color textColor: Theme.onSurface
  readonly property color mutedColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.62)
  readonly property string fontFamily: "Adwaita Sans, Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  readonly property string iconFont: "JetBrainsMono Nerd Font, Font Awesome 7 Free, sans-serif"

  readonly property real flareRadius: 12
  readonly property real cornerRadius: 10
  readonly property int gridColumns: 5
  readonly property real gridCellHeight: 86
  readonly property real searchBarHeight: 46

  property real openProgress: 0

  Behavior on openProgress {
    NumberAnimation {
      duration: root.openRequested ? Motion.dur(380) : Motion.dur(260)
      easing.type: root.openRequested ? Easing.OutBack : Easing.OutCubic
      easing.overshoot: 1.08
    }
  }

  onOpenRequestedChanged: root.openProgress = root.openRequested ? 1 : 0

  onOpenProgressChanged: {
    if (!root.openRequested && root.openProgress < 0.01)
      root.closing = false
  }

  readonly property real currentWidth: root.collapsedWidth
    + root.openProgress * (root.expandedWidth - root.collapsedWidth)
  readonly property real currentHeight: root.collapsedHeight
    + root.openProgress * (root.expandedHeight - root.collapsedHeight)

  // Apps
  property var allApps: []
  property var filteredApps: []
  property var recentAppIds: []
  property var hiddenAppIds: []
  property int selectedIndex: 0
  property string query: ""

  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
    || (Quickshell.env("HOME") + "/.local/state")
  readonly property string recentsPath: root.stateHome + "/ryoku/lumania-recents.json"
  readonly property string launcherConfigPath: (Quickshell.env("XDG_CONFIG_HOME")
    || (Quickshell.env("HOME") + "/.config")) + "/ryoku/launcher.json"

  function normalizeId(id) {
    return String(id || "").replace(/\.desktop$/, "").trim().toLowerCase()
  }

  function refreshApps() {
    const out = []
    const seen = {}
    const raw = DesktopEntries.applications.values || []
    for (let i = 0; i < raw.length; i++) {
      const app = raw[i]
      if (!app || !app.id || app.noDisplay) continue
      const id = String(app.id)
      if (seen[id]) continue
      seen[id] = true
      if (root.hiddenAppIds.indexOf(root.normalizeId(id)) >= 0) continue
      out.push({
        id: id,
        name: String(app.name || id),
        subtext: String(app.comment || app.genericName || ""),
        icon: String(app.icon || ""),
        entry: app
      })
    }
    out.sort(function(a, b) { return a.name.localeCompare(b.name) })
    root.allApps = out
    root.updateFilter()
  }

  function updateFilter() {
    const q = root.query.trim().toLowerCase()
    if (!q) {
      const recent = []
      const taken = {}
      for (let r = 0; r < root.recentAppIds.length && recent.length < root.gridColumns; r++) {
        const target = root.normalizeId(root.recentAppIds[r])
        for (let a = 0; a < root.allApps.length; a++) {
          const app = root.allApps[a]
          if (taken[app.id]) continue
          if (root.normalizeId(app.id) === target) {
            taken[app.id] = true
            recent.push(app)
            break
          }
        }
      }
      const rest = []
      for (let k = 0; k < root.allApps.length; k++) {
        if (!taken[root.allApps[k].id]) rest.push(root.allApps[k])
      }
      root.filteredApps = recent.concat(rest)
      root.selectedIndex = 0
      return
    }

    const exact = []
    const prefix = []
    const fuzzy = []
    for (let i = 0; i < root.allApps.length; i++) {
      const item = root.allApps[i]
      const name = item.name.toLowerCase()
      const sub = item.subtext.toLowerCase()
      const id = item.id.toLowerCase()
      if (name === q) exact.push(item)
      else if (name.indexOf(q) === 0 || id.indexOf(q) === 0) prefix.push(item)
      else if (name.indexOf(q) > 0 || sub.indexOf(q) >= 0 || id.indexOf(q) >= 0) fuzzy.push(item)
    }

    function byRecent(list) {
      if (root.recentAppIds.length === 0) return list
      return list.sort(function(a, b) {
        const ai = root.recentAppIds.indexOf(root.normalizeId(a.id))
        const bi = root.recentAppIds.indexOf(root.normalizeId(b.id))
        if (ai !== -1 && bi !== -1) return ai - bi
        if (ai !== -1) return -1
        if (bi !== -1) return 1
        return a.name.localeCompare(b.name)
      })
    }

    root.filteredApps = byRecent(exact).concat(byRecent(prefix)).concat(byRecent(fuzzy))
    root.selectedIndex = 0
  }

  function selectNext() {
    if (root.filteredApps.length === 0) return
    root.selectedIndex = (root.selectedIndex + 1) % root.filteredApps.length
  }

  function selectPrev() {
    if (root.filteredApps.length === 0) return
    root.selectedIndex = (root.selectedIndex - 1 + root.filteredApps.length) % root.filteredApps.length
  }

  function selectDown() {
    if (root.filteredApps.length === 0) return
    const next = root.selectedIndex + root.gridColumns
    root.selectedIndex = next < root.filteredApps.length ? next : root.filteredApps.length - 1
  }

  function selectUp() {
    if (root.filteredApps.length === 0) return
    const prev = root.selectedIndex - root.gridColumns
    root.selectedIndex = prev >= 0 ? prev : 0
  }

  function activateCurrent() {
    if (root.selectedIndex >= 0 && root.selectedIndex < root.filteredApps.length)
      root.launchItem(root.filteredApps[root.selectedIndex])
  }

  function recordRecent(id) {
    const norm = root.normalizeId(id)
    if (!norm) return
    const list = [norm]
    for (let i = 0; i < root.recentAppIds.length && list.length < 15; i++) {
      const item = root.normalizeId(root.recentAppIds[i])
      if (item && item !== norm && list.indexOf(item) === -1) list.push(item)
    }
    root.recentAppIds = list
    Quickshell.execDetached(["sh", "-c",
      "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
      "lumania-recents", root.recentsPath, JSON.stringify(list)])
  }

  function launchItem(item) {
    if (!item) return
    root.recordRecent(item.id)
    root.hide()
    AppLaunch.run(item.entry, null)
  }

  function iconSource(item) {
    if (!item) return ""
    return Icons.path(item.icon, "application-x-executable")
  }

  function rubberBand(overshoot, d) {
    if (overshoot <= 0) return 0
    const c = 0.55
    return (1.0 - 1.0 / (overshoot * c / d + 1.0)) * d
  }

  FileView {
    id: recentsFile
    path: root.recentsPath
    watchChanges: true
    blockLoading: true
    printErrors: false
    onLoaded: {
      let data = []
      try { data = JSON.parse(text()) } catch (e) { data = [] }
      root.recentAppIds = Array.isArray(data) ? data : []
      root.updateFilter()
    }
  }

  FileView {
    id: launcherConfig
    path: root.launcherConfigPath
    watchChanges: true
    blockLoading: true
    printErrors: false
    onLoaded: {
      let data = {}
      try { data = JSON.parse(text()) } catch (e) { data = {} }
      const hidden = data && Array.isArray(data.hiddenApps) ? data.hiddenApps : []
      const out = []
      for (let i = 0; i < hidden.length; i++) {
        const id = root.normalizeId(hidden[i])
        if (id) out.push(id)
      }
      root.hiddenAppIds = out
      root.refreshApps()
    }
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.refreshApps() }
  }

  Component.onCompleted: root.refreshApps()

  LazyLoader {
    active: root.shown && root.hostScreen !== null

    PanelWindow {
      id: win
      screen: root.hostScreen
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "launcher"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
      }

      Item {
        id: notch
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: root.currentWidth
        height: root.currentHeight

        Shape {
          id: notchShape
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer

          readonly property real w: notchShape.width
          readonly property real h: notchShape.height
          readonly property real b: root.frameThickness
          readonly property real protrusion: Math.max(0, h - b)
          readonly property real effRfL: Math.max(0.5, root.flareRadius)
          readonly property real effRfR: Math.min(root.flareRadius, Math.max(0.5, protrusion * 0.4))
          readonly property real effRc: Math.max(0, Math.min(root.cornerRadius, protrusion - effRfR))
          readonly property real topStart: Math.min(effRfL, w * 0.22)
          readonly property real topEnd: Math.max(topStart + 1, w - effRfR - effRc)
          readonly property real slack: 0.45

          ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.cardColor
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: 0
            startY: notchShape.h + 2.0

            PathLine {
              x: 0
              y: -notchShape.effRfL
            }

            PathCubic {
              x: notchShape.topStart
              y: 0
              control1X: 0
              control1Y: -notchShape.effRfL * notchShape.slack
              control2X: notchShape.topStart * 0.55
              control2Y: 0
            }

            PathLine {
              x: notchShape.topEnd
              y: 0
            }

            PathArc {
              x: notchShape.topEnd + notchShape.effRc
              y: notchShape.effRc
              radiusX: Math.max(1, notchShape.effRc)
              radiusY: Math.max(1, notchShape.effRc)
              direction: PathArc.Clockwise
            }

            PathLine {
              x: notchShape.w - notchShape.effRfR
              y: notchShape.h - notchShape.b - notchShape.effRfR
            }

            PathCubic {
              x: notchShape.w
              y: notchShape.h - notchShape.b
              control1X: notchShape.w - notchShape.effRfR
              control1Y: notchShape.h - notchShape.b - (notchShape.effRfR * notchShape.slack)
              control2X: notchShape.w - (notchShape.effRfR * notchShape.slack)
              control2Y: notchShape.h - notchShape.b
            }

            PathLine {
              x: notchShape.w
              y: notchShape.h + 2.0
            }

            PathLine {
              x: 0
              y: notchShape.h + 2.0
            }
          }
        }

        Item {
          id: expandedView
          anchors.fill: parent
          anchors.topMargin: 12
          anchors.bottomMargin: root.frameThickness + 8
          anchors.leftMargin: root.frameThickness + 14
          anchors.rightMargin: root.flareRadius + 8

          visible: opacity > 0.01
          opacity: root.openProgress
          scale: 0.94 + 0.06 * root.openProgress
          transformOrigin: Item.BottomLeft

          ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: root.searchBarHeight
              radius: root.searchBarHeight / 2
              color: Qt.rgba(0, 0, 0, 0.08)
              border.width: 1
              border.color: searchInput.activeFocus
                ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.38)
                : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.14)

              Behavior on border.color { ColorAnimation { duration: Motion.dur(180) } }

              Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 32
                height: 1
                radius: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 10

                Text {
                  text: "\uf002"
                  font.family: root.iconFont
                  font.pixelSize: 15
                  color: searchInput.activeFocus ? root.textColor : root.mutedColor
                  renderType: Text.NativeRendering
                  Behavior on color { ColorAnimation { duration: Motion.dur(150) } }
                }

                TextInput {
                  id: searchInput
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: root.fontFamily
                  font.pixelSize: 14
                  color: root.textColor
                  selectionColor: root.accentColor
                  selectedTextColor: root.textColor
                  clip: true

                  Component.onCompleted: searchInput.forceActiveFocus()

                  onTextChanged: {
                    root.query = text
                    root.updateFilter()
                  }

                  Keys.onRightPressed: root.selectNext()
                  Keys.onLeftPressed: root.selectPrev()
                  Keys.onDownPressed: root.selectDown()
                  Keys.onUpPressed: root.selectUp()
                  Keys.onReturnPressed: root.activateCurrent()
                  Keys.onEnterPressed: root.activateCurrent()
                  Keys.onEscapePressed: root.hide()

                  Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search applications..."
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    color: root.mutedColor
                    visible: !searchInput.text && !searchInput.activeFocus
                    renderType: Text.NativeRendering
                  }
                }

                Rectangle {
                  id: clearButton
                  Layout.preferredWidth: 24
                  Layout.preferredHeight: 24
                  radius: 12
                  visible: searchInput.text.length > 0
                  color: clearHover.hovered
                    ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.22)
                    : (clearTap.pressed ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.32)
                       : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10))
                  border.width: 1
                  border.color: clearHover.hovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3) : "transparent"
                  scale: clearTap.pressed ? 0.9 : (clearHover.hovered ? 1.08 : 1.0)

                  Behavior on color { ColorAnimation { duration: Motion.dur(120) } }
                  Behavior on scale { NumberAnimation { duration: Motion.dur(140); easing.type: Easing.OutBack } }

                  HoverHandler {
                    id: clearHover
                    cursorShape: Qt.PointingHandCursor
                  }

                  TapHandler {
                    id: clearTap
                    onTapped: {
                      searchInput.text = ""
                      searchInput.forceActiveFocus()
                    }
                  }

                  Text {
                    anchors.centerIn: parent
                    text: "\u00d7"
                    font.pixelSize: 12
                    color: clearHover.hovered ? "#ffffff" : root.textColor
                  }
                }

                Rectangle {
                  id: escButton
                  Layout.preferredHeight: 24
                  Layout.preferredWidth: escRow.implicitWidth + 14
                  radius: 7
                  color: escHover.hovered
                    ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.20)
                    : (escTap.pressed ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.28)
                       : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08))
                  border.width: 1
                  border.color: escHover.hovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3)
                    : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.16)
                  scale: escTap.pressed ? 0.92 : (escHover.hovered ? 1.05 : 1.0)

                  Behavior on color { ColorAnimation { duration: Motion.dur(120) } }
                  Behavior on scale { NumberAnimation { duration: Motion.dur(140); easing.type: Easing.OutBack } }

                  HoverHandler {
                    id: escHover
                    cursorShape: Qt.PointingHandCursor
                  }

                  TapHandler {
                    id: escTap
                    onTapped: root.hide()
                  }

                  Row {
                    id: escRow
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "\u238b"
                      font.pixelSize: 11
                      color: escHover.hovered ? "#ffffff" : root.textColor
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "esc"
                      font.family: root.fontFamily
                      font.pixelSize: 10
                      font.weight: Font.DemiBold
                      color: escHover.hovered ? "#ffffff" : root.textColor
                      renderType: Text.NativeRendering
                    }
                  }
                }
              }
            }

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              FluidSpring {
                id: scrollSpring
                response: 0.14
                dampingFraction: 1.0
                target: 0
                value: 0
                reduceMotion: Motion.reduce

                onValueChanged: resultsGrid.contentY = value
              }

              Timer {
                id: releaseTimer
                interval: 70
                repeat: false
                onTriggered: {
                  const maxY = Math.max(0, resultsGrid.contentHeight - resultsGrid.height)
                  if (scrollSpring.target < 0) scrollSpring.retarget(0, scrollSpring.velocity)
                  else if (scrollSpring.target > maxY) scrollSpring.retarget(maxY, scrollSpring.velocity)
                }
              }

              GridView {
                id: resultsGrid
                anchors.fill: parent
                clip: true
                model: root.filteredApps
                cellWidth: Math.floor(width / Math.max(1, root.gridColumns))
                cellHeight: root.gridCellHeight
                cacheBuffer: root.gridCellHeight * 6
                interactive: false

                readonly property real maxY: Math.max(0, contentHeight - height)
                readonly property real overscrollAmount: contentY < 0
                  ? -contentY : (contentY > maxY ? contentY - maxY : 0)

                scale: 1.0 - Math.min(0.035, overscrollAmount / 600)
                transformOrigin: contentY < 0 ? Item.Top : Item.Bottom

                onModelChanged: {
                  scrollSpring.snapTo(0)
                  resultsGrid.contentY = 0
                }

                onContentYChanged: if (scrollTimer) scrollTimer.restart()

                WheelHandler {
                  acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                  onWheel: function(event) {
                    const maxY = Math.max(0, resultsGrid.contentHeight - resultsGrid.height)
                    if (maxY <= 0) return

                    if (event.pixelDelta.y !== 0) {
                      const rawTarget = scrollSpring.target - event.pixelDelta.y * 1.5
                      let bounded = rawTarget
                      if (rawTarget < 0) bounded = -root.rubberBand(-rawTarget, resultsGrid.height * 0.35)
                      else if (rawTarget > maxY) bounded = maxY + root.rubberBand(rawTarget - maxY, resultsGrid.height * 0.35)
                      scrollSpring.target = bounded
                      scrollSpring.snapTo(bounded)
                      releaseTimer.restart()
                      event.accepted = true
                      return
                    }

                    const delta = event.angleDelta.y
                    if (delta !== 0) {
                      const step = -(delta / 120) * (root.gridCellHeight * 2.2)
                      let current = scrollSpring.target
                      if (current < 0) current = 0
                      else if (current > maxY) current = maxY

                      const next = current + step
                      let clamped = next
                      if (next < 0) clamped = -root.rubberBand(-next, resultsGrid.height * 0.3)
                      else if (next > maxY) clamped = maxY + root.rubberBand(next - maxY, resultsGrid.height * 0.3)

                      const impulse = (step / 0.14) * 1.2
                      const velocity = Math.max(-5000, Math.min(5000, scrollSpring.velocity + impulse))
                      scrollSpring.retarget(clamped, velocity)
                      releaseTimer.restart()
                      event.accepted = true
                    }
                  }
                }

                delegate: Item {
                  id: cell

                  required property var modelData
                  required property int index

                  width: resultsGrid.cellWidth
                  height: resultsGrid.cellHeight

                  readonly property bool isSelected: cell.index === root.selectedIndex
                  readonly property bool isHovered: cellHover.hovered

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: 14
                    color: cell.isSelected
                      ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.14)
                      : (cell.isHovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.07) : "transparent")
                    border.width: 1
                    border.color: cell.isSelected ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.24) : "transparent"

                    Behavior on color { ColorAnimation { duration: Motion.dur(120) } }
                    Behavior on border.color { ColorAnimation { duration: Motion.dur(120) } }
                  }

                  scale: cellTap.pressed ? 0.95 : (cell.isSelected ? 1.02 : (cell.isHovered ? 1.015 : 1.0))
                  Behavior on scale {
                    NumberAnimation {
                      duration: cellTap.pressed ? Motion.dur(80) : Motion.dur(200)
                      easing.type: cellTap.pressed ? Easing.OutQuad : Easing.OutBack
                      easing.overshoot: 1.15
                    }
                  }

                  HoverHandler {
                    id: cellHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) root.selectedIndex = cell.index
                  }

                  TapHandler {
                    id: cellTap
                    onTapped: root.launchItem(cell.modelData)
                  }

                  ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 10
                    spacing: 5

                    Item {
                      Layout.alignment: Qt.AlignHCenter
                      Layout.preferredWidth: 44
                      Layout.preferredHeight: 44

                      Image {
                        id: appIcon
                        anchors.centerIn: parent
                        width: 42
                        height: 42
                        sourceSize.width: 84
                        sourceSize.height: 84
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        mipmap: true
                        smooth: true
                        visible: status === Image.Ready
                        source: root.iconSource(cell.modelData)
                      }

                      Text {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        text: cell.modelData && cell.modelData.name.length > 0
                          ? cell.modelData.name.charAt(0).toUpperCase() : "?"
                        font.family: root.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: root.textColor
                        renderType: Text.NativeRendering
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      textFormat: Text.PlainText
                      text: cell.modelData ? cell.modelData.name : ""
                      font.family: root.fontFamily
                      font.pixelSize: 11
                      font.weight: cell.isSelected ? Font.DemiBold : Font.Normal
                      color: cell.isSelected ? "#ffffff" : root.textColor
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                      maximumLineCount: 1
                      renderType: Text.NativeRendering
                    }
                  }
                }

                Item {
                  anchors.centerIn: parent
                  anchors.horizontalCenterOffset: 0
                  width: Math.max(0, parent.width - 40)
                  height: 100
                  visible: root.filteredApps.length === 0

                  ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                      Layout.alignment: Qt.AlignHCenter
                      text: "No applications found"
                      font.family: root.fontFamily
                      font.pixelSize: 14
                      font.weight: Font.DemiBold
                      color: root.textColor
                      renderType: Text.NativeRendering
                    }

                    Text {
                      Layout.alignment: Qt.AlignHCenter
                      text: "Try searching with a different keyword"
                      font.family: root.fontFamily
                      font.pixelSize: 11
                      color: root.mutedColor
                      renderType: Text.NativeRendering
                    }
                  }
                }
              }

              Rectangle {
                id: scrollIndicator
                anchors.right: parent.right
                anchors.rightMargin: 1
                width: 3.5
                radius: 1.75
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.4)
                visible: resultsGrid.contentHeight > resultsGrid.height

                readonly property real maxY: Math.max(1, resultsGrid.contentHeight - resultsGrid.height)
                readonly property real visibleRatio: Math.min(1.0, resultsGrid.height
                  / Math.max(1, resultsGrid.contentHeight))
                readonly property real baseHeight: Math.max(24, (resultsGrid.height - 12) * visibleRatio)
                readonly property real overscroll: resultsGrid.contentY < 0
                  ? -resultsGrid.contentY
                  : (resultsGrid.contentY > maxY ? resultsGrid.contentY - maxY : 0)

                height: Math.max(12, baseHeight - overscroll * 0.35)
                y: resultsGrid.contentY < 0
                  ? 6
                  : (resultsGrid.contentY > maxY
                      ? (resultsGrid.height - 6 - height)
                      : (6 + Math.max(0, Math.min(1.0, resultsGrid.contentY / maxY))
                          * (resultsGrid.height - 12 - height)))

                opacity: (scrollSpring.animating || (scrollTimer && scrollTimer.running)) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: Motion.dur(220) } }

                Timer {
                  id: scrollTimer
                  interval: 800
                  repeat: false
                }
              }
            }
          }
        }
      }
    }
  }
}
