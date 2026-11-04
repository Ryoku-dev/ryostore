import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../common"
import "../../../common/functions"
import "../../../common/widgets"
import "../../../../services"

ContentPage {
    id: root

    forceWidth: false

    signal goBack()

    // Which card is expanded, by config key. Empty means all collapsed.
    property string expandedKey: ""

    // Previews need to tick every second regardless of the global secondPrecision
    // option, otherwise the Seconds preview sits frozen while you edit it.
    SystemClock {
        id: previewClock

        precision: SystemClock.Seconds
    }

    component PreviewColumn: ColumnLayout {
        id: previewColumn

        required property string caption
        required property string value
        required property bool emphasized

        spacing: 0

        StyledText {
            text: previewColumn.value
            font.pixelSize: previewColumn.emphasized ? Appearance.font.pixelSize.large : Appearance.font.pixelSize.normal
            color: previewColumn.emphasized ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
        }

        StyledText {
            text: previewColumn.caption
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
    }

    // Inline components don't share scope with the enclosing file, so everything this
    // card needs from the page (clock, expanded state) is passed in explicitly.
    component FormatCard: Rectangle {
        id: card

        required property string label
        required property string cardIcon
        required property string configKey
        required property string defaultValue
        required property string usedIn
        required property date now
        required property bool expanded
        property bool syncsHyprlock: false

        signal toggleRequested()

        readonly property string configValue: Config.options.time[card.configKey] ?? card.defaultValue
        readonly property string draft: input.text.trim()
        readonly property string errorCode: DateUtils.dateTimeFormatError(card.draft)
        readonly property bool valid: card.errorCode.length === 0
        readonly property bool pending: card.valid && card.draft !== card.configValue
        readonly property string savedPreview: Qt.locale().toString(card.now, card.configValue)
        readonly property string draftPreview: card.valid ? Qt.locale().toString(card.now, card.draft) : ""

        function errorMessage(code) {
            if (code === "empty")
                return Translation.tr("Can't be empty.");

            if (code === "unclosedQuote")
                return Translation.tr("Unclosed quote — fixed text needs a quote on each side.");

            if (code === "noFields")
                return Translation.tr("No date or time codes found. Try dd/MM or hh:mm.");

            return "";
        }

        function commit(value) {
            const trimmed = String(value).trim();
            if (!DateUtils.isValidDateTimeFormat(trimmed) || trimmed === card.configValue)
                return;

            if (card.syncsHyprlock)
                DateUtils.syncHyprlockTimeFormat(trimmed);

            Config.options.time[card.configKey] = trimmed;
        }

        function reset() {
            input.text = card.defaultValue;
            card.commit(card.defaultValue);
        }

        // The binding on input.text dies as soon as the user types, so restore it by hand
        // whenever the config changes from elsewhere (e.g. the Clock Format presets).
        onConfigValueChanged: {
            if (!input.activeFocus)
                input.text = card.configValue;
        }

        Layout.fillWidth: true
        implicitHeight: cardColumn.implicitHeight
        radius: Appearance.rounding.normal
        color: card.expanded ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        ColumnLayout {
            id: cardColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            // Collapsed header — always visible, click to expand
            MouseArea {
                Layout.fillWidth: true
                implicitHeight: 60
                cursorShape: Qt.PointingHandCursor
                onClicked: card.toggleRequested()

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    MaterialSymbol {
                        text: card.cardIcon
                        iconSize: Appearance.font.pixelSize.hugeass
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: card.label
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        text: card.savedPreview
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.monospace
                        color: Appearance.colors.colSubtext
                        opacity: card.expanded ? 0 : 1

                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }

                    MaterialSymbol {
                        text: "keyboard_arrow_down"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colSubtext
                        rotation: card.expanded ? 180 : 0

                        Behavior on rotation {
                            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                        }
                    }
                }
            }

            // Expanding body. Content stays loaded so its implicitHeight is always known —
            // a Loader here would make the first expansion jump instead of animate.
            Item {
                Layout.fillWidth: true
                implicitHeight: card.expanded ? body.implicitHeight : 0
                clip: true

                Behavior on implicitHeight {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                ColumnLayout {
                    id: body

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        spacing: 8

                        MaterialTextField {
                            id: input

                            Layout.fillWidth: true
                            placeholderText: card.defaultValue
                            text: card.configValue
                            error: !card.valid
                            font.family: Appearance.font.family.monospace
                            onEditingFinished: card.commit(input.text)
                        }

                        RippleButton {
                            implicitWidth: 40
                            implicitHeight: 40
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colSecondaryContainer
                            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                            colRipple: Appearance.colors.colSecondaryContainerActive
                            enabled: card.draft !== card.defaultValue
                            opacity: enabled ? 1 : 0.4
                            onClicked: card.reset()

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "restart_alt"
                                iconSize: Appearance.font.pixelSize.large
                                color: Appearance.colors.colOnSecondaryContainer
                            }

                            StyledToolTip {
                                text: Translation.tr("Reset to default (%1)").arg(card.defaultValue)
                            }
                        }
                    }

                    // Error hint — replaces the preview while the format is unusable
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        spacing: 6
                        visible: !card.valid

                        MaterialSymbol {
                            text: "error"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colError
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: card.errorMessage(card.errorCode)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colError
                            wrapMode: Text.Wrap
                        }
                    }

                    // Before / after — only while there is an uncommitted change
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        spacing: 14
                        visible: card.pending

                        PreviewColumn {
                            caption: Translation.tr("current")
                            value: card.savedPreview
                            emphasized: false
                        }

                        MaterialSymbol {
                            text: "arrow_forward"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colSubtext
                        }

                        PreviewColumn {
                            caption: Translation.tr("after saving")
                            value: card.draftPreview
                            emphasized: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    // Steady-state preview — shown when there is nothing pending
                    PreviewColumn {
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        visible: card.valid && !card.pending
                        caption: Translation.tr("preview")
                        value: card.savedPreview
                        emphasized: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 16
                        text: Translation.tr("Appears in: %1").arg(card.usedIn)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    RowLayout {
        spacing: 12

        RippleButton {
            implicitWidth: implicitHeight
            implicitHeight: 40
            topLeftRadius: Appearance.rounding.full
            topRightRadius: Appearance.rounding.full
            bottomLeftRadius: Appearance.rounding.full
            bottomRightRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive
            onClicked: root.goBack()

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSecondaryContainer
            }
        }

        StyledText {
            text: Translation.tr("Custom format strings")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }

    ContentSection {
        icon: "edit_calendar"
        title: Translation.tr("Custom format strings")

        TipBox {
            Layout.fillWidth: true
            isFirst: true
            text: Translation.tr("d/dd = day, M/MM = month, yy/yyyy = year, ddd/dddd = weekday, MMM/MMMM = month name, h/hh = hour (12h), H/HH = hour (24h), m/mm = minute, s/ss = second, a/A/ap/AP = am/pm.\nWrap fixed text in single quotes, e.g. \"ddd, dd/MM/yyyy 'at' hh:mm ap\".")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            FormatCard {
                label: Translation.tr("Time")
                cardIcon: "schedule"
                configKey: "format"
                defaultValue: "hh:mm"
                syncsHyprlock: true
                usedIn: Translation.tr("bar clock, lock screen, desktop clock widgets, cheatsheet")
                now: previewClock.date
                expanded: root.expandedKey === "format"
                onToggleRequested: root.expandedKey = (root.expandedKey === "format") ? "" : "format"
            }

            FormatCard {
                label: Translation.tr("Seconds")
                cardIcon: "timer"
                configKey: "secondsFormat"
                defaultValue: "ss"
                usedIn: Translation.tr("bar clock and vertical bar clock, when seconds are shown")
                now: previewClock.date
                expanded: root.expandedKey === "secondsFormat"
                onToggleRequested: root.expandedKey = (root.expandedKey === "secondsFormat") ? "" : "secondsFormat"
            }

            FormatCard {
                label: Translation.tr("Date (bar & widgets)")
                cardIcon: "calendar_month"
                configKey: "dateFormat"
                defaultValue: "dd/MM, ddd"
                usedIn: Translation.tr("bar clock date, desktop digital clock")
                now: previewClock.date
                expanded: root.expandedKey === "dateFormat"
                onToggleRequested: root.expandedKey = (root.expandedKey === "dateFormat") ? "" : "dateFormat"
            }

            FormatCard {
                label: Translation.tr("Short date")
                cardIcon: "calendar_view_day"
                configKey: "shortDateFormat"
                defaultValue: "dd/MM"
                usedIn: Translation.tr("vertical bar date and clock widgets")
                now: previewClock.date
                expanded: root.expandedKey === "shortDateFormat"
                onToggleRequested: root.expandedKey = (root.expandedKey === "shortDateFormat") ? "" : "shortDateFormat"
            }

            FormatCard {
                label: Translation.tr("Date with year")
                cardIcon: "event"
                configKey: "dateWithYearFormat"
                defaultValue: "dd/MM/yyyy"
                usedIn: Translation.tr("Waffle bar clock, weather refresh timestamp")
                now: previewClock.date
                expanded: root.expandedKey === "dateWithYearFormat"
                onToggleRequested: root.expandedKey = (root.expandedKey === "dateWithYearFormat") ? "" : "dateWithYearFormat"
            }
        }
    }
}
