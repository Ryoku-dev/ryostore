import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../services" as S
import "../components"

Item {
  id: root

  S.WallpaperModel { id: wall }

  required property var frameConfig
  property int borderThickness: frameConfig.borderThickness
  property color notchColor: frameConfig.activeBorderColor
  property color textColor: frameConfig.activeTextColor
  property color mutedColor: frameConfig.mutedColor
  property string fontFamily: "Adwaita Sans, Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  property bool isOpen: false
  property bool hasOpenApps: false

  readonly property bool reduceMotion: root.frameConfig.reduceMotion

  signal openRequested()
  signal closeRequested()

  property bool isHoverOpen: false
  property bool isPinned: false

  readonly property bool isOpenEffective: root.isOpen || root.isHoverOpen || root.isPinned
  readonly property bool isHovered: Boolean(notchHover && notchHover.hovered)

  onIsOpenChanged: {
    if (!root.isOpen) {
      root.isPinned = false
      root.isHoverOpen = false
    }
  }

  function hoverOpen() {
    root.isHoverOpen = true
    root.refreshWallpapers()
    root.refreshMotionPreference()
  }

  function open() {
    root.isHoverOpen = true
    root.openRequested()
    root.refreshWallpapers()
    root.refreshMotionPreference()
  }

  function close() {
    root.isPinned = false
    root.isHoverOpen = false
    root.closeRequested()
  }

  function hoverClose() {
    if (root.isPinned || root.isOpen) return
    root.isHoverOpen = false
  }

  function armHoverClose() {
    if (root.isPinned || root.isOpen) return
    hoverCloseTimer.restart()
  }

  function toggle() {
    if (root.isOpenEffective) root.close()
    else root.open()
  }

  function tapPin() {
    if (root.isPinned) root.close()
    else root.isPinned = true
  }

  readonly property var wallpapers: wall.entries
  property int selectedIndex: 0
  property string selectedPath: ""
  readonly property string activePath: wall.currentPath
  property string pendingPath: ""
  property int pendingStep: 0
  property bool userNavigated: false

  function indexOfPath(path) {
    if (!path) return -1
    for (var i = 0; i < root.wallpapers.length; i++)
      if (root.wallpapers[i] && root.wallpapers[i].path === path) return i
    return -1
  }

  function refreshWallpapers(force) { root.syncSelectionToActive() }

  function syncActiveWallpaper() { root.syncSelectionToActive() }

  function syncSelectionToActive() {
    if (root.userNavigated) return
    var idx = root.indexOfPath(root.activePath)
    if (idx >= 0) root.selectedIndex = idx
  }

  // instant = apply right now (pointer click, fresh key press, IPC hop).
  // Otherwise the call is coalesced, which keeps held arrow keys from spawning
  // a shell per auto-repeat tick.
  function select(index, instant) {
    if (index < 0 || index >= root.wallpapers.length) return
    var entry = root.wallpapers[index]
    if (!entry) return
    root.userNavigated = true
    root.selectedIndex = index
    root.selectedPath = entry.path
    root.pendingPath = entry.path
    if (instant) {
      applyDebounce.stop()
      root.applyPath(entry.path)
    } else {
      applyDebounce.restart()
    }
    Qt.callLater(root.revealSelection)
  }

  function step(delta, instant, pin) {
    if (root.wallpapers.length === 0) {
      root.pendingStep = delta
      root.refreshWallpapers(true)
      return
    }
    // Only an explicit pin keeps the panel alive after the pointer leaves.
    // Keyboard stepping never pins, so hovering out always retracts.
    if (pin === true) root.isPinned = true
    var count = root.wallpapers.length
    root.select((root.selectedIndex + delta + count) % count, instant === true)
  }

  function nextWallpaper(instant) {
    root.step(1, instant !== false, false)
  }

  function previousWallpaper(instant) {
    root.step(-1, instant !== false, false)
  }

  function jumpTo(edge) {
    if (root.wallpapers.length === 0) return
    root.select(edge === "start" ? 0 : root.wallpapers.length - 1, true)
  }

  function revealSelection() {
    if (filmstrip && filmstrip.count > 0) {
      filmstrip.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    }
  }

  onSelectedIndexChanged: Qt.callLater(root.revealSelection)

  function applyPath(path) {
    if (!path) return
    wall.setWallpaper(path)
    root.syncSelectionToActive()
  }

  function refreshMotionPreference() {}

  Component.onCompleted: root.syncSelectionToActive()

  onIsOpenEffectiveChanged: {
    if (root.isOpenEffective) {
      root.userNavigated = false
      root.syncSelectionToActive()
      Qt.callLater(function() {
        if (keyCatcher) keyCatcher.forceActiveFocus()
      })
    }
  }

  readonly property real collapsedWidth: root.frameConfig.wallpaperCollapsedWidth

  readonly property int visibleThumbs: Math.max(1, Math.min(
    root.wallpapers.length > 0 ? root.wallpapers.length : root.frameConfig.wallpaperMaxVisibleThumbs,
    root.frameConfig.wallpaperMaxVisibleThumbs))

  readonly property real targetExpandedWidth: Math.max(root.collapsedWidth,
    root.frameConfig.wallpaperContentPadding * 2
      + root.visibleThumbs * root.frameConfig.wallpaperThumbWidth
      + Math.max(0, root.visibleThumbs - 1) * root.frameConfig.wallpaperThumbSpacing
      + 16)

  property real expandedWidth: targetExpandedWidth

  Behavior on expandedWidth {
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  readonly property real collapsedHeight: root.borderThickness
    + root.frameConfig.wallpaperCollapsedHeight
  readonly property real expandedHeight: root.borderThickness
    + root.frameConfig.wallpaperExpandedHeight

  readonly property real currentFlareRadius: root.frameConfig.wallpaperFlareRadius
    + (openProgress * (root.frameConfig.wallpaperExpandedFlareRadius - root.frameConfig.wallpaperFlareRadius))
  readonly property real currentCornerRadius: root.frameConfig.wallpaperCornerRadius
    + (openProgress * (root.frameConfig.wallpaperExpandedCornerRadius - root.frameConfig.wallpaperCornerRadius))

  readonly property real targetProgress: root.isOpenEffective ? 1.0 : 0.0
  property real openProgress: targetProgress

  Behavior on openProgress {
    NumberAnimation {
      duration: root.reduceMotion
        ? (root.isOpenEffective ? 180 : 140)
        : (root.isOpenEffective ? (root.frameConfig ? root.frameConfig.wallpaperOpenDuration : 380)
                                : (root.frameConfig ? root.frameConfig.wallpaperCloseDuration : 260))
      easing.type: (root.reduceMotion || !root.isOpenEffective) ? Easing.OutCubic : Easing.OutBack
      easing.overshoot: (root.reduceMotion || !root.isOpenEffective)
        ? 1.0
        : (root.frameConfig ? root.frameConfig.wallpaperOpenOvershoot : 1.04)
    }
  }

  readonly property real progressNorm: Math.min(1.0, Math.max(0.0, openProgress))

  readonly property real currentWidth: collapsedWidth
    + (progressNorm * (expandedWidth - collapsedWidth))
    + (Math.sin(progressNorm * Math.PI) * (root.frameConfig ? root.frameConfig.wallpaperWidthPulse : 0))

  readonly property real currentHeight: collapsedHeight
    + (openProgress * (expandedHeight - collapsedHeight))
    + (Math.sin(progressNorm * Math.PI) * (root.frameConfig ? root.frameConfig.wallpaperHeightPulse : 4))

  property alias maskItem: notchContainer
  property alias backdropItem: backdropOverlay
  property alias wakeItem: wakeZone

  Timer {
    id: hoverCloseTimer
    interval: root.frameConfig.wallpaperHoverCloseDelay
    repeat: false
    onTriggered: root.hoverClose()
  }

  Timer {
    id: applyDebounce
    interval: 140
    repeat: false
    onTriggered: if (root.pendingPath !== "") root.applyPath(root.pendingPath)
  }

  readonly property bool shouldRetract: root.hasOpenApps && !root.isOpenEffective
    && root.openProgress < root.frameConfig.wallpaperRetractProgressEpsilon && !root.isHovered

  readonly property bool wakeZoneActive: root.shouldRetract

  FluidSpring {
    id: retractSpring
    target: root.shouldRetract ? -(root.collapsedHeight - root.borderThickness) : 0.0
    response: root.shouldRetract
      ? root.frameConfig.wallpaperRetractResponse : root.frameConfig.wallpaperWakeResponse
    dampingFraction: root.shouldRetract
      ? root.frameConfig.wallpaperRetractDamping : root.frameConfig.wallpaperWakeDamping
    epsilon: 0.05
    reduceMotion: root.reduceMotion
  }

  Item {
    id: wakeZone
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    width: root.wakeZoneActive
      ? Math.max(root.frameConfig.wallpaperWakeZoneWidth, root.collapsedWidth) : 0
    height: root.wakeZoneActive ? root.borderThickness + root.frameConfig.wallpaperWakeZoneHeight : 0

    HoverHandler {
      id: wakeHover
      onHoveredChanged: {
        if (hovered) {
          hoverCloseTimer.stop()
          root.hoverOpen()
        } else {
          root.armHoverClose()
        }
      }
    }
  }

  Item {
    id: backdropOverlay
    width: root.isOpenEffective ? parent.width : 0
    height: root.isOpenEffective ? parent.height : 0
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    visible: root.isOpenEffective && root.openProgress > 0.01

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }
  }

  Item {
    id: notchContainer
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: retractSpring.value

    width: root.currentWidth
    height: root.currentHeight

    property color activeColor: root.notchColor

    readonly property real protrusion: Math.max(1, root.currentHeight - root.borderThickness)

    HoverHandler {
      id: notchHover
      cursorShape: root.isOpenEffective ? Qt.ArrowCursor : Qt.PointingHandCursor
      onHoveredChanged: {
        if (hovered) {
          hoverCloseTimer.stop()
          root.hoverOpen()
        } else {
          root.armHoverClose()
        }
      }
    }

    property bool isLipPressed: restingTap.pressed

    FluidSpring {
      id: lipPressSpring
      target: (!root.isOpenEffective && notchContainer.isLipPressed)
        ? root.frameConfig.wallpaperRestingPressScale : 1.0
      response: notchContainer.isLipPressed
        ? root.frameConfig.wallpaperPressResponse : root.frameConfig.wallpaperReleaseResponse
      dampingFraction: notchContainer.isLipPressed
        ? root.frameConfig.wallpaperPressDamping : root.frameConfig.wallpaperReleaseDamping
      epsilon: root.frameConfig.wallpaperSpringEpsilon
      reduceMotion: root.reduceMotion
      value: 1.0
    }

    scale: lipPressSpring.value
    transformOrigin: Item.Bottom

    Shape {
      id: silhouette
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      readonly property real w: silhouette.width
      readonly property real h: silhouette.height
      readonly property real b: root.borderThickness
      readonly property real protrusion: Math.max(1, h - b)

      readonly property real rFlare: Math.max(0.5,
        Math.min(root.currentFlareRadius, notchContainer.protrusion * 0.5))

      readonly property real freeWidth: Math.max(2, silhouette.w - 2 * silhouette.rFlare)
      readonly property real rCorner: Math.max(0, Math.min(root.currentCornerRadius,
        Math.max(0, notchContainer.protrusion - silhouette.rFlare),
        silhouette.freeWidth * root.frameConfig.wallpaperTopEdgeGuardRatio))

      readonly property real ctl: root.frameConfig.wallpaperFlareControlRatio
      readonly property real bleed: root.frameConfig.wallpaperBleed
      readonly property real borderTop: silhouette.h - silhouette.b

      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: notchContainer.activeColor
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        startX: 0
        startY: silhouette.h + silhouette.bleed

        PathLine {
          x: silhouette.w
          y: silhouette.h + silhouette.bleed
        }

        PathLine {
          x: silhouette.w
          y: silhouette.borderTop
        }

        PathCubic {
          x: silhouette.w - silhouette.rFlare
          y: silhouette.borderTop - silhouette.rFlare
          control1X: silhouette.w - (silhouette.rFlare * silhouette.ctl)
          control1Y: silhouette.borderTop
          control2X: silhouette.w - silhouette.rFlare
          control2Y: silhouette.borderTop - (silhouette.rFlare * silhouette.ctl)
        }

        PathLine {
          x: silhouette.w - silhouette.rFlare
          y: silhouette.rCorner
        }

        PathArc {
          x: silhouette.w - silhouette.rFlare - silhouette.rCorner
          y: 0
          radiusX: silhouette.rCorner
          radiusY: silhouette.rCorner
          direction: PathArc.Counterclockwise
        }

        PathLine {
          x: silhouette.rFlare + silhouette.rCorner
          y: 0
        }

        PathArc {
          x: silhouette.rFlare
          y: silhouette.rCorner
          radiusX: silhouette.rCorner
          radiusY: silhouette.rCorner
          direction: PathArc.Counterclockwise
        }

        PathLine {
          x: silhouette.rFlare
          y: silhouette.borderTop - silhouette.rFlare
        }

        PathCubic {
          x: 0
          y: silhouette.borderTop
          control1X: silhouette.rFlare
          control1Y: silhouette.borderTop - (silhouette.rFlare * silhouette.ctl)
          control2X: silhouette.rFlare * silhouette.ctl
          control2Y: silhouette.borderTop
        }

        PathLine {
          x: 0
          y: silhouette.h + silhouette.bleed
        }
      }
    }

    Item {
      id: restingArea
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      width: root.collapsedWidth
      height: root.collapsedHeight
      visible: root.openProgress < root.frameConfig.wallpaperRestingHideAt
      opacity: Math.max(0.0, 1.0 - root.openProgress * root.frameConfig.wallpaperRestingFadeRate)

      TapHandler {
        id: restingTap
        onTapped: root.tapPin()
      }
    }

    Item {
      id: expandedView
      anchors.fill: parent
      anchors.bottomMargin: root.borderThickness
      anchors.leftMargin: root.frameConfig.wallpaperContentPadding
      anchors.rightMargin: root.frameConfig.wallpaperContentPadding

      visible: opacity > 0.01
      opacity: Math.max(0.0, Math.min(1.0,
        (root.openProgress - root.frameConfig.wallpaperContentFadeStart)
          * root.frameConfig.wallpaperContentFadeRate))
      scale: root.frameConfig.wallpaperContentScaleFrom
        + ((1.0 - root.frameConfig.wallpaperContentScaleFrom) * root.progressNorm)
      transformOrigin: Item.Bottom

      ListView {
        id: filmstrip
        anchors.fill: parent

        orientation: ListView.Horizontal
        spacing: root.frameConfig.wallpaperThumbSpacing
        clip: false
        boundsBehavior: Flickable.StopAtBounds
        model: root.wallpapers
        currentIndex: root.selectedIndex
        cacheBuffer: root.frameConfig.wallpaperCacheBuffer
        reuseItems: true
        interactive: false

        delegate: Item {
          id: thumbDelegate

          readonly property var entry: modelData
          readonly property int itemIndex: index
          readonly property bool isSelected: itemIndex === root.selectedIndex
          readonly property bool isApplied: Boolean(entry) && entry.path === root.activePath

          width: root.frameConfig.wallpaperThumbWidth
          height: filmstrip.height

          Item {
            id: thumbFrame
            anchors.centerIn: parent
            width: root.frameConfig.wallpaperThumbWidth
            height: root.frameConfig.wallpaperThumbHeight

            FluidSpring {
              id: thumbSpring
              target: thumbDelegate.isSelected
                ? root.frameConfig.wallpaperSelectedScale
                : (thumbArea.containsMouse ? root.frameConfig.wallpaperHoverScale : 1.0)
              response: root.frameConfig.wallpaperThumbHoverResponse
              dampingFraction: root.frameConfig.wallpaperThumbHoverDamping
              epsilon: root.frameConfig.wallpaperSpringEpsilon
              reduceMotion: root.reduceMotion
              value: 1.0
            }

            scale: thumbSpring.value

            Rectangle {
              anchors.fill: parent
              radius: root.frameConfig.wallpaperThumbRadius
              color: root.frameConfig.wallpaperThumbBg
            }

            Rectangle {
              id: thumbMask
              anchors.fill: parent
              radius: root.frameConfig.wallpaperThumbRadius
              color: "#ffffff"
              visible: false
              layer.enabled: true
            }

            Item {
              anchors.fill: parent
              layer.enabled: true
              layer.smooth: true
              layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: thumbMask
              }

              Image {
                id: thumbImage
                anchors.fill: parent
                source: thumbDelegate.entry ? wall.thumbUrl(thumbDelegate.entry.path) : ""
                sourceSize.width: root.frameConfig.wallpaperThumbWidth
                  * root.frameConfig.wallpaperThumbSourceScale
                sourceSize.height: root.frameConfig.wallpaperThumbHeight
                  * root.frameConfig.wallpaperThumbSourceScale
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true

                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity {
                  NumberAnimation {
                    duration: root.frameConfig.wallpaperThumbFadeDuration
                    easing.type: Easing.OutCubic
                  }
                }
              }
            }

            Rectangle {
              anchors.fill: parent
              radius: root.frameConfig.wallpaperThumbRadius
              color: root.frameConfig.wallpaperItemHoverBg
              opacity: (thumbArea.containsMouse && !thumbDelegate.isSelected) ? 1 : 0

              Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            Rectangle {
              anchors.fill: parent
              radius: root.frameConfig.wallpaperThumbRadius
              color: "transparent"
              border.width: thumbDelegate.isSelected
                ? root.frameConfig.wallpaperSelectedBorderWidth
                : (thumbDelegate.isApplied
                  ? root.frameConfig.wallpaperAppliedBorderWidth
                  : 1)
              border.color: thumbDelegate.isSelected
                ? root.frameConfig.wallpaperThumbActiveBorder
                : (thumbDelegate.isApplied
                  ? root.frameConfig.wallpaperAppliedBorderColor
                  : (thumbArea.containsMouse ? root.frameConfig.wallpaperThumbHoverBorder
                                             : root.frameConfig.wallpaperThumbBorder))

              Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
              id: thumbArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.select(thumbDelegate.itemIndex, true)
            }
          }
        }
      }

      Item {
        anchors.fill: parent

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            if (Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)) {
              if (event.angleDelta.x > 0) root.step(1, true)
              else if (event.angleDelta.x < 0) root.step(-1, true)
            } else if (event.angleDelta.y !== 0) {
              root.step(event.angleDelta.y > 0 ? -1 : 1, true)
            }
            event.accepted = true
          }
        }
      }

      Row {
        visible: false
        Repeater {
          model: root.wallpapers

          delegate: Image {
            required property var modelData
            width: 0
            height: 0
            source: wall.thumbUrl(modelData.path)
            sourceSize.width: root.frameConfig.wallpaperThumbWidth
              * root.frameConfig.wallpaperThumbSourceScale
            sourceSize.height: root.frameConfig.wallpaperThumbHeight
              * root.frameConfig.wallpaperThumbSourceScale
            asynchronous: true
            cache: true
          }
        }
      }

      Item {
        anchors.fill: parent

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            if (Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)) {
              if (event.angleDelta.x > 0) root.step(1, true)
              else if (event.angleDelta.x < 0) root.step(-1, true)
            } else if (event.angleDelta.y !== 0) {
              root.step(event.angleDelta.y > 0 ? -1 : 1, true)
            }
            event.accepted = true
          }
        }
      }
    }
  }

  Item {
    id: keyCatcher
    anchors.fill: parent
    focus: root.isOpenEffective

    Keys.onPressed: function(event) {
      if (!root.isOpenEffective) return

      var instant = !event.isAutoRepeat

      switch (event.key) {
      case Qt.Key_Left:
        root.step(-1, instant)
        event.accepted = true
        break
      case Qt.Key_Right:
        root.step(1, instant)
        event.accepted = true
        break
      case Qt.Key_Up:
        root.step(-1, instant)
        event.accepted = true
        break
      case Qt.Key_Down:
        root.step(1, instant)
        event.accepted = true
        break
      case Qt.Key_Home:
        root.jumpTo("start")
        event.accepted = true
        break
      case Qt.Key_End:
        root.jumpTo("end")
        event.accepted = true
        break
      case Qt.Key_Return:
      case Qt.Key_Enter:
        root.close()
        event.accepted = true
        break
      case Qt.Key_Escape:
        root.close()
        event.accepted = true
        break
      default:
        break
      }
    }
  }
}
