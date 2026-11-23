pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import QtQml
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import Ryoku.Blobs
import Ryoku.Ui.Singletons
import shell.services
import shell.modules.sidebar as Kit

Item {
    id: root

    required property var screen
    property real us: 1
    property bool active: false
    property real availableWidth: 0
    property real availableHeight: 0
    property string placement: "right"
    signal closeRequested()

    readonly property string requestedPage: SidebarState.activeTab(screen)
    readonly property bool pluginsEnabled: SidebarState.elementVisible("pluginCards")
    readonly property string page: requestedPage === "plugins" && !pluginsEnabled
        ? "controls" : requestedPage
    readonly property bool detail: page !== "controls"
    readonly property bool overviewActive: active && !detail
    readonly property bool bottomControlsVisible: SidebarState.visibleSections.some(
        section => section.id === "bottomControls")
    readonly property var scrollSections: SidebarState.visibleSections.filter(
        section => section.id !== "bottomControls")
    readonly property var pluginCards: pluginHost.cards()

    // The vitals block is laid out for the stock panel's 688 px; narrower, its
    // meters elide.
    implicitWidth: Math.max(688 * us, footerBar.implicitWidth + Tokens.s4 * us * 2)
    implicitHeight: Math.max(1, availableHeight)
    clip: true

    onPluginsEnabledChanged: {
        if (!pluginsEnabled && requestedPage === "plugins")
            home();
    }

    function home(): void {
        SidebarState.selectTab(root.screen, "controls");
    }

    function showPage(value): void {
        SidebarState.selectTab(root.screen, value);
    }

    function session(action): void {
        root.closeRequested();
        SessionActions.run(action);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.active
    }

    Kit.SidebarPlugins {
        id: pluginHost
        active: root.active && root.pluginsEnabled
    }

    Rectangle {
        anchors.fill: parent
        color: Tokens.paper
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Tokens.border
        color: Tokens.line
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: (Tokens.s7 * 2 + Tokens.s4) * root.us

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Tokens.border
            color: Tokens.line
        }

        Text {
            id: eyebrow
            anchors.left: parent.left
            anchors.leftMargin: Tokens.s4 * root.us
            anchors.top: parent.top
            anchors.topMargin: Tokens.s3 * root.us
            text: I18n.tr("Byobu")
            color: Tokens.inkMuted
            font.family: Tokens.mono
            font.pixelSize: Tokens.fTiny * root.us
            font.letterSpacing: Tokens.trackMark * root.us
            font.capitalization: Font.AllUppercase
        }

        Text {
            id: weekday
            anchors.left: eyebrow.left
            anchors.bottom: calendarDate.top
            anchors.bottomMargin: Tokens.s1 * root.us
            text: clock.date.toLocaleDateString(TimeFormat.locale, "dddd")
            color: Tokens.ink
            font.family: Tokens.display
            font.pixelSize: Tokens.fHero * root.us
            font.weight: Font.Medium
        }

        Text {
            id: calendarDate
            anchors.left: eyebrow.left
            anchors.right: closeButton.left
            anchors.rightMargin: Tokens.s3 * root.us
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.s3 * root.us
            text: clock.date.toLocaleDateString(TimeFormat.locale, "d MMMM yyyy")
            color: Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: Tokens.fMicro * root.us
            font.letterSpacing: Tokens.trackLabel * root.us
            font.capitalization: Font.AllUppercase
            elide: Text.ElideRight
        }

        Kit.CornerButton {
            id: closeButton
            anchors.right: parent.right
            anchors.rightMargin: Tokens.s4 * root.us
            anchors.top: parent.top
            anchors.topMargin: Tokens.s4 * root.us
            s: root.us
            glyph: "close"
            subtle: true
            Accessible.name: I18n.tr("Close")
            onClicked: root.closeRequested()
        }
    }

    Item {
        id: stage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        clip: true

        Item {
            id: overview
            // These two pages size themselves instead of anchors.fill: with both
            // left and right anchors set, the anchor layout owns x and the slide
            // bindings are discarded, leaving both pages stacked on top of each
            // other (Wi-Fi/Bluetooth text drawn over the overview sections).
            width: parent.width
            height: parent.height
            x: root.detail ? -width : 0

            Behavior on x {
                NumberAnimation {
                    duration: SidebarState.motionDuration(Tokens.swap)
                    easing.type: Tokens.ease
                }
            }

            ByobuFold {
                id: footer
                visible: root.bottomControlsVisible
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Tokens.s4 * root.us
                anchors.rightMargin: Tokens.s4 * root.us
                anchors.bottom: parent.bottom
                height: visible ? implicitHeight : 0
                s: root.us
                label: I18n.tr("Session")

                Kit.ControlsBar {
                    id: footerBar
                    width: parent.width
                    height: implicitHeight
                    s: root.us
                    screen: root.screen
                    active: root.overviewActive
                    onSession: action => root.session(action)
                    onOpenExtensions: root.showPage("plugins")
                    onRequestClose: root.closeRequested()
                }
            }

            QQC.ScrollView {
                id: overviewScroll
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: footer.visible ? footer.top : parent.bottom
                anchors.leftMargin: Tokens.s4 * root.us
                anchors.rightMargin: Tokens.s4 * root.us
                anchors.topMargin: Tokens.s3 * root.us
                anchors.bottomMargin: footer.visible ? Tokens.s3 * root.us : Tokens.s4 * root.us
                clip: true
                contentWidth: availableWidth
                QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff

                Column {
                    id: sections
                    width: overviewScroll.availableWidth
                    spacing: Tokens.s4 * root.us

                    Repeater {
                        model: root.scrollSections

                        delegate: Loader {
                            required property var modelData
                            width: sections.width
                            sourceComponent: modelData.id === "vitals" ? vitalsSection
                                : modelData.id === "connections" ? connectionsSection
                                : modelData.id === "powerProfile" ? profileSection
                                : modelData.id === "media" ? mediaSection
                                : levelsSection
                            height: item ? item.implicitHeight : 0
                        }
                    }
                }
            }
        }

        Item {
            id: detailPage
            width: parent.width
            height: parent.height
            x: root.detail ? 0 : width

            Behavior on x {
                NumberAnimation {
                    duration: SidebarState.motionDuration(Tokens.swap)
                    easing.type: Tokens.ease
                }
            }

            Loader {
                anchors.fill: parent
                anchors.margins: Tokens.s4 * root.us
                active: root.detail
                sourceComponent: root.page === "plugins" ? extensionsPage : controlsPage
            }
        }
    }

    Component {
        id: vitalsSection
        ByobuFold {
            width: sections.width
            s: root.us
            label: I18n.tr("Vitals")
            Kit.ControlsHero {
                width: parent.width
                height: implicitHeight
                s: root.us
                active: root.overviewActive
            }
        }
    }

    Component {
        id: connectionsSection
        ByobuFold {
            width: sections.width
            s: root.us
            label: I18n.tr("Connections")
            Kit.ControlsConnections {
                width: parent.width
                height: implicitHeight
                s: root.us
                screen: root.screen
                active: root.overviewActive
                onOpenPage: page => root.showPage(page)
            }
        }
    }

    Component {
        id: profileSection
        ByobuFold {
            width: sections.width
            s: root.us
            label: I18n.tr("Power")
            Kit.PowerProfileControl {
                width: parent.width
                height: implicitHeight
                s: root.us
                active: root.overviewActive
            }
        }
    }

    Component {
        id: mediaSection
        ByobuFold {
            width: sections.width
            s: root.us
            label: I18n.tr("Media")
            Kit.ControlsMedia {
                width: parent.width
                height: implicitHeight
                s: root.us
                active: root.overviewActive
            }
        }
    }

    Component {
        id: levelsSection
        ByobuFold {
            width: sections.width
            s: root.us
            label: I18n.tr("Levels")
            Kit.ControlsLevels {
                width: parent.width
                height: implicitHeight
                s: root.us
                screen: root.screen
                active: root.overviewActive
            }
        }
    }

    Component {
        id: controlsPage
        Kit.ControlsBoard {
            s: root.us
            screen: root.screen
            active: root.active && root.detail && root.page !== "plugins"
            page: root.page
            onRequestClose: root.closeRequested()
        }
    }

    Component {
        id: extensionsPage
        Item {
            Item {
                id: extensionsHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Tokens.rowH * root.us

                Kit.CornerButton {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.us
                    glyph: "arrow_back"
                    subtle: true
                    Accessible.name: I18n.tr("Back to controls")
                    onClicked: root.home()
                }

                Text {
                    anchors.centerIn: parent
                    text: I18n.tr("Extensions")
                    color: Tokens.ink
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fMicro * root.us
                    font.letterSpacing: Tokens.trackLabel * root.us
                    font.capitalization: Font.AllUppercase
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Tokens.border
                    color: Tokens.lineSoft
                }
            }

            Kit.ExtensionsBoard {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: extensionsHeader.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Tokens.s3 * root.us
                s: root.us
                plugins: root.pluginCards
                active: root.active && root.page === "plugins"
                onRequestClose: root.closeRequested()
            }
        }
    }
}
