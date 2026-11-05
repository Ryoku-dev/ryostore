pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.Ui.Singletons
import "."
import "components"
import "island"
import "power"
import "tray"
import "workspaces"
import "control"
import "wallpaper"
import "search"
import "settings"

Scope {
  id: root

  property var modelData: null

  readonly property var screen: root.modelData
  readonly property string screenName: root.screen ? String(root.screen.name) : ""
  readonly property string fontFamily: "Adwaita Sans, Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"

  readonly property bool fullscreen: root.screenName !== "" && Wm.outputHasFullscreen(root.screenName)

  readonly property bool hasOpenApps: {
    if (root.screenName === "") return false
    const all = Wm.workspaces || []
    for (let i = 0; i < all.length; i++) {
      const w = all[i]
      if (w.special) continue
      if (w.output && String(w.output) !== root.screenName) continue
      if (Number(w.windows || 0) > 0) return true
    }
    return false
  }

  readonly property bool isFocusedScreen: root.screenName === "" || Wm.focusedOutput === ""
    || String(Wm.focusedOutput) === root.screenName

  GlobalState { id: global }
  FrameConfig { id: cfg; settings: global.settings }

  property bool controlOpen: false
  property bool wallpaperOpen: false
  property bool settingsOpen: false

  onFullscreenChanged: {
    if (root.fullscreen) {
      root.controlOpen = false
      root.wallpaperOpen = false
      root.settingsOpen = false
    }
  }

  // The top edge: border line, both corners, and the island.
  PanelWindow {
    id: topWindow
    screen: root.screen

    visible: !root.fullscreen
    anchors {
      top: true
      left: true
      right: true
    }
    implicitHeight: 380
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "ryoku-lumania-top"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: cfg.borderThickness

    mask: Region {
      Region { item: topBarLine }
      Region { item: topLeftCorner }
      Region { item: topRightCorner }
      Region { item: island.islandMaskItem }
    }

    Rectangle {
      id: topBarLine
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: cfg.borderThickness
      color: cfg.activeBorderColor
    }

    FrameCorner {
      id: topLeftCorner
      anchors.top: parent.top
      anchors.left: parent.left
      corner: "topLeft"
      thickness: cfg.borderThickness
      radius: cfg.topLeftRadius
      color: cfg.activeBorderColor
      style: cfg.cornerStyle
      squircleFactor: cfg.squircleFactor
    }

    FrameCorner {
      id: topRightCorner
      anchors.top: parent.top
      anchors.right: parent.right
      corner: "topRight"
      thickness: cfg.borderThickness
      radius: cfg.topRightRadius
      color: cfg.activeBorderColor
      style: cfg.cornerStyle
      squircleFactor: cfg.squircleFactor
    }

    Island {
      id: island
      anchors.fill: parent
      frameConfig: cfg
      borderThickness: cfg.borderThickness
      islandColor: cfg.activeBorderColor
      islandTextColor: cfg.activeTextColor
      islandMutedColor: cfg.mutedColor
      fontFamily: root.fontFamily
      hasOpenApps: root.hasOpenApps
      showNotifications: cfg.islandNotifications
    }
  }

  PanelWindow {
    id: powerWindow
    screen: root.screen

    visible: !root.fullscreen
    anchors {
      top: true
      left: true
      right: true
    }
    implicitHeight: Math.ceil(powerNotch.baseHeight + 8)
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "ryoku-lumania-power"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
      Region { item: powerNotch.maskItem }
      Region { item: powerNotch.wakeItem }
    }

    PowerNotch {
      id: powerNotch
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.leftMargin: cfg.borderThickness + cfg.topLeftRadius
        + cfg.powerNotchLeftMargin
      frameConfig: cfg
      borderThickness: cfg.borderThickness
      notchColor: cfg.activeBorderColor
      textColor: cfg.activeTextColor
      mutedColor: cfg.mutedColor
      fontFamily: root.fontFamily
      hasOpenApps: root.hasOpenApps
    }
  }

  PanelWindow {
    id: trayWindow
    screen: root.screen

    visible: !root.fullscreen
    anchors {
      top: true
      left: true
      right: true
    }
    implicitHeight: Math.ceil(trayNotch.baseHeight + 8)
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "ryoku-lumania-tray"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
      Region { item: trayNotch.maskItem }
      Region { item: trayNotch.wakeItem }
    }

    TrayNotch {
      id: trayNotch
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.rightMargin: cfg.borderThickness + cfg.topRightRadius
        + cfg.trayNotchRightMargin
      frameConfig: cfg
      borderThickness: cfg.borderThickness
      notchColor: cfg.activeBorderColor
      textColor: cfg.activeTextColor
      mutedColor: cfg.mutedColor
      fontFamily: root.fontFamily
      hasOpenApps: root.hasOpenApps
    }
  }

  PanelWindow {
    id: workspaceWindow
    screen: root.screen

    visible: !root.fullscreen
    anchors {
      left: true
      top: true
    }
    implicitWidth: cfg.workspaceWidth + 30
    implicitHeight: cfg.workspaceTopMargin + workspaceRail.targetHeight + 30
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "ryoku-lumania-workspaces"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
      Region { item: workspaceRail.maskItem }
    }

    WorkspaceRail {
      id: workspaceRail
      anchors.fill: parent
      frameConfig: cfg
      borderThickness: cfg.borderThickness
      notchColor: cfg.activeBorderColor
      textColor: cfg.activeTextColor
      mutedColor: cfg.mutedColor
      fontFamily: root.fontFamily
      hasOpenApps: root.hasOpenApps
      screenName: root.screenName
    }
  }

  // Bottom and side bezels.
  PanelWindow {
    id: bottomWindow
    screen: root.screen

    visible: !root.fullscreen
    anchors {
      bottom: true
      left: true
      right: true
    }
    implicitHeight: cfg.borderThickness
      + Math.max(cfg.bottomLeftRadius, cfg.bottomRightRadius)
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "ryoku-lumania-frame-bottom"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: cfg.borderThickness

    mask: Region {
      Region { item: bottomBarLine }
      Region { item: bottomLeftCorner }
      Region { item: bottomRightCorner }
    }

    Rectangle {
      id: bottomBarLine
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: cfg.borderThickness
      color: cfg.activeBorderColor
    }

    FrameCorner {
      id: bottomLeftCorner
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      corner: "bottomLeft"
      thickness: cfg.borderThickness
      radius: cfg.bottomLeftRadius
      color: cfg.activeBorderColor
      style: cfg.cornerStyle
      squircleFactor: cfg.squircleFactor
    }

    FrameCorner {
      id: bottomRightCorner
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      corner: "bottomRight"
      thickness: cfg.borderThickness
      radius: cfg.bottomRightRadius
      color: cfg.activeBorderColor
      style: cfg.cornerStyle
      squircleFactor: cfg.squircleFactor
    }
  }

  PanelWindow {
    id: leftWindow
    screen: root.screen

    visible: !root.fullscreen
    anchors {
      left: true
      top: true
      bottom: true
    }
    implicitWidth: cfg.borderThickness
    color: cfg.activeBorderColor
    surfaceFormat.opaque: true
    WlrLayershell.namespace: "ryoku-lumania-frame-left"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: cfg.borderThickness
  }

  PanelWindow {
    id: rightWindow
    screen: root.screen

    visible: !root.fullscreen
    anchors {
      right: true
      top: true
      bottom: true
    }
    implicitWidth: cfg.borderThickness
    color: cfg.activeBorderColor
    surfaceFormat.opaque: true
    WlrLayershell.namespace: "ryoku-lumania-frame-right"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: cfg.borderThickness
  }

  PanelWindow {
    id: controlWindow
    screen: root.screen

    visible: !root.fullscreen
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "ryoku-lumania-control"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
      Region { item: controlCenter.maskItem }
      Region { item: controlCenter.wakeItem }
      Region { item: controlCenter.backdropItem }
      Region { item: controlCenter.subpanelMaskItem }
    }

    ControlCenter {
      id: controlCenter
      anchors.fill: parent
      frameConfig: cfg
      borderThickness: cfg.borderThickness
      notchColor: cfg.activeBorderColor
      fontFamily: root.fontFamily
      hasOpenApps: root.hasOpenApps
      isOpen: root.controlOpen
      onOpenRequested: root.controlOpen = true
      onCloseRequested: root.controlOpen = false
    }
  }

  PanelWindow {
    id: searchWindow
    screen: root.screen

    visible: !root.fullscreen
    anchors {
      bottom: true
      left: true
    }
    implicitWidth: searchGusset.collapsedWidth
    implicitHeight: searchGusset.collapsedHeight
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "ryoku-lumania-search"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
      Region { item: searchGusset.maskItem }
      Region { item: searchGusset.wakeItem }
    }

    SearchGusset {
      id: searchGusset
      anchors.fill: parent
      frameConfig: cfg
      borderThickness: cfg.borderThickness
      notchColor: cfg.activeBorderColor
      hasOpenApps: root.hasOpenApps
      onActivateRequested: Quickshell.execDetached(["ryoku-shell", "launcher"])
      onSettingsRequested: root.settingsOpen = !root.settingsOpen
    }
  }

  PanelWindow {
    id: settingsWindow
    screen: root.screen

    visible: root.settingsOpen
    anchors {
      bottom: true
      left: true
    }
    implicitWidth: settingsPanel.implicitWidth + 36
    implicitHeight: settingsPanel.implicitHeight + 36
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "ryoku-lumania-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: root.settingsOpen
      ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
      Region { item: settingsPanel.cardItem }
    }

    SettingsPanel {
      id: settingsPanel
      anchors.fill: parent
      anchors.margins: 18
      settings: global
      frameConfig: cfg
      fontFamily: root.fontFamily
      onCloseRequested: root.settingsOpen = false
    }
  }

  PanelWindow {
    id: wallpaperWindow
    screen: root.screen

    visible: !root.fullscreen
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "ryoku-lumania-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: (wallpaperStrip.isOpenEffective && root.isFocusedScreen)
      ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
      Region { item: wallpaperStrip.maskItem }
      Region { item: wallpaperStrip.backdropItem }
      Region { item: wallpaperStrip.wakeItem }
    }

    WallpaperStrip {
      id: wallpaperStrip
      anchors.fill: parent
      frameConfig: cfg
      borderThickness: cfg.borderThickness
      notchColor: cfg.activeBorderColor
      textColor: cfg.activeTextColor
      mutedColor: cfg.mutedColor
      fontFamily: root.fontFamily
      hasOpenApps: root.hasOpenApps
      isOpen: root.wallpaperOpen
      onOpenRequested: root.wallpaperOpen = true
      onCloseRequested: root.wallpaperOpen = false
    }
  }
}
