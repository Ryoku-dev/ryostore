import QtQuick
import shell.services

Item {
  id: root

  readonly property var notif: (Notifs.popups && Notifs.popups.length > 0) ? Notifs.popups[0] : null

  readonly property bool hasNotification: !!notif
  readonly property string currentSummary: notif ? String(notif.summary || "") : ""
  readonly property string currentBody: notif ? String(notif.body || "") : ""
  readonly property string currentAppName: notif ? String(notif.appName || "") : ""
  readonly property string currentAppIcon: notif ? String(notif.appIcon || "") : ""
  readonly property string currentImage: notif ? String(notif.image || "") : ""
  readonly property string currentGlyph: ""
  readonly property int currentUrgency: notif ? Number(notif.urgency || 1) : 1
  readonly property bool dnd: Flags.dnd

  property bool isHovered: false

  function dismissCurrent() {
    if (root.notif) Notifs.dismiss(root.notif)
  }

  function invokeAction() {
    if (!root.notif) return
    var acts = root.notif.actions || []
    if (acts.length > 0 && typeof root.notif.invokeAction === "function")
      root.notif.invokeAction(acts[0].identifier)
    else
      Notifs.dismiss(root.notif)
  }
}
