import Quickshell
import Quickshell.Hyprland
import QtQuick
import shell.services as Ryoku
import "../../../services"
import "../../../modules/common/widgets"

// The tray's popup layer — two PopupWindows under the bar:
//
//   - `popup`: the dropdown, a capsule with the icon of every tray app
//     that isn't pinned, centered under the tray button, when `open`
//     is true
//   - `menuPopup`: the right-click menu for one app: below the capsule
//     when the dropdown is open, or (for a right-click on a pinned icon
//     in the bar, dropdown closed) on its own, centered under that icon
//
// The menu is its own window, mapped only once the app's entries have
// arrived, so it appears at its final size and place in one go. When it
// was a part of the dropdown's window, opening it meant resizing a popup
// that was already on screen, and the compositor showed that as the
// whole popup jumping sideways for a moment. Both windows hang off the
// bar itself, so the menu is never a popup of a popup.
//
// Together with Bar.qml and TraySource.qml this is where tray clicks turn
// into real actions; TrayCollection / TrayMenu only report clicks.
//
//   left click    open the app (activate). Apps that only publish a
//                 menu (`onlyMenu`) get their menu instead.
//   middle click  the app's secondary action
//   right click   the menu
//
// `open` is owned by Bar.qml (the tray button toggles it); this asks
// for it to be closed via closeRequested() — after an action, or when
// you click anywhere outside the tray.
//
// Pin / Unpin plays out over about a quarter of a second: the icon
// shrinks away where it is (`leavingItem`), then the pin actually
// flips, and it pops in on the other side while both capsules glide to
// their new widths.
Scope {
    id: root

    property var parentWindow: null
    readonly property real uiScale: root.parentWindow && root.parentWindow.uiScale ? root.parentWindow.uiScale : 1
    property var source: null
    property Item toggleAnchor: null

    property bool open: false

    readonly property bool capsuleStyle: !!root.parentWindow && root.parentWindow.barStyle === 3

    readonly property string barEdge: root.parentWindow && root.parentWindow.barPosition
        ? root.parentWindow.barPosition : "top"

    readonly property int gravity: root.parentWindow ? root.parentWindow.popupGravity : (Edges.Bottom | Edges.Right)

    function windowLeft(w) {
        return w.anchor.rect.x - ((root.gravity & Edges.Left) ? w.implicitWidth : 0)
    }

    function windowTop(w) {
        return w.anchor.rect.y - ((root.gravity & Edges.Top) ? w.implicitHeight : 0)
    }

    property real dropReveal: 0

    NumberAnimation {
        id: dropPopIn
        target: root
        property: "dropReveal"
        to: 1
        duration: 340
        easing.type: Easing.OutBack
        easing.overshoot: 1.3
    }

    NumberAnimation {
        id: dropSwallow
        target: root
        property: "dropReveal"
        to: 0
        duration: 170
        easing.type: Easing.InCubic
    }

    Connections {
        target: PopupHandoff

        function onSerialChanged() {
            if (!root.open && root.dropReveal > 0) {
                dropSwallow.stop()
                dropPopIn.stop()
                root.dropReveal = 0
            }
        }
    }

    // Click-anywhere-else-to-dismiss (Hyprland's focus grab). If clicks
    // on the dropdown ever seem to do nothing, set this to false and
    // reload: clicks work regardless, you just close it with the tray
    // button (or by picking something) instead.
    property bool useFocusGrab: true

    signal closeRequested()

    property var menuItem: null
    property var menuStack: []
    property real pinnedIconX: 0
    property real pinnedIconY: 0

    readonly property real gapTop: 6
    readonly property real gapBetween: 6

    readonly property real bleed: 14

    readonly property real dropPadT: barEdge === "top" ? gapTop : bleed
    readonly property real dropPadB: barEdge === "bottom" ? gapTop : bleed
    readonly property real dropPadL: barEdge === "left" ? gapTop : bleed
    readonly property real dropPadR: barEdge === "right" ? gapTop : bleed

    readonly property real menuPadT: barEdge === "top" ? 0 : bleed
    readonly property real menuPadB: barEdge === "bottom" ? 0 : bleed
    readonly property real menuPadL: barEdge === "left" ? 0 : bleed
    readonly property real menuPadR: barEdge === "right" ? 0 : bleed

    // The menu window is only mapped once the app's entries are in (see
    // startPop), so it never has to resize while it's on screen.
    property bool menuReady: false

    readonly property int entryCount: root.menuEntries.length
    onEntryCountChanged: {
        if (popPending && entryCount > 0)
            popSettle.restart()
    }

    property bool menuPinned: false

    property var leavingItem: null

    property real windowW: 0
    onWindowWChanged: console.log("[tray] popup width " + windowW)

    property bool menuOnly: false

    readonly property var menuRoot: root.menuItem ? root.source.menuTreeFor(root.menuItem) : null
    readonly property var menuNode: root.menuStack.length > 0
        ? root.menuStack[root.menuStack.length - 1]
        : root.menuRoot

    // The Ryoku daemon menu tree -> the row shape TrayMenu draws.
    function rowsFor(node) {
        const kids = (node && node.children) ? node.children : []
        const out = []
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i]
            if (!c || c.visible === false)
                continue
            const hasKids = c.type !== "separator" && Array.isArray(c.children) && c.children.length > 0
            out.push({
                node: c,
                text: c.type === "separator" ? "" : (c.label || ""),
                isSeparator: c.type === "separator",
                enabled: c.enabled !== false,
                hasChildren: hasKids,
                icon: ""
            })
        }
        return out
    }

    readonly property var menuEntries: root.rowsFor(root.menuNode)

    function fireEntry(entry) {
        if (!entry || !entry.node)
            return
        Ryoku.Tray.menuEvent(root.menuItem ? root.menuItem.service : "", entry.node.id)
        root.closeAll()
    }

    function enterSubmenu(entry) {
        if (entry && entry.node)
            root.menuStack = root.menuStack.concat([entry.node])
    }

    readonly property real dropdownCenterX: {
        void root.open
        return toggleAnchor ? toggleAnchor.mapToItem(null, toggleAnchor.width / 2, 0).x : 0
    }

    readonly property real dropdownCenterY: {
        void root.open
        return toggleAnchor ? toggleAnchor.mapToItem(null, 0, toggleAnchor.height / 2).y : 0
    }

    onOpenChanged: {
        if (open) {
            PopupHandoff.opening()
            dropSwallow.stop()
            dropPopIn.restart()
        } else {
            dropPopIn.stop()
            dropSwallow.restart()
        }
        capsuleLive = false
        if (open) {
            menuOnly = false
            shrinkHold.stop()
            windowW = wantW
            liveTimer.restart()
        } else {
            liveTimer.stop()
        }
        closeMenu()
    }

    property bool capsuleLive: false

    Timer {
        id: liveTimer
        interval: 120
        onTriggered: root.capsuleLive = true
    }

    property bool menuLeaving: false

    function closeMenu() {
        popPending = false
        popFallback.stop()
        popSettle.stop()
        if (menuReady && menuItem !== null && menuCard.popProgress > 0.001) {
            menuLeaving = true
            menuReady = false
            menuCard.away()
            return
        }
        finishCloseMenu()
    }

    function finishCloseMenu() {
        menuLeaving = false
        menuReady = false
        menuStack = []
        menuItem = null
    }

    function closeAll() {
        closeMenu()
        if (open)
            closeRequested()
    }

    function openMenu(item, icon, inDropdown) {
        if (!item || !item.hasMenu) {
            console.log("[tray] " + (item ? item.id : "?") + " has no menu to show")
            return
        }
        menuCard.hold()
        menuLeaving = false
        menuPinned = root.source ? root.source.isPinned(item) : false
        menuStack = []
        if (open) {
            menuOnly = false
        } else {
            menuOnly = true
            pinnedIconX = icon.mapToItem(null, icon.width / 2, 0).x
            pinnedIconY = icon.mapToItem(null, 0, icon.height / 2).y
        }
        menuItem = item
        Ryoku.Tray.aboutToShow(item.service)
        startPop()
    }

    // The menu's entries arrive over D-Bus a moment after the right-click,
    // so the card is first the size of its "Pin" row alone and then grows
    // to its real size. So the menu window isn't mapped until the entries
    // are in (plus a short settle for rows that trickle in), and then it
    // appears at its final size and plays the pop-in. The fallback covers
    // a menu that publishes nothing, or entries that were already cached
    // and so never change the count. Right-clicking another icon while a
    // menu is up takes the same road: the window unmaps and maps again.
    property bool popPending: false

    function startPop() {
        menuReady = false
        popPending = true
        popFallback.restart()
        if (entryCount > 0)
            popSettle.restart()
    }

    function firePop() {
        if (!popPending)
            return
        popPending = false
        popFallback.stop()
        popSettle.stop()
        menuReady = true
        menuCard.pop()
    }

    Timer {
        id: popFallback
        interval: 160
        onTriggered: root.firePop()
    }

    Timer {
        id: popSettle
        interval: 30
        onTriggered: root.firePop()
    }

    function pinWithAnimation(item) {
        closeMenu()
        if (!item)
            return
        leavingItem = item
        pinTimer.pendingItem = item
        pinTimer.restart()
    }

    Timer {
        id: pinTimer
        interval: 120
        property var pendingItem: null
        onTriggered: {
            if (root.source)
                root.source.togglePinned(pendingItem)
            root.leavingItem = null
            pendingItem = null
        }
    }

    // Width the dropdown window should have. It's always at least as wide
    // as a menu card, so the capsule gliding wider or narrower as icons
    // come and go never has to resize a window that's on screen (a
    // Wayland compositor can move a popup and redraw it at its new size
    // as two separate steps). The capsule stays centered in the window,
    // so it looks exactly the same.
    readonly property real wantW: open
        ? Math.max(capsule.implicitWidth, menuCard.maxWidth)
        : 0

    onWantWChanged: {
        if (!open)
            return
        if (wantW >= windowW) {
            shrinkHold.stop()
            windowW = wantW
        } else {
            shrinkHold.restart()
        }
    }


    Timer {
        id: shrinkHold
        interval: 280
        onTriggered: root.windowW = root.wantW
    }

    function handleClick(item, button, icon, inDropdown) {
        if (!item)
            return
        console.log("[tray] click " + item.id + " button=" + button
            + " onlyMenu=" + item.onlyMenu + " hasMenu=" + item.hasMenu
            + (inDropdown ? " (dropdown)" : " (pinned)"))
        if (button === Qt.RightButton) {
            openMenu(item, icon, inDropdown)
        } else if (button === Qt.MiddleButton) {
            item.secondaryActivate()
            closeAll()
        } else if (item.onlyMenu) {
            openMenu(item, icon, inDropdown)
        } else {
            item.activate()
            closeAll()
        }
    }

    function handleScroll(item, delta, horizontal) {
        if (item && SettingsService.flag("tray.scroll"))
            item.scroll(delta, horizontal)
    }


    readonly property bool grabWanted: useFocusGrab && (popup.visible || menuPopup.visible)

    onGrabWantedChanged: {
        if (grabWanted) {
            grabDelay.restart()
        } else {
            grabDelay.stop()
            grab.active = false
        }
    }

    Timer {
        id: grabDelay
        interval: 80
        onTriggered: grab.active = root.grabWanted
    }

    HyprlandFocusGrab {
        id: grab
        windows: [popup, menuPopup, root.parentWindow]
        onCleared: {
            console.log("[tray] focus grab cleared (click outside the tray)")
            root.closeAll()
        }
    }

    PopupWindow {
        id: popup

        visible: (root.open || root.dropReveal > 0.001) && root.parentWindow !== null

        anchor.window: root.parentWindow
        anchor.rect.x: {
            const pw = root.parentWindow
            if (!pw)
                return 0
            if (pw.vertical)
                return pw.popupX(0, 0, popup.implicitWidth, popup.implicitHeight)
            const wanted = root.dropdownCenterX - popup.implicitWidth / 2
            const maxX = pw.width - popup.implicitWidth - 8
            return Math.max(8, Math.min(wanted, maxX))
        }
        anchor.rect.y: {
            const pw = root.parentWindow
            if (!pw)
                return 0
            if (!pw.vertical)
                return pw.popupY(0, 0, popup.implicitWidth, popup.implicitHeight)
            return Math.max(8, Math.min(root.dropdownCenterY - (20 + root.dropPadT - root.gapTop) * root.uiScale,
                                        pw.height - popup.implicitHeight - 8))
        }
        anchor.gravity: root.parentWindow ? root.parentWindow.popupGravity : (Edges.Bottom | Edges.Right)

        onVisibleChanged: console.log("[tray] popup " + (visible ? "shown" : "hidden"))

        implicitWidth: Math.max(1, Math.ceil((root.windowW + root.dropPadL + root.dropPadR) * root.uiScale))
        implicitHeight: Math.max(1, Math.ceil(content.implicitHeight * root.uiScale))
        color: "transparent"

        ScaleHost {
            anchors.fill: parent
            factor: root.uiScale
            enabled: root.open

            Item {
                id: content

                // Grows out of the bar's edge from nothing and shrinks all the way
                // back into it (no fade to hide the end), like the other popups.
                // The point it grows out of and shrinks into is the middle of the tray
                // button, outside the window: the whole capsule goes into the pill
                // (and so no piece is left to fade). It fades in a touch, never out.
                opacity: root.open ? Math.min(1, root.dropReveal * 8) : 1
                transform: Scale {
                    origin.x: (root.dropdownCenterX - root.windowLeft(popup)) / root.uiScale
                    origin.y: (root.dropdownCenterY - root.windowTop(popup)) / root.uiScale
                    xScale: Math.max(0, root.dropReveal)
                    yScale: Math.max(0, root.dropReveal)
                }

                implicitHeight: root.dropPadT + capsule.height + root.dropPadB

                width: root.windowW + root.dropPadL + root.dropPadR
                height: implicitHeight

                TrayCollection {
                    id: capsule
                    capRim: root.capsuleStyle
                    visible: root.open || root.dropReveal > 0.001
                    animated: root.capsuleLive
                    x: root.dropPadL + (root.parentWindow && root.parentWindow.vertical
                        ? (root.barEdge === "right" ? root.windowW - width : 0)
                        : (root.windowW - width) / 2)
                    y: root.dropPadT
                    width: shownWidth
                    model: root.source ? root.source.unpinnedItems : []
                    activeItem: root.menuItem
                    leavingItem: root.leavingItem
                    onItemClicked: (item, button, icon) => root.handleClick(item, button, icon, true)
                    onItemScrolled: (item, delta, horizontal) => root.handleScroll(item, delta, horizontal)
                    scrollEnabled: SettingsService.flag("tray.scroll")
                }
            }
        }
    }

    // The right-click menu. Its own window, mapped once the entries are
    // in (menuReady), centered under the tray button / pinned icon it
    // belongs to. Same width whatever the menu holds, so the card sits in
    // the middle of it and the window never has to widen.
    PopupWindow {
        id: menuPopup

        visible: (root.menuReady || root.menuLeaving) && root.menuItem !== null && root.parentWindow !== null

        readonly property real lead: root.menuOnly
            ? root.gapTop
            : root.gapTop + capsule.height + root.gapBetween

        anchor.window: root.parentWindow
        anchor.rect.x: {
            const pw = root.parentWindow
            if (!pw)
                return 0
            if (pw.vertical)
                return pw.popupX(0, 0, menuPopup.implicitWidth, menuPopup.implicitHeight)
            const cx = root.menuOnly ? root.pinnedIconX : root.dropdownCenterX
            const maxX = pw.width - menuPopup.implicitWidth - 8
            return Math.max(8, Math.min(cx - menuPopup.implicitWidth / 2, maxX))
        }
        anchor.rect.y: {
            const pw = root.parentWindow
            if (!pw)
                return 0
            const lead = menuPopup.lead * root.uiScale
            if (!pw.vertical) {
                const base = pw.popupY(0, 0, menuPopup.implicitWidth, menuPopup.implicitHeight)
                return pw.barPosition === "bottom" ? base - lead : base + lead
            }
            const cy = root.menuOnly ? root.pinnedIconY : root.dropdownCenterY
            return Math.max(8, Math.min(cy - (20 + root.menuPadT) * root.uiScale + lead,
                                        pw.height - menuPopup.implicitHeight - 8))
        }
        anchor.gravity: root.parentWindow ? root.parentWindow.popupGravity : (Edges.Bottom | Edges.Right)

        onVisibleChanged: console.log("[tray] menu popup " + (visible ? "shown" : "hidden")
            + (visible ? " " + implicitWidth + "x" + implicitHeight : ""))

        implicitWidth: Math.max(1, Math.ceil((menuCard.maxWidth + root.menuPadL + root.menuPadR) * root.uiScale))
        implicitHeight: Math.max(1, Math.ceil((menuCard.height + root.menuPadT + root.menuPadB) * root.uiScale))
        color: "transparent"

        ScaleHost {
            anchors.fill: parent
            factor: root.uiScale

            TrayMenu {
                id: menuCard

                capRim: root.capsuleStyle
                roundness: root.parentWindow && root.parentWindow.barRoundness !== undefined
                    ? root.parentWindow.barRoundness : 1
                x: root.menuPadL + (root.parentWindow && root.parentWindow.vertical
                    ? (root.barEdge === "right" ? maxWidth - width : 0)
                    : (maxWidth - width) / 2)
                y: root.menuPadT

                originX: ((root.menuOnly ? root.pinnedIconX : root.dropdownCenterX)
                    - root.windowLeft(menuPopup)) / root.uiScale - x
                originY: ((root.menuOnly ? root.pinnedIconY : root.dropdownCenterY)
                    - root.windowTop(menuPopup)) / root.uiScale - y

                onAwayDone: {
                    if (root.menuLeaving)
                        root.finishCloseMenu()
                }

                entries: root.menuEntries
                texel: root.uiScale * Screen.devicePixelRatio
                pinned: root.menuPinned
                showPin: root.menuStack.length === 0
                showBack: root.menuStack.length > 0

                onPinRequested: root.pinWithAnimation(root.menuItem)
                onBackRequested: root.menuStack = root.menuStack.slice(0, -1)
                onSubmenuRequested: entry => root.enterSubmenu(entry)
                onEntryTriggered: entry => root.fireEntry(entry)
            }
        }
    }
}
