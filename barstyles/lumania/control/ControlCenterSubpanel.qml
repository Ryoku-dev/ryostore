import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import "../components"

Item {
  id: root

  required property var frameConfig

  property int borderThickness: frameConfig.borderThickness
  property color notchColor: frameConfig.activeBorderColor
  property color activeTextColor: "#ffffff"
  property string fontFamily: "Adwaita Sans, Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  readonly property string iconFont: "JetBrainsMono Nerd Font, Font Awesome 7 Free, sans-serif"

  property string activeTab: "wifi"

  property bool isOpen: false
  property bool isPinned: false

  readonly property bool isHovered: cardHover.hovered

  property var wifiData: ({
    enabled: true,
    connected: false,
    ssid: "",
    ip: "",
    signal: 0,
    networks: []
  })
  property var btData: ({
    enabled: false,
    connectedCount: 0,
    devices: []
  })
  property bool isRescanningWifi: false
  property var dnsData: ({
    current: "",
    preset: "dhcp"
  })

  readonly property var dnsPresets: [
    { id: "cloudflare", label: "Cloudflare", desc: "1.1.1.1" },
    { id: "google", label: "Google", desc: "8.8.8.8" },
    { id: "adguard", label: "AdGuard", desc: "Ad blocking" },
    { id: "dhcp", label: "DHCP Default", desc: "Router" }
  ]

  property bool reduceMotion: false

  signal toggleWifiRequested()
  signal rescanWifiRequested()
  signal connectWifiRequested(string ssid)
  signal toggleBluetoothRequested()
  signal connectBluetoothRequested(string mac)
  signal disconnectBluetoothRequested(string mac)
  signal setDnsRequested(string preset)

  function openTab(tab) {
    if (root.activeTab !== tab) root.activeTab = tab
    root.isOpen = true
  }

  function close() {
    root.isPinned = false
    root.isOpen = false
  }

  readonly property real targetProgress: isOpen ? 1.0 : 0.0
  property real openProgress: targetProgress

  Behavior on openProgress {
    NumberAnimation {
      duration: root.reduceMotion
        ? (root.isOpen ? 180 : 140)
        : (root.isOpen ? 280 : 200)
      easing.type: (root.reduceMotion || !root.isOpen) ? Easing.OutCubic : Easing.OutBack
      easing.overshoot: (root.reduceMotion || !root.isOpen) ? 1.0 : 1.06
    }
  }

  property alias maskItem: subpanelCard

  implicitWidth: frameConfig.controlSubpanelWidth

  property var cachedWifiNetworks: []
  property var cachedBtDevices: []

  onWifiDataChanged: {
    if (wifiData && wifiData.networks && wifiData.networks.length > 0) {
      cachedWifiNetworks = wifiData.networks
    }
  }

  onBtDataChanged: {
    if (btData && btData.devices && btData.devices.length > 0) {
      cachedBtDevices = btData.devices
    }
  }

  readonly property int rowPitch: 30
  readonly property real verticalPadding: (frameConfig.controlSubpanelFlareRadius * 2) + 16
  readonly property var wifiNetworks: {
    var nets = (root.wifiData.networks && root.wifiData.networks.length > 0)
      ? root.wifiData.networks
      : root.cachedWifiNetworks
    var filtered = []
    for (var i = 0; i < nets.length; i++) {
      var n = nets[i]
      if (n.ssid && n.ssid.length > 0 && n.ssid !== "--") filtered.push(n)
    }

    filtered.sort(function (a, b) { return (b.active ? 1 : 0) - (a.active ? 1 : 0) })
    return filtered
  }
  readonly property var btDevices: {
    return (root.btData.devices && root.btData.devices.length > 0)
      ? root.btData.devices
      : root.cachedBtDevices
  }
  readonly property int activeRowCount: root.activeTab === "wifi"
    ? root.wifiNetworks.length
    : (root.activeTab === "dns" ? root.dnsPresets.length : root.btDevices.length)

  FluidSpring {
    id: heightSpring
    target: Math.min(frameConfig.controlSubpanelHeight,
                     root.verticalPadding + (Math.max(1, root.activeRowCount) * root.rowPitch))
    response: 0.32
    dampingFraction: 1.0
    epsilon: 0.5
    reduceMotion: root.reduceMotion
  }

  implicitHeight: heightSpring.value

  opacity: Math.max(0.0, Math.min(1.0, openProgress * 1.15))
  scale: 0.94 + (0.06 * openProgress)
  transformOrigin: Item.Right
  visible: openProgress > 0.01

  Item {
    id: subpanelCard
    anchors.fill: parent

    HoverHandler {
      id: cardHover
    }

    Shape {
      id: cardShape
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      readonly property real w: subpanelCard.width
      readonly property real h: subpanelCard.height

      readonly property real rf: Math.max(2, Math.min(root.frameConfig.controlSubpanelFlareRadius,
                                                     h * 0.30, w * 0.5))
      readonly property real rc: Math.max(2, Math.min(root.frameConfig.controlSubpanelCornerRadius,
                                                     (h - 2 * Math.min(root.frameConfig.controlSubpanelFlareRadius, h * 0.30)) / 2,
                                                     w - Math.min(root.frameConfig.controlSubpanelFlareRadius, h * 0.30)))
      readonly property real flareR: rf
      readonly property real rCorner: rc

      readonly property real tension: 0.62

      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.notchColor
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        startX: cardShape.w
        startY: 0

        PathCubic {
          x: cardShape.w - cardShape.rf
          y: cardShape.rf
          control1X: cardShape.w
          control1Y: cardShape.rf * cardShape.tension
          control2X: cardShape.w - cardShape.rf + (cardShape.rf * cardShape.tension)
          control2Y: cardShape.rf
        }

        PathLine {
          x: cardShape.rc
          y: cardShape.rf
        }

        PathCubic {
          x: 0
          y: cardShape.rf + cardShape.rc
          control1X: cardShape.rc - (cardShape.rc * cardShape.tension)
          control1Y: cardShape.rf
          control2X: 0
          control2Y: cardShape.rf + (cardShape.rc * (1 - cardShape.tension))
        }

        PathLine {
          x: 0
          y: cardShape.h - cardShape.rf - cardShape.rc
        }

        PathCubic {
          x: cardShape.rc
          y: cardShape.h - cardShape.rf
          control1X: 0
          control1Y: cardShape.h - cardShape.rf - (cardShape.rc * (1 - cardShape.tension))
          control2X: cardShape.rc - (cardShape.rc * cardShape.tension)
          control2Y: cardShape.h - cardShape.rf
        }

        PathLine {
          x: cardShape.w - cardShape.rf
          y: cardShape.h - cardShape.rf
        }

        PathCubic {
          x: cardShape.w
          y: cardShape.h
          control1X: cardShape.w - cardShape.rf + (cardShape.rf * cardShape.tension)
          control1Y: cardShape.h - cardShape.rf
          control2X: cardShape.w
          control2Y: cardShape.h - (cardShape.rf * cardShape.tension)
        }

        PathLine {
          x: cardShape.w
          y: 0
        }
      }
    }

    ColumnLayout {
      id: wifiView
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: cardShape.flareR + 14
      anchors.topMargin: cardShape.flareR + 8
      anchors.bottomMargin: cardShape.flareR + 8
      spacing: 8
      visible: root.activeTab === "wifi"

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        ListView {
          id: wifiList
          anchors.fill: parent
          spacing: 2
          boundsBehavior: Flickable.StopAtBounds
          visible: root.wifiData.enabled

          model: root.wifiNetworks

          delegate: Rectangle {
            id: netItem
            width: wifiList.width
            height: 28
            radius: 6

            readonly property bool isPressed: netTap.pressed

            color: netItem.isPressed
              ? Qt.rgba(255, 255, 255, 0.24)
              : (netItemHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent")

            Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

            HoverHandler { id: netItemHover }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 6

              Text {
                text: {
                  var sig = modelData.signal || 50
                  if (sig > 75) return "󰤨"
                  if (sig > 50) return "󰤥"
                  if (sig > 25) return "󰤢"
                  return "󰤟"
                }
                font.family: root.iconFont
                font.pixelSize: 13
                color: modelData.active ? "#ffffff" : Qt.rgba(255, 255, 255, 0.70)
              }

              Text {
                textFormat: Text.PlainText
                text: modelData.ssid
                font.family: root.fontFamily
                font.pixelSize: 11
                font.weight: modelData.active ? Font.DemiBold : Font.Normal
                color: "#ffffff"
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                visible: Boolean(modelData.active)
                text: "Active"
                font.family: root.fontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
                color: "#ffffff"
              }

              Text {
                visible: !modelData.active && modelData.security && modelData.security.length > 0
                text: "󰌾"
                font.family: root.iconFont
                font.pixelSize: 10
                color: Qt.rgba(255, 255, 255, 0.60)
              }
            }

            TapHandler {
              id: netTap
              onTapped: {
                if (!modelData.active) {
                  root.connectWifiRequested(modelData.ssid)
                }
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          visible: !root.wifiData.enabled || wifiList.count === 0
          text: !root.wifiData.enabled
            ? "Wi-Fi off"
            : (root.isRescanningWifi ? "Scanning for networks..."
                : (root.wifiData.connected ? "No other networks" : "No networks found"))
          font.family: root.fontFamily
          font.pixelSize: 11
          color: Qt.rgba(255, 255, 255, 0.60)
        }
      }
    }

    ColumnLayout {
      id: btView
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: cardShape.flareR + 14
      anchors.topMargin: cardShape.flareR + 8
      anchors.bottomMargin: cardShape.flareR + 8
      spacing: 8
      visible: root.activeTab === "bluetooth"

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        ListView {
          id: btList
          anchors.fill: parent
          spacing: 2
          boundsBehavior: Flickable.StopAtBounds
          visible: root.btData.enabled
          model: root.btDevices

          delegate: Rectangle {
            id: btItem
            width: btList.width
            height: 28
            radius: 6

            readonly property bool isPressed: btTap.pressed

            color: btItem.isPressed
              ? Qt.rgba(255, 255, 255, 0.24)
              : (btItemHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent")

            Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

            HoverHandler { id: btItemHover }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 6

              Text {
                text: {
                  if (modelData.icon === "gamepad") return "󰊴"
                  if (modelData.icon === "audio-card" || modelData.icon === "headset") return "󰋋"
                  return "󰂯"
                }
                font.family: root.iconFont
                font.pixelSize: 13
                color: modelData.connected ? "#ffffff" : Qt.rgba(255, 255, 255, 0.70)
              }

              Text {
                textFormat: Text.PlainText
                text: modelData.name
                font.family: root.fontFamily
                font.pixelSize: 11
                font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                color: "#ffffff"
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: modelData.connected ? "Disconnect" : "Connect"
                font.family: root.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: modelData.connected ? "#ffffff" : Qt.rgba(255, 255, 255, 0.80)
              }
            }

            TapHandler {
              id: btTap
              onTapped: {
                if (modelData.connected) root.disconnectBluetoothRequested(modelData.mac)
                else root.connectBluetoothRequested(modelData.mac)
              }
            }
          }

        }

        Text {
          anchors.centerIn: parent
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          visible: !root.btData.enabled || btList.count === 0
          text: root.btData.enabled ? "No devices found" : "Bluetooth off"
          font.family: root.fontFamily
          font.pixelSize: 11
          color: Qt.rgba(255, 255, 255, 0.60)
        }
      }
    }

    ColumnLayout {
      id: dnsView
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: cardShape.flareR + 14
      anchors.topMargin: cardShape.flareR + 8
      anchors.bottomMargin: cardShape.flareR + 8
      spacing: 8
      visible: root.activeTab === "dns"

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        ListView {
          id: dnsList
          anchors.fill: parent
          spacing: 2
          boundsBehavior: Flickable.StopAtBounds
          model: root.dnsPresets

          delegate: Rectangle {
            id: dnsItem
            width: dnsList.width
            height: 28
            radius: 6

            readonly property bool isSelected: root.dnsData.preset === modelData.id

            color: dnsItem.isSelected
              ? Qt.rgba(255, 255, 255, 0.24)
              : (dnsItemHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent")

            Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

            HoverHandler { id: dnsItemHover }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 6

              Rectangle {
                width: 8
                height: 8
                radius: 4
                color: dnsItem.isSelected ? "#ffffff" : Qt.rgba(255, 255, 255, 0.30)
              }

              Text {
                text: modelData.label
                font.family: root.fontFamily
                font.pixelSize: 11
                font.weight: dnsItem.isSelected ? Font.DemiBold : Font.Normal
                color: "#ffffff"
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: modelData.desc
                font.family: root.fontFamily
                font.pixelSize: 9
                color: Qt.rgba(255, 255, 255, 0.65)
              }
            }

            TapHandler {
              id: dnsTap
              onTapped: root.setDnsRequested(modelData.id)
            }
          }
        }
      }
    }
  }
}
