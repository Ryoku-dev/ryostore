pragma Singleton
pragma ComponentBehavior: Bound

import "../modules/common"
import ".."
import "."
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Ryoku.Ui.Singletons as RyokuUi
import shell.services as HostServices

// Adapter over the host notification service (shell.services Notifs).
Singleton {
    id: root
    component Notif: QtObject {
        id: wrapper
        required property int notificationId // Could just be `id` but it conflicts with the default prop in QtObject
        property Notification notification
        // Internal notifications have no freedesktop sender to keep alive.
        // They still use the same cards/actions/popup path as server traffic.
        property bool internal: false
        property list<var> customActions: []
        property var internalActionPayload: ({})
        property int internalExpireTimeout: -1
        property list<var> actions: {
            var base = notification ? notification.actions.map(function(action) {
                return { "identifier": action.identifier, "text": action.text };
            }) : [];
            if (customActions.length > 0) return base.concat(customActions);
            return base;
        }
        property bool popup: false
        property bool isTransient: notification?.transient ?? false
        property string appIcon: notification?.appIcon ?? ""
        property string appName: notification?.appName ?? ""
        property string body: notification?.body ?? ""
        property string image: notification?.image ?? ""
        property string summary: notification?.summary ?? ""
        property double time
        property string urgency: notification !== null ? String(notification.urgency ?? 1) : "normal"
        property Timer timer
        // Discarding a server notification clears its `notification` property,
        // which normally triggers discardNotification again. Mark the wrapper
        // first so the lifecycle cleanup is one-way and re-entrant safe.
        property bool _releasing: false

        onNotificationChanged: {
            if (notification === null && !internal && !_releasing) {
                root.discardNotification(notificationId);
            }
        }
    }

    component NotifTimer: Timer {
        required property int notificationId
        interval: 7000
        running: true
        onTriggered: () => {
            const notifObject = root.findNotification(notificationId);
            const timer = notifObject?.timer ?? null;
            if (notifObject)
                notifObject.timer = null;
            if (notifObject) {
                if (notifObject.isTransient) root.discardNotification(notificationId);
                else root.timeoutNotification(notificationId);
            }
            if (timer)
                timer.destroy();
            else
                destroy();
        }
    }

    // Shell-owned Do Not Disturb; the host gates its popups and arrival cue
    // with the same flag, so the two stay one switch.
    property bool silent: false
    onSilentChanged: HostServices.Notifs.dnd = silent

    // Any fullscreen window on the focused output, per the host window manager.
    readonly property bool focusedWindowFullscreen:
        RyokuUi.Wm.outputHasFullscreen(RyokuUi.Wm.focusedOutput ?? "")

    readonly property bool autoSilent: (Config?.options.notifications.autoDndFullscreen ?? true) && focusedWindowFullscreen
    readonly property bool effectiveSilent: silent || autoSilent
    property int unread: 0
    // Popups are held back while the sidebar covers the bar.
    property bool popupInhibited: GlobalStates?.sidebarRightOpen ?? false

    // Keep the list typed to the stable Qt base class. A list<Notif> retains the
    // generated QML type revision in its element type; after a hot reload, existing
    // Notif objects then fail assignment to the regenerated Notif type and become
    // null entries ("Cannot append Notif(...) to a QML list").
    property list<QtObject> list: []
    property var _livePopups: []
    // The sidebar covering the bar holds the banners back, exactly as the
    // upstream popups were never armed while it was open.
    readonly property var popupList: root.popupInhibited ? [] : root._livePopups
    property var latestTimeForApp: ({})

    // Server-notification wrappers by id, kept across rebuilds so a card on
    // screen is never replaced under its own animation.
    property var _serverWrappers: ({})
    property var _internalList: []
    // Popup ids already counted into `unread`, so the host's
    // dedup-then-front (same id moved to the top) never counts twice.
    property var _countedPopupIds: ({})

    function findNotification(notificationId: int): var {
        const key = String(notificationId);
        return root._serverWrappers[key]
            ?? (root._internalList.find(notif => notif && notif.notificationId === notificationId) ?? null);
    }

    function findTrackedNotification(notificationId: int): var {
        return root.findNotification(notificationId);
    }

    function ensureWrapper(raw) {
        const key = String(raw.id);
        let wrapper = root._serverWrappers[key];
        if (!wrapper) {
            wrapper = notifComponent.createObject(root, {
                "notificationId": raw.id,
                "notification": raw,
                "time": HostServices.Notifs.arrivalMs[raw.id] ?? Date.now(),
            });
            if (!wrapper)
                return null;
            root._serverWrappers[key] = wrapper;
            root._handleShellNotification(wrapper);
        }
        return wrapper;
    }

    function rebuildList() {
        const history = HostServices.Notifs.history ?? [];
        const merged = [];
        for (let i = 0; i < history.length; i++) {
            if (!history[i])
                continue;
            const wrapper = root.ensureWrapper(history[i]);
            if (wrapper)
                merged.push(wrapper);
        }
        for (let j = 0; j < root._internalList.length; j++)
            merged.push(root._internalList[j]);
        merged.sort((a, b) => b.time - a.time);
        root.list = merged;

        // Update latest time for each app reactively via reassignment
        const nextLatestTime = Object.assign({}, root.latestTimeForApp);
        merged.forEach((notif) => {
            if (!notif) return;
            if (!nextLatestTime[notif.appName] || notif.time > nextLatestTime[notif.appName]) {
                nextLatestTime[notif.appName] = Math.max(nextLatestTime[notif.appName] || 0, notif.time);
            }
        });
        Object.keys(nextLatestTime).forEach((appName) => {
            if (!merged.some((notif) => notif && notif.appName === appName)) {
                delete nextLatestTime[appName];
            }
        });
        root.latestTimeForApp = nextLatestTime;

        // Release wrappers for notifications the host no longer tracks.
        const alive = {};
        merged.forEach((notif) => {
            if (notif && !notif.internal)
                alive[String(notif.notificationId)] = true;
        });
        for (const id in root._serverWrappers) {
            if (!alive[id]) {
                const gone = root._serverWrappers[id];
                delete root._serverWrappers[id];
                root.releaseNotificationObject(gone);
            }
        }
    }

    function rebuildPopups() {
        const popups = HostServices.Notifs.popups ?? [];
        const out = [];
        for (let i = 0; i < popups.length; i++) {
            if (!popups[i])
                continue;
            const wrapper = root.ensureWrapper(popups[i]);
            if (!wrapper)
                continue;
            wrapper.popup = true;
            out.push(wrapper);
            // Count each popup once, no matter how often the host re-fronts it.
            const key = String(popups[i].id);
            if (!(key in root._countedPopupIds)) {
                root._countedPopupIds[key] = true;
                root.unread++;
            }
        }
        for (let j = 0; j < root._internalList.length; j++) {
            if (root._internalList[j].popup)
                out.push(root._internalList[j]);
        }
        root._livePopups = out;
        for (const id in root._serverWrappers) {
            const wrapper = root._serverWrappers[id];
            if (wrapper.popup && out.indexOf(wrapper) === -1)
                wrapper.popup = false;
        }
    }

    function releaseNotificationObject(notifObject) {
        if (!notifObject || notifObject._releasing)
            return;

        notifObject._releasing = true;
        const timer = notifObject.timer;
        notifObject.timer = null;
        if (timer) {
            timer.stop();
            timer.destroy();
        }

        // Drop the server-side QObject/image reference before destroying the
        // wrapper. The guard above prevents this assignment from recursively
        // entering discardNotification.
        notifObject.notification = null;
        notifObject.customActions = [];
        notifObject.internalActionPayload = ({});
        // Destroy on the next event-loop turn: Repeater releases pooled
        // delegates deferred, and binding re-evaluation against a wrapper
        // destroyed in this same tick logs "assign [undefined]" per property.
        Qt.callLater(() => notifObject.destroy());
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => {
            // Sort by time, descending
            return groups[b].time - groups[a].time;
        });
    }

    function groupsForList(list) {
        const groups = {};
        list.forEach((notif) => {
            if (!notif) return;
            if (!String(notif.summary || "").trim() && !String(notif.body || "").trim()) {
                return;
            }
            if (!groups[notif.appName]) {
                groups[notif.appName] = {
                    appName: notif.appName,
                    appIcon: notif.appIcon,
                    notifications: [],
                    time: 0
                };
            }
            groups[notif.appName].notifications.push(notif);
            // Always set to the latest time in the group
            groups[notif.appName].time = latestTimeForApp[notif.appName] || notif.time;
        });
        return groups;
    }

    // Computed group bindings - automatically cached by the QML engine and re-evaluated reactively.
    property var groupsByAppName: groupsForList(root.list)
    property var popupGroupsByAppName: groupsForList(root.popupList)
    property list<string> appNameList: appNameListForGroups(root.groupsByAppName)
    property list<string> popupAppNameList: appNameListForGroups(root.popupGroupsByAppName)

    function appSoundsMuted(appName) {
        const conf = Config.options?.sounds;
        if (!conf) return false;
        const lower = (appName || "").toLowerCase();
        const neverApps = conf.neverPlayApps ?? [];
        return neverApps.some(app => app.toLowerCase() === lower);
    }

    function toggleAppSoundMute(appName) {
        if (!appName) return;
        const conf = Config.options?.sounds;
        if (!conf) return;
        const lower = appName.toLowerCase();
        const neverApps = conf.neverPlayApps ?? [];
        const alwaysApps = conf.alwaysPlayApps ?? [];
        if (root.appSoundsMuted(appName)) {
            conf.neverPlayApps = neverApps.filter(app => app.toLowerCase() !== lower);
        } else {
            conf.alwaysPlayApps = alwaysApps.filter(app => app.toLowerCase() !== lower);
            conf.neverPlayApps = [...neverApps, appName];
        }
    }

    signal notify(notification: var);
    signal discard(id: int);
    signal discardAll();
    signal timeout(id: var);
    // The sender of an internal notification is this process, so custom action
    // identifiers come back here rather than trying to call a dead notify-send.
    signal internalActionInvoked(string identifier, int notificationId, var payload);

    function nextInternalNotificationId(): int {
        let candidate = -1;
        const used = new Set(Object.keys(root._serverWrappers).map(id => Number(id))
            .concat(root._internalList.filter(notif => notif).map(notif => Number(notif.notificationId))));
        while (used.has(candidate))
            candidate--;
        return candidate;
    }

    function armNotificationTimeout(notifObject) {
        if (root.popupInhibited)
            return;
        const expireTimeout = notifObject.internalExpireTimeout;
        if (expireTimeout === 0)
            return;
        const interval = expireTimeout < 0
            ? (Config?.options.notifications.timeout ?? 7000)
            : expireTimeout;
        notifObject.popup = true;
        if (notifObject.timer) {
            notifObject.timer.interval = interval;
            notifObject.timer.restart();
        } else {
            notifObject.timer = notifTimerComponent.createObject(root, {
                "notificationId": notifObject.notificationId,
                "interval": interval,
            });
        }
    }

    /**
     * Adds a shell-owned notification without spawning notify-send. Actions
     * are regular `customActions`, so every notification surface dispatches
     * them through executeShellAction and the caller receives one signal.
     */
    function publishInternalNotification(options: var): var {
        if (root.effectiveSilent)
            return null;
        const notificationId = root.nextInternalNotificationId();
        const appName = String(options?.appName ?? "Quickshell");
        const notifObject = notifComponent.createObject(root, {
            "notificationId": notificationId,
            "internal": true,
            "appName": appName,
            "appIcon": String(options?.appIcon ?? ""),
            "summary": String(options?.summary ?? ""),
            "body": String(options?.body ?? ""),
            "urgency": String(options?.urgency ?? "normal"),
            "time": Date.now(),
            "internalExpireTimeout": Number(options?.expireTimeout ?? -1)
        });
        if (!notifObject)
            return null;
        notifObject.customActions = Array.from(options?.actions ?? []).filter(action => {
            return String(action?.identifier ?? "").startsWith("__qs_")
                && String(action?.text ?? "").length > 0;
        });
        notifObject.internalActionPayload = options?.actionPayload ?? ({});
        root._internalList = root._internalList.concat([notifObject]);
        if (!root.popupInhibited) {
            root.armNotificationTimeout(notifObject);
            root.unread++;
        }
        if (options?.sound === true && !root.appSoundsMuted(appName))
            SoundService.playEvent("notifications", ["message-new-instant"]);
        root.notify(notifObject);
        root.rebuildList();
        root.rebuildPopups();
        return notificationId;
    }

    function _discardInternal(notifObject) {
        root._internalList = root._internalList.filter(notif => notif !== notifObject);
        root.releaseNotificationObject(notifObject);
        root.rebuildList();
        root.rebuildPopups();
    }

    function discardNotification(id) {
        const key = String(id);
        const internal = root._internalList.find(notif => notif && notif.notificationId === id);
        if (internal) {
            root._discardInternal(internal);
        }
        const wrapper = root._serverWrappers[key];
        if (wrapper) {
            if (wrapper.notification && typeof wrapper.notification.dismiss === "function") {
                // The host's closed hook drops it from the tracked list and the
                // popups; the rebuild below runs from the change signals.
                wrapper.notification.dismiss();
            } else {
                delete root._serverWrappers[key];
                root.releaseNotificationObject(wrapper);
                root.rebuildList();
                root.rebuildPopups();
            }
        }
        root.discard(id); // Emit signal
    }

    function discardMultipleNotifications(ids) {
        if (!ids || ids.length === 0) return;
        ids.forEach(id => root.discardNotification(id));
    }

    function discardAllNotifications() {
        const internals = root._internalList.slice();
        root._internalList = [];
        internals.forEach(notif => root.releaseNotificationObject(notif));
        // History items first (the host marks them seen), then whatever
        // transient popups are still up - they never entered history.
        HostServices.Notifs.clearAll();
        (HostServices.Notifs.popups ?? []).slice().forEach(raw => {
            if (raw && typeof raw.dismiss === "function")
                raw.dismiss();
        });
        root.rebuildList();
        root.rebuildPopups();
        root.discardAll();
    }

    function cancelTimeout(id) {
        const wrapper = root.findNotification(id);
        if (wrapper && wrapper.internal) {
            // The timer is gone once it has fired.
            wrapper.timer?.stop();
        } else {
            HostServices.Notifs.cancelPopupTimeout(id);
        }
    }

    function timeoutNotification(id) {
        const wrapper = root.findNotification(id);
        if (!wrapper)
            return;
        if (wrapper.internal) {
            wrapper.popup = false;
        } else if (wrapper.notification) {
            HostServices.Notifs.removePopup(wrapper.notification);
            wrapper.popup = false;
        }
        root.timeout(id);
    }

    function timeoutAll() {
        root.popupList.forEach((notif) => {
            root.timeoutNotification(notif.notificationId);
        })
    }

    function markAllRead() {
        root.unread = 0;
        root._countedPopupIds = ({});
        HostServices.Notifs.markSeen();
    }

    function attemptInvokeAction(id, notifIdentifier) {
        const tracked = HostServices.Notifs.tracked ?? [];
        const raw = tracked.find(notif => notif && notif.id === id);
        if (raw) {
            const action = (raw.actions ?? []).find(action => action.identifier === notifIdentifier);
            if (action)
                action.invoke();
        }
        root.discardNotification(id);
    }

    // Inject QML-handled action buttons for notifications produced in-process
    // (Actions prefixed with "__qs_" are dispatched through executeShellAction).
    function _handleShellNotification(notifObj) {
        // The battery warns before it suspends the machine, and the countdown is cancellable.
        if (notifObj.notification?.hints?.["x-qs-notif"] === "battery-suspend-warn") {
            notifObj.customActions = [
                { "identifier": "__qs_battery_suspend_now", "text": Translation.tr("Suspend now") },
                { "identifier": "__qs_battery_suspend_cancel", "text": Translation.tr("Stay awake") }
            ];
            return;
        }

        // The "Keep awake" timer warns before it expires and offers to push the deadline out.
        // Matched on a private hint rather than the icon: notify-send's -i doesn't reach appIcon.
        if (notifObj.notification?.hints?.["x-qs-notif"] === "keepawake-warn") {
            notifObj.customActions = [
                { "identifier": "__qs_keepawake_extend", "text": Translation.tr("Extend %1").arg(Idle.formatMinutes(Idle.extendMinutes)) },
                { "identifier": "__qs_keepawake_off", "text": Translation.tr("Stop") }
            ];
            return;
        }
    }

    // Execute a QML-handled notification action (identified by "__qs_" prefix).
    function executeShellAction(notifObj, identifier) {
        if (String(identifier).startsWith("__qs_calendar_") || String(identifier).startsWith("__qs_reminder_")
                || String(identifier).startsWith("__qs_health_")) {
            root.internalActionInvoked(identifier, notifObj?.notificationId ?? 0, notifObj?.internalActionPayload ?? ({}));
            return;
        }
        if (identifier === "__qs_battery_suspend_now") {
            Battery.suspendNow();
            return;
        } else if (identifier === "__qs_battery_suspend_cancel") {
            Battery.cancelAutomaticSuspend(true);
            return;
        }
        if (identifier === "__qs_keepawake_extend") {
            Idle.extendBy(Idle.extendMinutes);
            return;
        } else if (identifier === "__qs_keepawake_off") {
            Idle.toggleInhibit(false);
            return;
        }
    }

    Connections {
        target: HostServices.Notifs
        function onHistoryChanged() {
            root.rebuildList();
        }
        function onPopupsChanged() {
            root.rebuildPopups();
        }
        function onDndChanged() {
            if (root.silent !== HostServices.Notifs.dnd)
                root.silent = HostServices.Notifs.dnd;
        }
    }

    Component {
        id: notifComponent
        Notif {}
    }
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    Component.onCompleted: {
        root.silent = HostServices.Notifs.dnd;
        root.rebuildList();
        root.rebuildPopups();
    }
}
