import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import shell.services
import "../components"
import "."

Item {
  id: root

  required property var frameConfig

  property int borderThickness: frameConfig.borderThickness
  property color notchColor: frameConfig.activeBorderColor
  readonly property var frame: frameConfig
  property string fontFamily: "Adwaita Sans, Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  property bool isOpen: false
  property bool hasOpenApps: false

  property bool isHoverOpen: false
  property bool isPinned: false

  signal openRequested()
  signal closeRequested()

  readonly property bool isOpenEffective: root.isOpen || root.isHoverOpen || root.isPinned

  onIsOpenChanged: {
    if (!root.isOpen) {
      root.isPinned = false
      root.isHoverOpen = false
      if (statusSubpanel) statusSubpanel.close()
    }
  }

  function open() {

    root.isHoverOpen = true
    root.openRequested()
    root.refreshAll()
    root.refreshStatus()
    root.refreshMotionPreference()
  }

  function close() {
    root.isPinned = false
    root.isHoverOpen = false
    root.closeSubpanel()
    root.closeRequested()
  }

  function closeSubpanel() {
    if (statusSubpanel) statusSubpanel.close()
  }

  function toggle() {
    if (root.isOpenEffective) root.close()
    else root.open()
  }

  Timer {
    id: hoverCloseTimer
    interval: 160
    repeat: false
    onTriggered: {
      var subpanelHovered = Boolean(statusSubpanel && statusSubpanel.isHovered)
      if (statusSubpanel && statusSubpanel.isOpen && !statusSubpanel.isPinned
          && !notchHover.hovered && !subpanelHovered) {
        statusSubpanel.isOpen = false
      }
      if (!root.isPinned && !notchHover.hovered && !subpanelHovered) {
        root.close()
      }
    }
  }

  property bool pointerEngaged: true
  property int outsideTicks: 0

  function syncPointerWatchdog() {
    var subpanelHovered = Boolean(statusSubpanel && statusSubpanel.isHovered)
    var inside = notchHover.hovered || subpanelHovered || cornerTriggerHover.hovered
    if (inside) {
      root.pointerEngaged = true
      root.outsideTicks = 0
      return
    }
    if (!root.pointerEngaged || root.isPinned) return
    root.outsideTicks++
    if (root.outsideTicks < 1) return
    root.outsideTicks = 0
    root.pointerEngaged = false
    root.close()
  }

  Timer {
    interval: 120
    repeat: true
    running: root.isOpenEffective && !root.isPinned
    onTriggered: root.syncPointerWatchdog()
  }

  readonly property real collapsedWidth: frameConfig.controlCollapsedWidth
  readonly property real expandedWidth: frameConfig.controlExpandedWidth
  readonly property real collapsedHeight: root.borderThickness
    + Math.max(frameConfig.controlCollapsedHeight, frameConfig.controlRightTabHeight)
  readonly property real expandedHeight: root.borderThickness + frameConfig.controlExpandedHeight

  readonly property real currentFlareRadius: frameConfig.controlFlareRadius
    + (openProgress * (frameConfig.controlExpandedFlareRadius - frameConfig.controlFlareRadius))
  readonly property real currentCornerRadius: frameConfig.controlCornerRadius
    + (openProgress * (frameConfig.controlExpandedCornerRadius - frameConfig.controlCornerRadius))

  readonly property real targetProgress: root.isOpenEffective ? 1.0 : 0.0

  property real openProgress: targetProgress

  Behavior on openProgress {
    NumberAnimation {
      duration: root.reduceMotion
        ? (root.isOpenEffective ? 180 : 140)
        : (root.isOpenEffective ? (root.frameConfig ? root.frameConfig.controlOpenDuration : 380)
                                : (root.frameConfig ? root.frameConfig.controlCloseDuration : 260))
      easing.type: (root.reduceMotion || !root.isOpenEffective) ? Easing.OutCubic : Easing.OutBack
      easing.overshoot: (root.reduceMotion || !root.isOpenEffective)
        ? 1.0
        : (root.frameConfig ? root.frameConfig.controlOpenOvershoot : 1.08)
    }
  }

  readonly property real progressNorm: Math.min(1.0, Math.max(0.0, openProgress))

  readonly property real currentWidth: collapsedWidth
    + (openProgress * (expandedWidth - collapsedWidth))
    + (Math.sin(progressNorm * Math.PI) * (root.frameConfig ? root.frameConfig.controlWidthPulse : 10))

  readonly property real currentHeight: collapsedHeight
    + (openProgress * (expandedHeight - collapsedHeight))
    + (Math.sin(progressNorm * Math.PI) * (root.frameConfig ? root.frameConfig.controlHeightPulse : 6))

  property alias maskItem: notchContainer
  property alias backdropItem: backdropOverlay
  property alias wakeItem: cornerTriggerItem
  property alias statusPanel: statusSubpanel
  readonly property Item subpanelMaskItem: (statusSubpanel && (statusSubpanel.isOpen || statusSubpanel.openProgress > 0.01)) ? statusSubpanel.maskItem : null

  readonly property string iconFont: "JetBrainsMono Nerd Font, Font Awesome 7 Free, sans-serif"

  property string debugTab: ""



  readonly property var wifiData: ({
    enabled: Network.wifiRadio,
    connected: Network.wifiConnectivity === "Connected",
    ssid: Network.activeSsid,
    ip: "",
    signal: Math.round(Network.level * 100),
    networks: (Network.accessPoints || []).map(function(ap) {
      return {
        ssid: String(ap.ssid || ""),
        signal: Number(ap.strength || ap.signal || 0),
        active: String(ap.ssid || "") === Network.activeSsid,
        security: String(ap.security || "")
      }
    })
  })

  readonly property var btData: {
    var list = Bluetooth.devices ? Bluetooth.devices.values : []
    var devs = []
    var connected = 0
    for (var i = 0; i < list.length; i++) {
      var d = list[i]
      if (!d) continue
      if (d.connected) connected++
      devs.push({
        name: String(d.name || d.address || "Device"),
        mac: String(d.address || ""),
        connected: d.connected === true,
        icon: String(d.icon || "")
      })
    }
    return {
      enabled: BluetoothPower.enabled,
      connectedCount: connected,
      devices: devs
    }
  }

  readonly property var dnsData: ({
    current: (Network.dnsServers || []).join(", "),
    preset: String(Network.dnsProvider || "dhcp")
  })

  readonly property var batteryData: ({
    present: Battery.present,
    capacity: Battery.pct,
    charging: Battery.charging,
    timeRemaining: Battery.hasTime ? Battery.timeStr : ""
  })

  readonly property real volumeFraction: (Audio.sink && Audio.sink.audio) ? Audio.sink.audio.volume : 0
  readonly property real brightnessFraction: Devices.backlightAvailable
    ? Math.max(0.02, Devices.backlightPct / 100) : 0.5
  readonly property string activePowerProfile: PowerProfiles.profile || "balanced"
  property bool isDraggingSlider: false

  readonly property bool nightLightActive: Toggles.nightOn
  readonly property bool focusActive: Toggles.dnd
  readonly property bool recordingActive: Recorder.active
  property bool isRescanningWifi: false
  property int lastBtScan: 0
  property bool reduceMotion: frameConfig.reduceMotion

  function refreshStatus() {}
  function refreshAll() {}
  function refreshNightLight() {}
  function refreshFocus() {}
  function refreshRecord() {}
  function refreshMotionPreference() {}

  function toggleWifi() { Toggles.toggleWifi() }
  function toggleBluetooth() { Toggles.toggleBt() }
  function toggleNightLight() { Toggles.toggleNight() }
  function toggleFocus() { Toggles.toggleDnd() }
  function toggleRecord() { Recorder.active ? Recorder.stop() : Recorder.start() }

  function setDns(preset) {
    var servers = []
    if (preset === "cloudflare") servers = ["1.1.1.1", "1.0.0.1"]
    else if (preset === "google") servers = ["8.8.8.8", "8.8.4.4"]
    else if (preset === "adguard") servers = ["94.140.14.14", "94.140.15.15"]
    Network.setDnsProvider(preset === "dhcp" ? "" : preset, servers)
  }

  function rescanWifi() {
    root.isRescanningWifi = true
    Network.refresh()
    rescanTimer.restart()
  }

  Timer {
    id: rescanTimer
    interval: 3000
    onTriggered: root.isRescanningWifi = false
  }

  function connectWifi(ssid) {
    if (ssid) Network.connectWifi(ssid, "")
  }

  function connectBluetooth(mac) {
    var list = Bluetooth.devices ? Bluetooth.devices.values : []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && String(list[i].address) === mac) {
        list[i].connect()
        return
      }
    }
  }

  function disconnectBluetooth(mac) {
    var list = Bluetooth.devices ? Bluetooth.devices.values : []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && String(list[i].address) === mac) {
        list[i].disconnect()
        return
      }
    }
  }

  function scanBluetooth() {
    if (Bluetooth.defaultAdapter)
      Bluetooth.defaultAdapter.discovering = true
  }

  function showStatusTab(tab) {
    if (!statusSubpanel) return
    statusSubpanel.openTab(tab)
    if (tab === "wifi") Network.refresh()
    if (tab === "bluetooth" && root.btData.enabled
        && (Date.now() - root.lastBtScan) > 15000) {
      root.lastBtScan = Date.now()
      root.scanBluetooth()
    }
  }

  function togglePinStatusTab(tab) {
    if (!statusSubpanel) return
    if (statusSubpanel.isPinned && statusSubpanel.activeTab === tab) {
      statusSubpanel.close()
    } else {
      statusSubpanel.openTab(tab)
      statusSubpanel.isPinned = true
    }
  }

  function syncStatusTabFromPointer() {
    if (!cardProbe || !cardProbe.hovered) return
    var sp = cardProbe.point.scenePosition
    var wp = btnWifi.mapFromItem(null, sp.x, sp.y)
    var bp = btnBluetooth.mapFromItem(null, sp.x, sp.y)
    var dp = btnDns.mapFromItem(null, sp.x, sp.y)

    if (wp.x >= 0 && wp.x <= btnWifi.width && wp.y >= 0 && wp.y <= btnWifi.height) {
      showStatusTab("wifi")
      return
    }
    if (bp.x >= 0 && bp.x <= btnBluetooth.width && bp.y >= 0 && bp.y <= btnBluetooth.height) {
      showStatusTab("bluetooth")
      return
    }
    if (dp.x >= 0 && dp.x <= btnDns.width && dp.y >= 0 && dp.y <= btnDns.height) {
      showStatusTab("dns")
      return
    }

    var cp = statusColumn.mapFromItem(null, sp.x, sp.y)
    var inHotZone = cp.x >= -48 && cp.x <= (statusColumn.width + 12)
      && cp.y >= -12 && cp.y <= (statusColumn.height + 12)
    if (!inHotZone) closeStatusTab()
  }

  function closeStatusTab() {
    if (!statusSubpanel || statusSubpanel.isPinned) return
    if (statusSubpanel.isOpen) statusSubpanel.isOpen = false
  }

  function debugStatus(tab) {
    root.isPinned = false
    root.showStatusTab(tab)
  }

  function setVolume(pct) {
    if (Audio.sink && Audio.sink.audio)
      Audio.sink.audio.volume = Math.max(0, Math.min(1, pct))
  }

  function setBrightness(pct) {
    Devices.setBacklight(Math.max(5, Math.round(pct * 100)))
  }

  function setPowerProfile(profile) {
    if (profile) PowerProfiles.setProfile(profile)
  }

  Component.onCompleted: {
    if (Devices.backlightAvailable) Devices.readBacklight()
  }

  onIsOpenEffectiveChanged: {
    if (root.isOpenEffective) {
      if (Devices.backlightAvailable) Devices.readBacklight()
      Network.refresh()
    } else {
      root.closeSubpanel()
    }
  }

  function getVolumeIcon(fraction) {
    if (fraction <= 0.01) return ""
    if (fraction < 0.35) return ""
    if (fraction < 0.70) return ""
    return ""
  }

  function getWifiIcon() {
    if (!root.wifiData || !root.wifiData.enabled) return "󰤮"
    if (!root.wifiData.connected) return "󰤯"
    var sig = root.wifiData.signal || 50
    if (sig > 75) return "󰤨"
    if (sig > 50) return "󰤥"
    if (sig > 25) return "󰤢"
    return "󰤟"
  }

  function getBluetoothIcon() {
    if (!root.btData || !root.btData.enabled) return "󰂲"
    if (root.btData.connectedCount > 0) return "󰂱"
    return "󰂯"
  }

  function getBatteryIcon() {
    if (!root.batteryData || !root.batteryData.present) return "󰂑"
    var cap = root.batteryData.capacity || 0
    if (root.batteryData.charging) return cap >= 95 ? "󰂅" : "󰂄"
    if (cap >= 90) return "󰁹"
    if (cap >= 70) return "󰂀"
    if (cap >= 50) return "󰁿"
    if (cap >= 30) return "󰁾"
    if (cap >= 15) return "󰁻"
    return "󰁺"
  }

  Item {
    id: backdropOverlay
    anchors.fill: root.isOpenEffective ? parent : undefined
    width: root.isOpenEffective ? parent.width : 0
    height: root.isOpenEffective ? parent.height : 0
    visible: root.isOpenEffective && root.openProgress > 0.01

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }
  }

  Item {
    id: notchContainer
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.rightMargin: 0

    readonly property bool shouldRetract: root.hasOpenApps && !root.isOpenEffective && !(statusSubpanel && (statusSubpanel.isOpen || statusSubpanel.isHovered || statusSubpanel.isPinned))
    readonly property real targetRetractOffset: shouldRetract ? -(root.collapsedHeight - root.borderThickness) : 0.0
    property real currentRetractOffset: targetRetractOffset

    Behavior on currentRetractOffset {
      NumberAnimation {
        duration: notchContainer.shouldRetract ? 280 : 380
        easing.type: notchContainer.shouldRetract ? Easing.OutCubic : Easing.OutBack
        easing.overshoot: 1.08
      }
    }

    anchors.bottomMargin: currentRetractOffset

    width: root.currentWidth
    height: root.currentHeight

    Item {
      id: cornerTriggerItem
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      anchors.bottomMargin: -notchContainer.currentRetractOffset
      width: Math.max(64, root.collapsedWidth)
      height: root.borderThickness + 14

      HoverHandler {
        id: cornerTriggerHover
        cursorShape: (!root.isOpenEffective) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onHoveredChanged: {
          if (hovered) {
            root.open()
          } else {
            var subpanelHovered = Boolean(statusSubpanel && statusSubpanel.isHovered)
            if (!notchHover.hovered && !subpanelHovered && !root.isPinned) {
              root.close()
            }
          }
        }
      }
    }

    property color activeColor: root.notchColor

    HoverHandler {
      id: notchHover
      cursorShape: root.isOpenEffective ? Qt.ArrowCursor : Qt.PointingHandCursor
      onHoveredChanged: {
        if (hovered) {
          hoverCloseTimer.stop()
          root.isHoverOpen = true
          root.refreshAll()
          root.refreshStatus()
        } else {

          var subpanelHovered = Boolean(statusSubpanel && statusSubpanel.isHovered)
          if ((statusSubpanel && statusSubpanel.isOpen) || subpanelHovered) {
            hoverCloseTimer.restart()
          } else {
            hoverCloseTimer.stop()
            if (!root.isPinned) {
              root.close()
            }
          }
        }
      }
    }

    property bool isGussetPressed: restingTapHandler.pressed

    FluidSpring {
      id: gussetPressSpring
      target: (!root.isOpenEffective && notchContainer.isGussetPressed) ? 0.96 : 1.0
      response: notchContainer.isGussetPressed ? 0.18 : 0.30
      dampingFraction: notchContainer.isGussetPressed ? 1.0 : 0.78
      epsilon: 0.0004
      reduceMotion: root.reduceMotion
      value: 1.0
    }

    scale: gussetPressSpring.value
    transformOrigin: Item.BottomRight

    Shape {
      id: gussetShape
      anchors.fill: parent
      visible: root.openProgress < 0.05
      preferredRendererType: Shape.CurveRenderer

      readonly property real w: gussetShape.width
      readonly property real h: gussetShape.height
      readonly property real b: root.borderThickness
      readonly property real stripTop: h - b - frameConfig.controlCollapsedHeight
      readonly property real tabW: Math.max(2, Math.min(frameConfig.controlRightTabWidth, w * 0.25))
      readonly property real tabTop: Math.max(0, h - b - frameConfig.controlRightTabHeight)
      readonly property real rTab: Math.max(0, Math.min(frameConfig.controlTabCapRadius,
                                                        tabW * 0.5,
                                                        (stripTop - tabTop) * 0.45))
      readonly property real fillet: Math.max(0, Math.min(frameConfig.controlInnerRadius,
                                                          stripTop - tabTop))
      readonly property real rCorner: Math.max(0, Math.min(frameConfig.controlCornerRadius,
                                                           (h - stripTop) * 0.55))
      readonly property real stripEnd: Math.max(rCorner, w - tabW - fillet)

      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: notchContainer.activeColor
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        startX: gussetShape.w + 2.0
        startY: gussetShape.h + 2.0

        PathLine {
          x: gussetShape.w - gussetShape.stripEnd
          y: gussetShape.h + 2.0
        }

        PathLine {
          x: gussetShape.w - gussetShape.stripEnd
          y: gussetShape.stripTop + gussetShape.rCorner
        }

        PathArc {
          x: gussetShape.w - gussetShape.stripEnd + gussetShape.rCorner
          y: gussetShape.stripTop
          radiusX: gussetShape.rCorner
          radiusY: gussetShape.rCorner
          direction: PathArc.Clockwise
        }

        PathLine {
          x: gussetShape.w - gussetShape.tabW - gussetShape.fillet
          y: gussetShape.stripTop
        }

        PathCubic {
          x: gussetShape.w - gussetShape.tabW
          y: gussetShape.stripTop - gussetShape.fillet
          control1X: gussetShape.w - gussetShape.tabW - (gussetShape.fillet * 0.5)
          control1Y: gussetShape.stripTop
          control2X: gussetShape.w - gussetShape.tabW
          control2Y: gussetShape.stripTop - (gussetShape.fillet * 0.5)
        }

        PathLine {
          x: gussetShape.w - gussetShape.tabW
          y: gussetShape.tabTop + gussetShape.rTab
        }

        PathCubic {
          x: gussetShape.w
          y: gussetShape.tabTop + gussetShape.rTab
          control1X: gussetShape.w - gussetShape.tabW
          control1Y: gussetShape.tabTop
          control2X: gussetShape.w
          control2Y: gussetShape.tabTop
        }

        PathLine {
          x: gussetShape.w + 2.0
          y: gussetShape.tabTop + gussetShape.rTab
        }

        PathLine {
          x: gussetShape.w + 2.0
          y: gussetShape.h + 2.0
        }
      }
    }

    Shape {
      id: notchShape
      anchors.fill: parent
      visible: root.openProgress >= 0.05
      preferredRendererType: Shape.CurveRenderer

      readonly property real w: notchShape.width
      readonly property real h: notchShape.height
      readonly property real rf: root.currentFlareRadius
      readonly property real rc: root.currentCornerRadius
      readonly property real b: root.borderThickness

      readonly property real effRfTop: Math.min(rf, Math.max(2, (w - b) * 0.15))
      readonly property real effRfBot: Math.min(rf, Math.max(2, (w - b) * 0.15))
      readonly property real effRc: Math.min(rc, Math.max(4, Math.min(w * 0.15, h * 0.15)))

      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: notchContainer.activeColor
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        startX: notchShape.w + 2.0
        startY: notchShape.h + 2.0

        PathLine {
          x: notchShape.w + 2.0
          y: -notchShape.effRfTop
        }

        PathLine {
          x: notchShape.w
          y: -notchShape.effRfTop
        }

        PathCubic {
          x: notchShape.w - notchShape.effRfTop
          y: 0
          control1X: notchShape.w
          control1Y: -notchShape.effRfTop * 0.5
          control2X: notchShape.w - (notchShape.effRfTop * 0.5)
          control2Y: 0
        }

        PathLine {
          x: notchShape.effRfBot + notchShape.effRc
          y: 0
        }

        PathArc {
          x: notchShape.effRfBot
          y: notchShape.effRc
          radiusX: notchShape.effRc
          radiusY: notchShape.effRc
          direction: PathArc.Counterclockwise
        }

        PathLine {
          x: notchShape.effRfBot
          y: Math.max(notchShape.effRc, notchShape.h - notchShape.b - notchShape.effRfBot)
        }

        PathCubic {
          x: 0
          y: notchShape.h - notchShape.b
          control1X: notchShape.effRfBot
          control1Y: notchShape.h - notchShape.b - (notchShape.effRfBot * 0.5)
          control2X: notchShape.effRfBot * 0.5
          control2Y: notchShape.h - notchShape.b
        }

        PathLine {
          x: -2.0
          y: notchShape.h - notchShape.b
        }

        PathLine {
          x: -2.0
          y: notchShape.h + 2.0
        }

        PathLine {
          x: notchShape.w + 2.0
          y: notchShape.h + 2.0
        }
      }
    }

    Item {
      id: restingArea
      anchors.fill: parent
      visible: root.openProgress < 0.9
      opacity: Math.max(0.0, 1.0 - root.openProgress * 3.0)

      HoverHandler {
        cursorShape: Qt.PointingHandCursor
      }

      TapHandler {
        id: restingTapHandler
        onTapped: {
          if (root.isOpenEffective) root.close()
          else root.open()
        }
      }
    }

    Item {
      id: expandedView
      anchors.fill: parent

      visible: opacity > 0.01 && root.openProgress > 0.20
      opacity: Math.max(0.0, Math.min(1.0, (root.openProgress - 0.20) * 1.25))
      scale: 0.92 + (0.08 * root.openProgress)
      transformOrigin: Item.BottomRight

      HoverHandler {
        id: cardProbe
        onHoveredChanged: root.syncStatusTabFromPointer()
        onPointChanged: root.syncStatusTabFromPointer()
      }

      Column {
        id: controlsColumn
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter

        anchors.horizontalCenterOffset: frameConfig.controlExpandedFlareRadius / 2
        spacing: 14

        Row {
          id: topControlsRow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 10

          Column {
            id: statusColumn
            spacing: 10

            Rectangle {
              id: btnWifi
              width: frameConfig.controlButtonSize
              height: frameConfig.controlButtonSize
              radius: width / 2

              readonly property bool isActive: Boolean(root.wifiData && root.wifiData.enabled)
              readonly property bool isPressed: wifiArea.pressed

              FluidSpring {
                id: wifiPressSpring
                target: btnWifi.isPressed ? 0.90 : (wifiArea.containsMouse ? 1.08 : 1.0)
                response: btnWifi.isPressed ? 0.18 : 0.30
                dampingFraction: btnWifi.isPressed ? 1.0 : 0.78
                epsilon: 0.0004
                reduceMotion: root.reduceMotion
                value: 1.0
              }

              color: isActive
                ? frameConfig.powerButtonActiveBg
                : (wifiArea.containsMouse ? Qt.rgba(frameConfig.activeTextColor.r, frameConfig.activeTextColor.g, frameConfig.activeTextColor.b, 0.20) : frameConfig.powerButtonInactiveBg)
              scale: wifiPressSpring.value

              Behavior on color { ColorAnimation { duration: 180 } }

              Text {
                anchors.centerIn: parent
                text: root.getWifiIcon()
                font.family: root.iconFont
                font.pixelSize: 22
                color: btnWifi.isActive
                  ? frameConfig.powerButtonActiveIcon
                  : frameConfig.powerButtonInactiveIcon
                renderType: Text.NativeRendering
              }

              MouseArea {
                id: wifiArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) root.showStatusTab("wifi")
                onClicked: root.toggleWifi()
              }
            }

            Rectangle {
              id: btnBluetooth
              width: frameConfig.controlButtonSize
              height: frameConfig.controlButtonSize
              radius: width / 2

              readonly property bool isActive: Boolean(root.btData && root.btData.enabled)
              readonly property bool isPressed: btArea.pressed

              FluidSpring {
                id: btPressSpring
                target: btnBluetooth.isPressed ? 0.90 : (btArea.containsMouse ? 1.08 : 1.0)
                response: btnBluetooth.isPressed ? 0.18 : 0.30
                dampingFraction: btnBluetooth.isPressed ? 1.0 : 0.78
                epsilon: 0.0004
                reduceMotion: root.reduceMotion
                value: 1.0
              }

              color: isActive
                ? frameConfig.powerButtonActiveBg
                : (btArea.containsMouse ? Qt.rgba(frameConfig.activeTextColor.r, frameConfig.activeTextColor.g, frameConfig.activeTextColor.b, 0.20) : frameConfig.powerButtonInactiveBg)
              scale: btPressSpring.value

              Behavior on color { ColorAnimation { duration: 180 } }

              Text {
                anchors.centerIn: parent
                text: root.getBluetoothIcon()
                font.family: root.iconFont
                font.pixelSize: 22
                color: btnBluetooth.isActive
                  ? frameConfig.powerButtonActiveIcon
                  : frameConfig.powerButtonInactiveIcon
                renderType: Text.NativeRendering
              }

              MouseArea {
                id: btArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) root.showStatusTab("bluetooth")
                onClicked: root.toggleBluetooth()
              }
            }
          }

          Column {
            id: quickColumn
            spacing: 10

            Rectangle {
              id: btnNightLight
              width: frameConfig.controlButtonSize
              height: frameConfig.controlButtonSize
              radius: width / 2

              readonly property bool isActive: root.nightLightActive
              readonly property bool isPressed: nlArea.pressed

              FluidSpring {
                id: nlPressSpring
                target: btnNightLight.isPressed ? 0.90 : (nlArea.containsMouse ? 1.08 : 1.0)
                response: btnNightLight.isPressed ? 0.18 : 0.30
                dampingFraction: btnNightLight.isPressed ? 1.0 : 0.78
                epsilon: 0.0004
                reduceMotion: root.reduceMotion
                value: 1.0
              }

              color: isActive
                ? frameConfig.powerButtonActiveBg
                : (nlArea.containsMouse ? Qt.rgba(frameConfig.activeTextColor.r, frameConfig.activeTextColor.g, frameConfig.activeTextColor.b, 0.20) : frameConfig.powerButtonInactiveBg)
              scale: nlPressSpring.value

              Behavior on color { ColorAnimation { duration: 180 } }

              Text {
                anchors.centerIn: parent
                text: "󰔎"
                font.family: root.iconFont
                font.pixelSize: 20
                color: btnNightLight.isActive
                  ? frameConfig.powerButtonActiveIcon
                  : frameConfig.powerButtonInactiveIcon
                renderType: Text.NativeRendering
              }

              MouseArea {
                id: nlArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleNightLight()
              }
            }

            Rectangle {
              id: btnFocus
              width: frameConfig.controlButtonSize
              height: frameConfig.controlButtonSize
              radius: width / 2

              readonly property bool isActive: root.focusActive
              readonly property bool isPressed: focusArea.pressed

              FluidSpring {
                id: focusPressSpring
                target: btnFocus.isPressed ? 0.90 : (focusArea.containsMouse ? 1.08 : 1.0)
                response: btnFocus.isPressed ? 0.18 : 0.30
                dampingFraction: btnFocus.isPressed ? 1.0 : 0.78
                epsilon: 0.0004
                reduceMotion: root.reduceMotion
                value: 1.0
              }

              color: isActive
                ? frameConfig.powerButtonActiveBg
                : (focusArea.containsMouse ? Qt.rgba(frameConfig.activeTextColor.r, frameConfig.activeTextColor.g, frameConfig.activeTextColor.b, 0.20) : frameConfig.powerButtonInactiveBg)
              scale: focusPressSpring.value

              Behavior on color { ColorAnimation { duration: 180 } }

              Text {
                anchors.centerIn: parent
                text: btnFocus.isActive ? "󰂛" : "󰂚"
                font.family: root.iconFont
                font.pixelSize: 20
                color: btnFocus.isActive
                  ? frameConfig.powerButtonActiveIcon
                  : frameConfig.powerButtonInactiveIcon
                renderType: Text.NativeRendering
              }

              MouseArea {
                id: focusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleFocus()
              }
            }
          }

          Column {
            id: sliderColumn
            spacing: 10

            Item {
              id: brightItem
              width: frameConfig.controlSliderWidth
              height: frameConfig.controlSliderHeight

              FluidSpring {
                id: brightPressSpring
                target: brightArea.pressed ? 0.98 : 1.0
                response: brightArea.pressed ? 0.18 : 0.30
                dampingFraction: brightArea.pressed ? 1.0 : 0.78
                epsilon: 0.0004
                reduceMotion: root.reduceMotion
                value: 1.0
              }

              scale: brightPressSpring.value

              FluidSpring {
                id: brightFillSpring
                target: root.brightnessFraction
                tracking: brightArea.pressed
                response: 0.36
                dampingFraction: 0.80
                epsilon: 0.0004
                reduceMotion: root.reduceMotion
                value: root.brightnessFraction
              }

              Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: frameConfig.sliderTrackColor
              }

              Item {
                id: brightFillContainer
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, parent.width * brightFillSpring.value)
                clip: true
                visible: brightFillSpring.value > 0.002 && width > 0.5

                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: brightItem.width
                  radius: height / 2
                  color: frameConfig.activeSliderFillColor
                }
              }

              Text {
                z: 5
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "󰃠"
                font.family: root.iconFont
                font.pixelSize: 20
                color: (brightFillContainer.visible && brightFillContainer.width >= 36)
                  ? frameConfig.activeSliderIconColorFilled
                  : frameConfig.sliderIconColorUnfilled
                renderType: Text.NativeRendering
              }

              MouseArea {
                id: brightArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function applyPosition(mouse) {
                  var rawFrac = mouse.x / width
                  var frac = (rawFrac <= 0.02) ? 0.0 : Math.max(0.0, Math.min(1.0, rawFrac))
                  root.setBrightness(frac)
                }

                onPressed: function(mouse) {
                  root.isDraggingSlider = true
                  applyPosition(mouse)
                }
                onPositionChanged: function(mouse) {
                  if (pressed) applyPosition(mouse)
                }
                onReleased: root.isDraggingSlider = false
              }
            }

            Item {
              id: volItem
              width: frameConfig.controlSliderWidth
              height: frameConfig.controlSliderHeight

              FluidSpring {
                id: volPressSpring
                target: volArea.pressed ? 0.98 : 1.0
                response: volArea.pressed ? 0.18 : 0.30
                dampingFraction: volArea.pressed ? 1.0 : 0.78
                epsilon: 0.0004
                reduceMotion: root.reduceMotion
                value: 1.0
              }

              scale: volPressSpring.value

              FluidSpring {
                id: volFillSpring
                target: root.volumeFraction
                tracking: volArea.pressed
                response: 0.36
                dampingFraction: 0.80
                epsilon: 0.0004
                reduceMotion: root.reduceMotion
                value: root.volumeFraction
              }

              Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: frameConfig.sliderTrackColor
              }

              Item {
                id: volFillContainer
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, parent.width * volFillSpring.value)
                clip: true
                visible: volFillSpring.value > 0.002 && width > 0.5

                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: volItem.width
                  radius: height / 2
                  color: frameConfig.activeSliderFillColor
                }
              }

              Text {
                z: 5
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.getVolumeIcon(root.volumeFraction)
                font.family: root.iconFont
                font.pixelSize: 20
                color: (volFillContainer.visible && volFillContainer.width >= 36)
                  ? frameConfig.activeSliderIconColorFilled
                  : frameConfig.sliderIconColorUnfilled
                renderType: Text.NativeRendering
              }

              MouseArea {
                id: volArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function applyPosition(mouse) {
                  var rawFrac = mouse.x / width
                  var frac = (rawFrac <= 0.02) ? 0.0 : Math.max(0.0, Math.min(1.0, rawFrac))
                  root.setVolume(frac)
                }

                onPressed: function(mouse) {
                  root.isDraggingSlider = true
                  applyPosition(mouse)
                }
                onPositionChanged: function(mouse) {
                  if (pressed) applyPosition(mouse)
                }
                onReleased: root.isDraggingSlider = false
              }
            }
          }
        }

        Row {
          id: rowActionAndPower
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Math.floor((272 - (frameConfig.controlButtonSize * 5)) / 4)

          Rectangle {
            id: btnDns
            width: frameConfig.controlButtonSize
            height: frameConfig.controlButtonSize
            radius: width / 2

            readonly property bool isActive: Boolean(root.dnsData.preset) && root.dnsData.preset !== "dhcp"
            readonly property bool isPressed: dnsArea.pressed

            FluidSpring {
              id: dnsPressSpring
              target: btnDns.isPressed ? 0.90 : (dnsArea.containsMouse ? 1.08 : 1.0)
              response: btnDns.isPressed ? 0.18 : 0.30
              dampingFraction: btnDns.isPressed ? 1.0 : 0.78
              epsilon: 0.0004
              reduceMotion: root.reduceMotion
              value: 1.0
            }

            color: isActive
              ? frameConfig.powerButtonActiveBg
              : (dnsArea.containsMouse ? Qt.rgba(frameConfig.activeTextColor.r, frameConfig.activeTextColor.g, frameConfig.activeTextColor.b, 0.20) : frameConfig.powerButtonInactiveBg)
            scale: dnsPressSpring.value

            Behavior on color { ColorAnimation { duration: 180 } }

            Text {
              anchors.centerIn: parent
              text: "󰖟"
              font.family: root.iconFont
              font.pixelSize: 22
              color: btnDns.isActive
                ? frameConfig.powerButtonActiveIcon
                : frameConfig.powerButtonInactiveIcon
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: dnsArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: if (containsMouse) root.showStatusTab("dns")
            }
          }

          Rectangle {
            id: btnRecord
            width: frameConfig.controlButtonSize
            height: frameConfig.controlButtonSize
            radius: width / 2

            readonly property bool isActive: root.recordingActive
            readonly property bool isPressed: recordArea.pressed

            FluidSpring {
              id: recordPressSpring
              target: btnRecord.isPressed ? 0.90 : (recordArea.containsMouse ? 1.08 : 1.0)
              response: btnRecord.isPressed ? 0.18 : 0.30
              dampingFraction: btnRecord.isPressed ? 1.0 : 0.78
              epsilon: 0.0004
              reduceMotion: root.reduceMotion
              value: 1.0
            }

            color: isActive
              ? Qt.rgba(1.0, 0.25, 0.25, 0.85)
              : (recordArea.containsMouse ? Qt.rgba(frameConfig.activeTextColor.r, frameConfig.activeTextColor.g, frameConfig.activeTextColor.b, 0.20) : frameConfig.powerButtonInactiveBg)
            scale: recordPressSpring.value

            Behavior on color { ColorAnimation { duration: 180 } }

            Text {
              anchors.centerIn: parent
              text: "󰻂"
              font.family: root.iconFont
              font.pixelSize: 20
              color: btnRecord.isActive
                ? "#ffffff"
                : frameConfig.powerButtonInactiveIcon
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: recordArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleRecord()
            }
          }

          Rectangle {
            id: btnLowPower
            width: frameConfig.controlPowerButtonSize
            height: frameConfig.controlPowerButtonSize
            radius: width / 2

            readonly property bool isActive: root.activePowerProfile === "power-saver"

            FluidSpring {
              id: lpPressSpring
              target: lpArea.pressed ? 0.90 : (lpArea.containsMouse ? 1.08 : 1.0)
              response: lpArea.pressed ? 0.18 : 0.30
              dampingFraction: lpArea.pressed ? 1.0 : 0.78
              epsilon: 0.0004
              reduceMotion: root.reduceMotion
              value: 1.0
            }

            color: isActive
              ? frameConfig.powerButtonActiveBg
              : (lpArea.containsMouse ? Qt.rgba(frameConfig.activeTextColor.r, frameConfig.activeTextColor.g, frameConfig.activeTextColor.b, 0.20) : frameConfig.powerButtonInactiveBg)
            scale: lpPressSpring.value

            Behavior on color { ColorAnimation { duration: 180 } }

            Text {
              anchors.centerIn: parent
              text: "󰌪"
              font.family: root.iconFont
              font.pixelSize: 22
              color: btnLowPower.isActive
                ? frameConfig.powerButtonActiveIcon
                : frameConfig.powerButtonInactiveIcon
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: lpArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setPowerProfile("power-saver")
            }
          }

          Rectangle {
            id: btnBalanced
            width: frameConfig.controlPowerButtonSize
            height: frameConfig.controlPowerButtonSize
            radius: width / 2

            readonly property bool isActive: root.activePowerProfile === "balanced"

            FluidSpring {
              id: balPressSpring
              target: balArea.pressed ? 0.90 : (balArea.containsMouse ? 1.08 : 1.0)
              response: balArea.pressed ? 0.18 : 0.30
              dampingFraction: balArea.pressed ? 1.0 : 0.78
              epsilon: 0.0004
              reduceMotion: root.reduceMotion
              value: 1.0
            }

            color: isActive
              ? frameConfig.powerButtonActiveBg
              : (balArea.containsMouse ? Qt.rgba(frameConfig.activeTextColor.r, frameConfig.activeTextColor.g, frameConfig.activeTextColor.b, 0.20) : frameConfig.powerButtonInactiveBg)
            scale: balPressSpring.value

            Behavior on color { ColorAnimation { duration: 180 } }

            Text {
              anchors.centerIn: parent
              text: "󰊚"
              font.family: root.iconFont
              font.pixelSize: 22
              color: btnBalanced.isActive
                ? frameConfig.powerButtonActiveIcon
                : frameConfig.powerButtonInactiveIcon
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: balArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setPowerProfile("balanced")
            }
          }

          Rectangle {
            id: btnPerformance
            width: frameConfig.controlPowerButtonSize
            height: frameConfig.controlPowerButtonSize
            radius: width / 2

            readonly property bool isActive: root.activePowerProfile === "performance"

            FluidSpring {
              id: perfPressSpring
              target: perfArea.pressed ? 0.90 : (perfArea.containsMouse ? 1.08 : 1.0)
              response: perfArea.pressed ? 0.18 : 0.30
              dampingFraction: perfArea.pressed ? 1.0 : 0.78
              epsilon: 0.0004
              reduceMotion: root.reduceMotion
              value: 1.0
            }

            color: isActive
              ? frameConfig.powerButtonActiveBg
              : (perfArea.containsMouse ? Qt.rgba(frameConfig.activeTextColor.r, frameConfig.activeTextColor.g, frameConfig.activeTextColor.b, 0.20) : frameConfig.powerButtonInactiveBg)
            scale: perfPressSpring.value

            Behavior on color { ColorAnimation { duration: 180 } }

            Text {
              anchors.centerIn: parent
              text: "󰓅"
              font.family: root.iconFont
              font.pixelSize: 22
              color: btnPerformance.isActive
                ? frameConfig.powerButtonActiveIcon
                : frameConfig.powerButtonInactiveIcon
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: perfArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setPowerProfile("performance")
            }
          }
        }

        Rectangle {
          id: batteryCapsule
          anchors.horizontalCenter: parent.horizontalCenter
          width: frameConfig.controlBatteryRowWidth
          height: frameConfig.controlBatteryHeight
          radius: height / 2
          visible: root.batteryData.present
          color: frameConfig.sliderTrackColor

          Row {
            anchors.centerIn: parent
            spacing: 8

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.getBatteryIcon()
              font.family: root.iconFont
              font.pixelSize: 18
              color: root.batteryData.present && root.batteryData.charging
                ? frameConfig.powerButtonActiveIcon
                : frameConfig.powerButtonInactiveIcon
              renderType: Text.NativeRendering
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.batteryData.present
              text: root.batteryData.capacity + "%"
              font.family: "Adwaita Sans, Inter, sans-serif"
              font.pixelSize: 13
              font.weight: Font.DemiBold
              color: frameConfig.powerButtonInactiveIcon
              renderType: Text.NativeRendering
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.batteryData.present && (root.batteryData.charging || Boolean(root.batteryData.timeRemaining))
              text: "•"
              font.family: "Adwaita Sans, Inter, sans-serif"
              font.pixelSize: 13
              color: Qt.rgba(frameConfig.activeTextColor.r, frameConfig.activeTextColor.g, frameConfig.activeTextColor.b, 0.40)
              renderType: Text.NativeRendering
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.batteryData.present && (root.batteryData.charging || Boolean(root.batteryData.timeRemaining))
              text: root.batteryData.charging ? "Charging" : (root.batteryData.timeRemaining || "")
              font.family: "Adwaita Sans, Inter, sans-serif"
              font.pixelSize: 12
              color: Qt.rgba(frameConfig.activeTextColor.r, frameConfig.activeTextColor.g, frameConfig.activeTextColor.b, 0.60)
              renderType: Text.NativeRendering
            }
          }
        }
      }
    }
  }

  ControlCenterSubpanel {
    id: statusSubpanel
    frameConfig: root.frameConfig
    notchColor: root.notchColor
    borderThickness: root.borderThickness
    fontFamily: root.fontFamily
    anchors.right: notchContainer.left

    anchors.rightMargin: -frameConfig.controlExpandedFlareRadius
    anchors.top: notchContainer.top
    anchors.topMargin: root.borderThickness + 10

    wifiData: root.wifiData
    btData: root.btData
    isRescanningWifi: root.isRescanningWifi
    dnsData: root.dnsData
    reduceMotion: root.reduceMotion

    onSetDnsRequested: function(preset) { root.setDns(preset) }
    onToggleWifiRequested: root.toggleWifi()
    onRescanWifiRequested: root.rescanWifi()
    onConnectWifiRequested: function(ssid) { root.connectWifi(ssid) }
    onToggleBluetoothRequested: root.toggleBluetooth()
    onConnectBluetoothRequested: function(mac) { root.connectBluetooth(mac) }
    onDisconnectBluetoothRequested: function(mac) { root.disconnectBluetooth(mac) }
  }

  Connections {
    target: statusSubpanel
    function onIsHoveredChanged() {
      if (!statusSubpanel.isHovered) hoverCloseTimer.restart()
    }
  }
}
