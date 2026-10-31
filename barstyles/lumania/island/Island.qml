import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import shell.services
import "../services" as S
import "../components"
import "."

Item {
  id: root

  required property var frameConfig
  property int borderThickness: frameConfig.borderThickness
  property color islandColor: frameConfig.activeBorderColor
  property color islandTextColor: frameConfig.activeTextColor
  property color islandMutedColor: frameConfig.mutedColor
  property string fontFamily: "Adwaita Sans, Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  property string iconFont: "JetBrainsMono Nerd Font, Font Awesome 7 Free, sans-serif"
  property bool hasOpenApps: false
  property bool showNotifications: true

  S.NotificationModel { id: notifModel }

  readonly property var notificationManager: notifModel

  readonly property var availablePages: root.hasActualMedia ? ["media"] : []
  property int activePageIndex: 0
  readonly property string currentPageType: {
    var p = availablePages
    if (activePageIndex >= 0 && activePageIndex < p.length) return p[activePageIndex]
    return p[0] || ""
  }

  onInCallChanged: {
    if (root.inCall) root.activePageIndex = 0
  }

  onHasActualMediaChanged: {
    if (root.hasActualMedia && !root.inCall) {
      root.activePageIndex = 0
    }
  }

  readonly property bool hasNotification: root.showNotifications
    && Boolean(notificationManager && notificationManager.hasNotification)
  property real notificationProgress: hasNotification ? 1.0 : 0.0

  readonly property bool inCall: false
  readonly property bool callShowing: false

  Behavior on notificationProgress {
    NumberAnimation {
      duration: root.hasNotification ? 380 : 260
      easing.type: root.hasNotification ? Easing.OutBack : Easing.OutCubic
      easing.overshoot: root.hasNotification ? 1.12 : 1.0
    }
  }

  function resolveIcon(iconPath) {
    var s = String(iconPath || "").trim()
    if (!s || s.length === 0) return ""
    if (s.indexOf("file://") === 0 || s.indexOf("image://") === 0) return s
    if (s.charAt(0) === "/") return "file://" + s
    var themed = Quickshell.iconPath(s, true)
    return themed ? String(themed) : ""
  }

  function isFilePath(path) {
    var s = String(path || "").trim()
    return s.indexOf("/") === 0 || s.indexOf("file://") === 0 || s.indexOf("image://") === 0
  }

  readonly property int bodyWidth: frameConfig.islandBodyWidth
  readonly property int topCurveRadius: frameConfig.islandTopCurveRadius
  readonly property int islandWidth: bodyWidth + (topCurveRadius * 2)
  readonly property int islandHeight: borderThickness + 32
  readonly property int bottomCornerRadius: frameConfig.islandBottomCornerRadius

  readonly property Item islandMaskItem: islandContainer

  property string currentTimeString: ""
  property string currentDateString: ""
  property bool use24Hour: true

  function updateClock() {
    var now = new Date()
    currentTimeString = Qt.formatDateTime(now, use24Hour ? "HH:mm" : "h:mm AP")
    currentDateString = Qt.formatDateTime(now, "ddd, MMM d")
  }

  Component.onCompleted: updateClock()

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.updateClock()
  }

  function resolveMediaArt(p) {
    if (!p) return ""
    return String(p.trackArtUrl || "").trim()
  }

  function isCallOrComm(p) { return false }

  readonly property var activePlayer: Media.present ? Media.player : null

  readonly property bool hasActualMedia: Boolean(
    root.activePlayer && (
      root.activePlayer.trackTitle ||
      root.activePlayer.trackArtist ||
      root.activePlayer.canGoNext ||
      root.activePlayer.canGoPrevious
    )
  )

  readonly property bool isSkippable: Boolean(
    root.activePlayer && (
      root.activePlayer.canGoNext ||
      root.activePlayer.canGoPrevious
    )
  )

  Item {
    id: edgeTriggerItem
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.islandWidth
    height: root.borderThickness + 14

    HoverHandler {
      id: edgeTriggerHover
    }
  }

  Item {
    id: islandContainer
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter

    readonly property bool isPointerOver: islandHover.hovered || edgeTriggerHover.hovered

    onIsPointerOverChanged: {
      if (root.notificationManager) {
        root.notificationManager.isHovered = isPointerOver
      }
    }

    readonly property bool isHovered: isPointerOver && root.notificationProgress < 0.01
    readonly property real targetHoverProgress: isHovered ? 1.0 : 0.0
    property real hoverProgress: targetHoverProgress

    readonly property bool shouldRetract: root.hasOpenApps
      && !isPointerOver
      && !root.hasNotification
      && !root.inCall
      && !dynamicView.mprisPlaying
      && root.notificationProgress < 0.01
      && islandContainer.hoverProgress < 0.05
    readonly property real targetRetractY: shouldRetract ? -(root.islandHeight - root.borderThickness) : 0.0

    FluidSpring {
      id: retractSpring
      target: islandContainer.targetRetractY
      response: islandContainer.shouldRetract ? 0.28 : 0.36
      dampingFraction: islandContainer.shouldRetract ? 1.0 : 0.8
      epsilon: 0.05
    }

    readonly property real currentRetractY: retractSpring.value

    anchors.topMargin: currentRetractY

    Behavior on hoverProgress {
      NumberAnimation {
        duration: islandContainer.isHovered ? 400 : 280
        easing.type: islandContainer.isHovered ? Easing.OutBack : Easing.OutCubic
        easing.overshoot: islandContainer.isHovered ? 1.08 : 1.0
      }
    }

    readonly property bool isMediaActive: Boolean(root.hasActualMedia && dynamicView.showVisualizer)
    readonly property real targetProgress: isMediaActive ? 1.0 : 0.0
    property real transitionProgress: targetProgress

    Behavior on transitionProgress {
      NumberAnimation {
        duration: islandContainer.isMediaActive ? 380 : 240
        easing.type: islandContainer.isMediaActive ? Easing.OutBack : Easing.OutCubic
        easing.overshoot: islandContainer.isMediaActive ? 1.15 : 1.0
      }
    }

    readonly property real activeExpansionProgress: Math.max(hoverProgress, root.notificationProgress)

    readonly property real currentTopRadius: root.topCurveRadius
      + (activeExpansionProgress * (root.frameConfig.islandExpandedTopCurveRadius - root.topCurveRadius))
    readonly property real currentBottomRadius: root.bottomCornerRadius
      + (activeExpansionProgress * (root.frameConfig.islandExpandedBottomCornerRadius - root.bottomCornerRadius))

    readonly property real activeHoverHeightDelta: root.frameConfig.islandHoverHeightDeltaMedia + (root.availablePages.length > 1 ? 6 : 0)

    readonly property real notifContentTextWidth: Math.max(
      (typeof notifSummaryText !== "undefined" && notifSummaryText) ? notifSummaryText.implicitWidth : 0,
      (typeof notifBodyText !== "undefined" && notifBodyText && notifBodyText.text.length > 0) ? notifBodyText.implicitWidth : 0
    )
    readonly property real notifDynamicTargetWidth: Math.max(
      root.islandWidth,
      Math.min(480, Math.ceil(notifContentTextWidth) + 104)
    )
    readonly property real notifWidthDelta: Math.max(0, notifDynamicTargetWidth - root.islandWidth)
    property real animatedNotifWidthDelta: notifWidthDelta

    Behavior on animatedNotifWidthDelta {
      NumberAnimation {
        duration: 320
        easing.type: Easing.OutBack
        easing.overshoot: 1.08
      }
    }

    readonly property real notifHeightDelta: 18

    readonly property real baseWidth: root.callShowing ? 206 : root.islandWidth
    readonly property real normalWidth: baseWidth
      + (hoverProgress * root.frameConfig.islandHoverWidthDelta)
      + (root.notificationProgress * animatedNotifWidthDelta)
      + (Math.sin(Math.min(1.0, Math.max(0.0, transitionProgress)) * Math.PI) * 8.0)
      + (Math.sin(Math.min(1.0, Math.max(0.0, hoverProgress)) * Math.PI) * 6.0)
      + (Math.sin(Math.min(1.0, Math.max(0.0, root.notificationProgress)) * Math.PI) * 10.0)

    width: normalWidth

    height: root.islandHeight
      + (hoverProgress * activeHoverHeightDelta)
      + (root.notificationProgress * notifHeightDelta)

    property bool isPressed: tapHandler.pressed
    scale: isPressed ? 0.96 : 1.0
    transformOrigin: Item.Top

    Behavior on scale {
      NumberAnimation {
        duration: islandContainer.isPressed ? 140 : 320
        easing.type: islandContainer.isPressed ? Easing.OutQuad : Easing.OutBack
        easing.overshoot: 1.2
      }
    }

    HoverHandler {
      id: islandHover
      cursorShape: Qt.PointingHandCursor
    }

    WheelHandler {
      id: islandWheel
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      enabled: islandContainer.isHovered && root.availablePages.length > 1
      onWheel: function(event) {
        if (event.angleDelta.y < 0) {
          root.activePageIndex = Math.min(root.availablePages.length - 1, root.activePageIndex + 1)
        } else if (event.angleDelta.y > 0) {
          root.activePageIndex = Math.max(0, root.activePageIndex - 1)
        }
      }
    }

    TapHandler {
      id: tapHandler
      enabled: !islandContainer.isHovered && !root.hasActualMedia && !root.inCall && root.notificationProgress < 0.01
      onTapped: {
        root.use24Hour = !root.use24Hour
        root.updateClock()
      }
    }

    Shape {
      id: islandShape
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      readonly property real w: islandContainer.width
      readonly property real h: islandContainer.height
      readonly property real rTop: islandContainer.currentTopRadius
      readonly property real rBot: islandContainer.currentBottomRadius
      readonly property real b: root.borderThickness

      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.islandColor
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        startX: 0
        startY: -2.0

        PathLine {
          x: islandShape.w
          y: -2.0
        }

        PathLine {
          x: islandShape.w
          y: islandShape.b
        }

        PathCubic {
          x: islandShape.w - islandShape.rTop
          y: islandShape.b + islandShape.rTop
          control1X: islandShape.w - (islandShape.rTop * 0.5)
          control1Y: islandShape.b
          control2X: islandShape.w - islandShape.rTop
          control2Y: islandShape.b + (islandShape.rTop * 0.5)
        }

        PathLine {
          x: islandShape.w - islandShape.rTop
          y: islandShape.h - islandShape.rBot
        }

        PathArc {
          x: islandShape.w - islandShape.rTop - islandShape.rBot
          y: islandShape.h
          radiusX: islandShape.rBot
          radiusY: islandShape.rBot
          direction: PathArc.Clockwise
        }

        PathLine {
          x: islandShape.rTop + islandShape.rBot
          y: islandShape.h
        }

        PathArc {
          x: islandShape.rTop
          y: islandShape.h - islandShape.rBot
          radiusX: islandShape.rBot
          radiusY: islandShape.rBot
          direction: PathArc.Clockwise
        }

        PathLine {
          x: islandShape.rTop
          y: islandShape.b + islandShape.rTop
        }

        PathCubic {
          x: 0
          y: islandShape.b
          control1X: islandShape.rTop
          control1Y: islandShape.b + (islandShape.rTop * 0.5)
          control2X: islandShape.rTop * 0.5
          control2Y: islandShape.b
        }

        PathLine {
          x: 0
          y: -2.0
        }
      }
    }

    Row {
      id: clockContentRow
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -5.0 * islandContainer.transitionProgress
      spacing: 8

      opacity: (!root.inCall && !islandContainer.isHovered && islandContainer.hoverProgress < 0.02 && root.notificationProgress < 0.01)
        ? Math.max(0.0, 1.0 - islandContainer.transitionProgress * 2.2)
        : 0.0
      scale: Math.max(0.82, 1.0 - islandContainer.transitionProgress * 0.16)
      visible: opacity > 0.01 && !root.inCall && !islandContainer.isHovered && islandContainer.hoverProgress < 0.02 && root.notificationProgress < 0.01
      transformOrigin: Item.Center

      Behavior on opacity {
        NumberAnimation { duration: 140 }
      }

      Text {
        id: dateLabel
        anchors.verticalCenter: parent.verticalCenter
        text: root.currentDateString
        color: root.islandMutedColor
        font.family: root.fontFamily
        font.pixelSize: 12
        font.weight: Font.Medium
        renderType: Text.NativeRendering
        verticalAlignment: Text.AlignVCenter
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 3
        radius: 1.5
        color: Qt.rgba(root.islandTextColor.r, root.islandTextColor.g, root.islandTextColor.b, 0.35)
      }

      Text {
        id: timeLabel
        anchors.verticalCenter: parent.verticalCenter
        text: root.currentTimeString
        color: root.islandTextColor
        font.family: root.fontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
        verticalAlignment: Text.AlignVCenter
      }
    }

    DynamicWorkspaceView {
      id: dynamicView
      anchors.fill: parent
      artUrl: (root.hasActualMedia && root.activePlayer) ? root.resolveMediaArt(root.activePlayer) : ""
      mprisPlaying: Media.playing
      textColor: root.islandTextColor
      accentColor: root.frameConfig.accentColor

      opacity: (!root.inCall && !islandContainer.isHovered && islandContainer.hoverProgress < 0.02 && root.notificationProgress < 0.01)
        ? Math.min(1.0, Math.max(0.0, (islandContainer.transitionProgress - 0.25) * 1.33))
        : 0.0
      scale: 0.82 + (0.18 * islandContainer.transitionProgress)
      y: 4.0 * (1.0 - islandContainer.transitionProgress)
      visible: opacity > 0.01 && !root.inCall && !islandContainer.isHovered && islandContainer.hoverProgress < 0.02 && root.notificationProgress < 0.01
      transformOrigin: Item.Center

      Behavior on opacity {
        NumberAnimation { duration: 140 }
      }
    }

    Row {
      id: mediaControlsRow
      anchors.centerIn: parent
      anchors.verticalCenterOffset: root.availablePages.length > 1 ? (root.borderThickness * 0.5 - 2) : (root.borderThickness * 0.5)
      spacing: 18

      readonly property bool mediaPageActive: root.currentPageType === "media"
      opacity: (islandContainer.hoverProgress > 0.15 && root.hasActualMedia && root.notificationProgress < 0.01 && mediaPageActive)
        ? Math.min(1.0, (islandContainer.hoverProgress - 0.15) * 1.35)
        : 0.0
      scale: 0.88 + (0.12 * islandContainer.hoverProgress)
      visible: opacity > 0.01 && root.hasActualMedia && root.notificationProgress < 0.01
      transformOrigin: Item.Center

      Rectangle {
        id: btnPrev
        visible: root.isSkippable
        width: 38
        height: 38
        radius: 19
        anchors.verticalCenter: parent.verticalCenter

        readonly property bool isPressed: prevArea.pressed
        scale: isPressed ? 0.90 : (prevArea.containsMouse ? 1.08 : 1.0)
        color: prevArea.containsMouse ? Qt.rgba(root.islandTextColor.r, root.islandTextColor.g, root.islandTextColor.b, 0.20) : root.frameConfig.powerButtonInactiveBg

        Behavior on scale {
          NumberAnimation {
            duration: btnPrev.isPressed ? 120 : 240
            easing.type: btnPrev.isPressed ? Easing.OutQuad : Easing.OutBack
            easing.overshoot: 1.15
          }
        }
        Behavior on color {
          ColorAnimation { duration: 180 }
        }

        Text {
          anchors.centerIn: parent
          text: "󰒮"
          font.family: root.iconFont
          font.pixelSize: 18
          color: root.frameConfig.powerButtonInactiveIcon
          renderType: Text.NativeRendering
        }

        MouseArea {
          id: prevArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var p = root.activePlayer
            if (!p) return
            if (p.canGoPrevious || p.canControl) p.previous()
          }
        }
      }

      Rectangle {
        id: btnPlayPause
        width: 44
        height: 44
        radius: 22
        anchors.verticalCenter: parent.verticalCenter

        readonly property bool isPlaying: Boolean(root.activePlayer && root.activePlayer.isPlaying)
        readonly property bool isPressed: playPauseArea.pressed
        scale: isPressed ? 0.90 : (playPauseArea.containsMouse ? 1.08 : 1.0)

        color: isPlaying
          ? root.frameConfig.powerButtonActiveBg
          : (playPauseArea.containsMouse ? Qt.rgba(root.islandTextColor.r, root.islandTextColor.g, root.islandTextColor.b, 0.20) : root.frameConfig.powerButtonInactiveBg)

        Behavior on scale {
          NumberAnimation {
            duration: btnPlayPause.isPressed ? 120 : 240
            easing.type: btnPlayPause.isPressed ? Easing.OutQuad : Easing.OutBack
            easing.overshoot: 1.15
          }
        }
        Behavior on color {
          ColorAnimation { duration: 180 }
        }

        Text {
          anchors.centerIn: parent
          text: btnPlayPause.isPlaying ? "󰏤" : "󰐊"
          font.family: root.iconFont
          font.pixelSize: 22
          color: btnPlayPause.isPlaying ? root.frameConfig.powerButtonActiveIcon : root.frameConfig.powerButtonInactiveIcon
          renderType: Text.NativeRendering
        }

        MouseArea {
          id: playPauseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var p = root.activePlayer
            if (!p) return

            if (p.isPlaying) {
              if (p.canPause) p.pause()
              else if (p.canTogglePlaying) p.togglePlaying()
            } else {
              if (p.canPlay) p.play()
              else if (p.canTogglePlaying) p.togglePlaying()
            }
          }
        }
      }

      Rectangle {
        id: btnNext
        visible: root.isSkippable
        width: 38
        height: 38
        radius: 19
        anchors.verticalCenter: parent.verticalCenter

        readonly property bool isPressed: nextArea.pressed
        scale: isPressed ? 0.90 : (nextArea.containsMouse ? 1.08 : 1.0)
        color: nextArea.containsMouse ? Qt.rgba(root.islandTextColor.r, root.islandTextColor.g, root.islandTextColor.b, 0.20) : root.frameConfig.powerButtonInactiveBg

        Behavior on scale {
          NumberAnimation {
            duration: btnNext.isPressed ? 120 : 240
            easing.type: btnNext.isPressed ? Easing.OutQuad : Easing.OutBack
            easing.overshoot: 1.15
          }
        }
        Behavior on color {
          ColorAnimation { duration: 180 }
        }

        Text {
          anchors.centerIn: parent
          text: "󰒭"
          font.family: root.iconFont
          font.pixelSize: 18
          color: root.frameConfig.powerButtonInactiveIcon
          renderType: Text.NativeRendering
        }

        MouseArea {
          id: nextArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var p = root.activePlayer
            if (!p) return
            if (p.canGoNext || p.canControl) p.next()
          }
        }
      }
    }

    Row {
      id: multiActivityPagination
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 4
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 4
      visible: islandContainer.hoverProgress > 0.3 && root.availablePages.length > 1 && root.notificationProgress < 0.01
      opacity: islandContainer.hoverProgress

      Repeater {
        model: root.availablePages.length
        delegate: Rectangle {
          required property int index
          width: root.activePageIndex === index ? 10 : 3
          height: 3
          radius: 1.5
          color: root.activePageIndex === index ? root.islandTextColor : Qt.rgba(root.islandTextColor.r, root.islandTextColor.g, root.islandTextColor.b, 0.35)
          Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 160 } }

          MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activePageIndex = index
          }
        }
      }
    }

    Item {
      id: notificationContent
      anchors.fill: parent
      anchors.topMargin: root.borderThickness
      anchors.leftMargin: islandShape.rTop + 12
      anchors.rightMargin: islandShape.rTop + 14

      opacity: root.notificationProgress
      scale: 0.92 + (0.08 * root.notificationProgress)
      visible: opacity > 0.005
      transformOrigin: Item.Center

      RowLayout {
        anchors.fill: parent
        spacing: 11

        Item {
          id: notifIconContainer
          Layout.preferredWidth: 30
          Layout.preferredHeight: 30
          Layout.alignment: Qt.AlignVCenter

          Item {
            id: circleMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {
              anchors.fill: parent
              radius: width * 0.5
              color: "#000000"
            }
          }

          Rectangle {
            anchors.fill: parent
            radius: width * 0.5
            color: Qt.rgba(root.islandTextColor.r, root.islandTextColor.g, root.islandTextColor.b, 0.14)
          }

          Item {
            id: notifImageWrapper
            anchors.fill: parent
            visible: (notifImg.status === Image.Ready && notifImg.source.toString().length > 0)
              || (notifAppIcon.status === Image.Ready && notifAppIcon.source.toString().length > 0)
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
              maskEnabled: true
              maskSource: circleMask
              maskThresholdMin: 0.5
              maskSpreadAtMin: 0.5
            }

            Image {
              id: notifImg
              anchors.fill: parent
              visible: status === Image.Ready && source.toString().length > 0
              source: {
                if (!root.notificationManager) return ""
                var img = root.notificationManager.currentImage
                if (img && img.length > 0) return root.resolveIcon(img)
                var icon = root.notificationManager.currentAppIcon
                if (icon && root.isFilePath(icon)) return root.resolveIcon(icon)
                return ""
              }
              fillMode: Image.PreserveAspectCrop
              mipmap: true
              smooth: true
            }

            Image {
              id: notifAppIcon
              anchors.centerIn: parent
              width: 20
              height: 20
              visible: !notifImg.visible && status === Image.Ready && source.toString().length > 0
              source: {
                if (!root.notificationManager) return ""
                var icon = root.notificationManager.currentAppIcon
                if (icon && !root.isFilePath(icon)) return root.resolveIcon(icon)
                return ""
              }
              fillMode: Image.PreserveAspectFit
              mipmap: true
              smooth: true
            }
          }

          Text {
            anchors.centerIn: parent
            visible: !notifImageWrapper.visible
            text: (root.notificationManager && root.notificationManager.currentGlyph.length > 0)
              ? root.notificationManager.currentGlyph
              : ((root.notificationManager && root.notificationManager.currentUrgency === 2) ? "󰀦" : "󰂚")
            font.family: root.iconFont
            font.pixelSize: 15
            color: root.islandTextColor
            renderType: Text.NativeRendering
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 1

          Text {
            textFormat: Text.PlainText
            id: notifSummaryText
            Layout.fillWidth: true
            text: (root.notificationManager && root.notificationManager.currentSummary.length > 0)
              ? root.notificationManager.currentSummary
              : (root.notificationManager ? root.notificationManager.currentAppName : "Notification")
            font.family: root.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: root.islandTextColor
            elide: Text.ElideRight
            renderType: Text.NativeRendering
            maximumLineCount: 1
          }

          Text {
            textFormat: Text.PlainText
            id: notifBodyText
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.notificationManager ? root.notificationManager.currentBody : ""
            font.family: root.fontFamily
            font.pixelSize: 11
            font.weight: Font.Normal
            color: Qt.rgba(root.islandTextColor.r, root.islandTextColor.g, root.islandTextColor.b, 0.72)
            elide: Text.ElideRight
            renderType: Text.NativeRendering
            maximumLineCount: 1
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) {
            if (root.notificationManager) root.notificationManager.dismissCurrent()
          } else {
            if (root.notificationManager) root.notificationManager.invokeAction()
          }
        }
      }
    }


  }
}
