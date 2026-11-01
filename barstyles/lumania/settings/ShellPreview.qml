pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import shell.services
import "../components"
import "../island"
import "../tray"
import "../power"
import "../workspaces"
import "../control"
import "../search"
import "../dock"

// Live miniature of the desktop: the real rails at 1920x1080, scaled to fit.
Item {
  id: root

  required property var frameConfig
  property var settings: null
  property string fontFamily: ""
  property bool active: false
  property string focusRail: ""

  readonly property var cfg: root.frameConfig
  readonly property real stageWidth: 1920
  readonly property real stageHeight: 1080
  readonly property real fit: Math.min(width / stageWidth, height / stageHeight)

  readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME")
    || (Quickshell.env("HOME") + "/.cache")) + "/ryogami"
  property string wallpaperPath: ""

  // The desktop behind the rails is the wallpaper that is actually set.
  FileView {
    path: root.cacheDir + "/outputs.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.readOutputs(text())
    onFileChanged: reload()
  }

  function readOutputs(text) {
    var data = {}
    try { data = JSON.parse(text) } catch (e) { return }
    var keys = Object.keys(data || {})
    var entry = data["*"] || (keys.length > 0 ? data[keys[0]] : null)
    if (!entry || !entry.path) return
    var path = String(entry.path)
    if (path.indexOf("~/") === 0) path = Quickshell.env("HOME") + path.slice(1)
    root.wallpaperPath = path
  }

  function railOpacity(id) {
    if (root.focusRail === "") return 1.0
    return root.focusRail === id ? 1.0 : 0.3
  }

  Rectangle {
    anchors.fill: parent
    radius: 14
    color: Theme.surfaceContainerLowest
    border.width: 1
    border.color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
    clip: true

    Loader {
      anchors.fill: parent
      active: root.active
      sourceComponent: stageComp
    }
  }

  Component {
    id: stageComp

    Item {
      anchors.fill: parent

      Item {
        id: stage
        width: root.stageWidth
        height: root.stageHeight
        x: Math.round((root.width - width * root.fit) / 2)
        y: Math.round((root.height - height * root.fit) / 2)
        scale: root.fit
        transformOrigin: Item.TopLeft
        enabled: false

        Rectangle {
          anchors.fill: parent
          color: Theme.surfaceContainerLowest
        }

        Rectangle {
          anchors.fill: parent
          anchors.margins: root.cfg.borderThickness
          color: Theme.surfaceContainerHigh
        }

        Image {
          anchors.fill: parent
          anchors.margins: root.cfg.borderThickness
          source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
          sourceSize.width: 384
          sourceSize.height: 216
          fillMode: Image.PreserveAspectCrop
          visible: status === Image.Ready
          smooth: true
          asynchronous: true
        }

        Rectangle {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: root.cfg.borderThickness
          color: root.cfg.activeBorderColor
        }

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: root.cfg.borderThickness
          color: root.cfg.activeBorderColor
        }

        Rectangle {
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          width: root.cfg.borderThickness
          color: root.cfg.activeBorderColor
        }

        Rectangle {
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          width: root.cfg.borderThickness
          color: root.cfg.activeBorderColor
        }

        FrameCorner {
          anchors.top: parent.top
          anchors.left: parent.left
          corner: "topLeft"
          thickness: root.cfg.borderThickness
          radius: root.cfg.topLeftRadius
          color: root.cfg.activeBorderColor
          style: root.cfg.cornerStyle
          squircleFactor: root.cfg.squircleFactor
        }

        FrameCorner {
          anchors.top: parent.top
          anchors.right: parent.right
          corner: "topRight"
          thickness: root.cfg.borderThickness
          radius: root.cfg.topRightRadius
          color: root.cfg.activeBorderColor
          style: root.cfg.cornerStyle
          squircleFactor: root.cfg.squircleFactor
        }

        FrameCorner {
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          corner: "bottomLeft"
          thickness: root.cfg.borderThickness
          radius: root.cfg.bottomLeftRadius
          color: root.cfg.activeBorderColor
          style: root.cfg.cornerStyle
          squircleFactor: root.cfg.squircleFactor
        }

        FrameCorner {
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          corner: "bottomRight"
          thickness: root.cfg.borderThickness
          radius: root.cfg.bottomRightRadius
          color: root.cfg.activeBorderColor
          style: root.cfg.cornerStyle
          squircleFactor: root.cfg.squircleFactor
        }

        Item {
          anchors.fill: parent
          visible: root.cfg.railEnabled("island")
          opacity: root.railOpacity("island")

          Island {
            anchors.fill: parent
            frameConfig: root.cfg
            borderThickness: root.cfg.borderThickness
            islandColor: root.cfg.activeBorderColor
            islandTextColor: root.cfg.activeTextColor
            islandMutedColor: root.cfg.mutedColor
            fontFamily: root.fontFamily
            hasOpenApps: false
            showNotifications: false
          }
        }

        Item {
          anchors.fill: parent
          visible: root.cfg.railEnabled("power")
          opacity: root.railOpacity("power")

          PowerNotch {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: root.cfg.borderThickness + root.cfg.topLeftRadius
              + root.cfg.powerNotchLeftMargin
            frameConfig: root.cfg
            borderThickness: root.cfg.borderThickness
            notchColor: root.cfg.activeBorderColor
            textColor: root.cfg.activeTextColor
            mutedColor: root.cfg.mutedColor
            fontFamily: root.fontFamily
            hasOpenApps: false
          }
        }

        Item {
          anchors.fill: parent
          visible: root.cfg.railEnabled("tray")
          opacity: root.railOpacity("tray")

          TrayNotch {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: root.cfg.borderThickness + root.cfg.topRightRadius
              + root.cfg.trayNotchRightMargin
            frameConfig: root.cfg
            borderThickness: root.cfg.borderThickness
            notchColor: root.cfg.activeBorderColor
            textColor: root.cfg.activeTextColor
            mutedColor: root.cfg.mutedColor
            fontFamily: root.fontFamily
            hasOpenApps: false
          }
        }

        Item {
          anchors.fill: parent
          visible: root.cfg.railEnabled("workspaces")
          opacity: root.railOpacity("workspaces")

          Item {
            id: workspaceSlot
            anchors.top: parent.top
            anchors.left: parent.left
            width: root.cfg.workspaceWidth + 30
            height: root.cfg.workspaceTopMargin + previewWorkspaces.targetHeight + 30

            WorkspaceRail {
              id: previewWorkspaces
              anchors.fill: parent
              frameConfig: root.cfg
              borderThickness: root.cfg.borderThickness
              notchColor: root.cfg.activeBorderColor
              textColor: root.cfg.activeTextColor
              mutedColor: root.cfg.mutedColor
              fontFamily: root.fontFamily
              hasOpenApps: false
              screenName: ""
            }
          }
        }

        Item {
          anchors.fill: parent
          opacity: root.railOpacity("control")

          ControlCenter {
            anchors.fill: parent
            frameConfig: root.cfg
            borderThickness: root.cfg.borderThickness
            notchColor: root.cfg.activeBorderColor
            fontFamily: root.fontFamily
            hasOpenApps: false
            isOpen: false
          }
        }

        Item {
          anchors.fill: parent
          opacity: root.railOpacity("search")

          Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: root.cfg.searchCollapsedWidth
            height: root.cfg.borderThickness
              + Math.max(root.cfg.searchCollapsedHeight, root.cfg.searchLeftTabHeight)

            SearchGusset {
              anchors.fill: parent
              frameConfig: root.cfg
              borderThickness: root.cfg.borderThickness
              notchColor: root.cfg.activeBorderColor
              hasOpenApps: false
            }
          }
        }

        Item {
          anchors.fill: parent
          visible: root.cfg.railEnabled("dock")
          opacity: root.railOpacity("dock")

          Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: previewDock.targetHeight

            AppDock {
              id: previewDock
              anchors.fill: parent
              frameConfig: root.cfg
              settings: root.settings
              borderThickness: root.cfg.borderThickness
              notchColor: root.cfg.activeBorderColor
              textColor: root.cfg.activeTextColor
              mutedColor: root.cfg.mutedColor
              fontFamily: root.fontFamily
              screenName: ""
              preview: true
            }
          }
        }
      }
    }
  }
}
