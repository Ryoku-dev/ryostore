pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../port/components"
import "../../config"
import "../../components"
import "../../services"
LazyListView {
    id: root

    required property Props props
    required property Flickable container
    required property DrawerVisibilities visibilities

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: contentHeight

    spacing: Tokens.spacing.small
    readyDelay: 1
    cacheBuffer: 400
    asynchronous: true

    onViewportAdjustNeeded: d => {
        if (contentYAnim.running)
            contentYAnim.complete();
        contentYAnim.to = Math.max(0, container.contentY + d);
        contentYAnim.start();
    }

    useCustomViewport: true
    viewport: Qt.rect(0, container.contentY, width, container.height)

    removeDuration: Tokens.anim.durations.normal

    model: ScriptModel {
        values: {
            const map = new Map();
            for (const n of Notifs.list.filter(n => !n.closed))
                map.set(n.appName, null);
            for (const n of Notifs.list)
                map.set(n.appName, null);
            return [...map.keys()];
        }
    }

    delegate: Component {
        NotifSwipeDelegate {
            id: notif

            required property int index
            required property string modelData

            width: parent?.width ?? root.width
            implicitWidth: width

            trackViewport: !notifInner.expanded && notifInner.nonAnimHeight < notifInner.implicitHeight
            preferredHeight: notifInner.notifCount === 0 ? 0 : notifInner.nonAnimHeight
            visibleHeight: notifInner.implicitHeight
            implicitHeight: notifInner.implicitHeight

            opacity: removing || notifInner.notifCount === 0 || adding ? 0 : 1
            scale: removing || notifInner.notifCount === 0 ? 0.6 : adding ? 0 : 1

            allowExpandGesture: !notifInner.expanded
            closed: closeAnim.running || notifInner.notifCount === 0

            onExpandRequested: expanded => notifInner.toggleExpand(expanded)
            onCloseRequested: closeAnim.restart()

            ParallelAnimation {
                id: closeAnim

                onFinished: {
                    const appName = notif.modelData;
                    const toClose = Notifs.list.filter(n => !n.closed && n.appName === appName);
                    if (toClose.length === 0)
                        return;
                    Notifs.list = Notifs.list.filter(n => !toClose.includes(n));
                    for (const n of toClose) n.close();
                }

                Anim {
                    type: Anim.DefaultEffects
                    target: notif
                    property: "opacity"
                    to: 0
                }

                Anim {
                    target: notif
                    property: "x"
                    to: notif.x >= 0 ? notif.width : -notif.width
                }
            }

            NotifGroup {
                id: notifInner

                modelData: notif.modelData
                props: root.props
                container: root.container
                visibilities: root.visibilities
            }
        }
    }

    Anim {
        id: contentYAnim

        target: root.container
        property: "contentY"
    }
}
