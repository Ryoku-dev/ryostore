import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// The one view the host mounts, at `compact` density on the wallpaper.
//
// The host sets pluginApi, density, s, widthBudget, active and screen: read
// them, never assign. Sizes and font sizes are multiplied by `s` rather than
// applying Item.scale, which would blur the CJK glyphs.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property string phase: service ? service.phase : "init"
    readonly property var card: service ? service.card : null
    readonly property bool isCard: phase === "question" || phase === "revealed"
    readonly property real pad: 16 * root.s

    // Lookup is OFF unless explicitly opened, so the text field does not even
    // exist most of the time.
    property bool lookupOpen: false

    // THE keyboard contract with the host. Desktop.qml:711 reads exactly this
    // property and grabs the wallpaper layer's keyboard (exclusively) while it
    // is true. It is derived from the loaded field's own derived flag, so it
    // is false whenever the field is unloaded - which is the common case.
    readonly property bool editing: !!(lookupLoader.item && lookupLoader.item.editing)

    // the tile losing its host, or the card advancing, closes lookup and so
    // drops the grab
    onActiveChanged: if (!active) root.lookupOpen = false
    onPhaseChanged: if (phase === "init" || phase === "error") root.lookupOpen = false

    // A fixed tile width keeps the wallpaper layout still: the card underneath
    // changes length constantly and the tile must not twitch with it.
    implicitWidth: 300 * root.s
    implicitHeight: col.implicitHeight + root.pad * 2

    function humanGap(seconds) {
        if (seconds <= 0) return "now";
        const m = Math.floor(seconds / 60);
        const sec = Math.floor(seconds % 60);
        if (m < 1)  return sec + "s";
        if (m < 60) return m + "m";
        const h = Math.floor(m / 60);
        if (h < 24) return h + "h " + (m % 60) + "m";
        return Math.round(h / 24) + "d";
    }

    Column {
        id: col
        x: root.pad
        y: root.pad
        width: root.implicitWidth - root.pad * 2
        spacing: 12 * root.s

        // --- masthead ------------------------------------------------------

        Item {
            width: parent.width
            height: eyebrow.implicitHeight

            MicroLabel {
                id: eyebrow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                label: "Kotoba"
                s: root.s
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!root.service && root.service.dueCount > 0
                    text: root.service ? root.service.dueCount + " due" : ""
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 1.2 * root.s
                }

                // Opens the lookup field. Only shown once a dictionary is
                // actually installed, so it never invites a dead end.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!root.service && root.service.dictReady
                    text: root.lookupOpen ? "\u00d7" : "+"
                    color: lookupHover.hovered ? Theme.accent : Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 14 * root.s

                    HoverHandler { id: lookupHover }
                    TapHandler {
                        onTapped: {
                            root.lookupOpen = !root.lookupOpen;
                            if (root.lookupOpen && lookupLoader.item)
                                lookupLoader.item.focusField();
                        }
                    }
                }
            }
        }

        // --- the card, or whatever stands in for it -------------------------

        // The lookup field exists ONLY while lookupOpen. Unloaded, it cannot
        // hold focus, so the keyboard grab is impossible in the resting state.
        Loader {
            id: lookupLoader
            width: parent.width
            active: root.lookupOpen
            visible: active
            source: "LookupField.qml"
            onLoaded: {
                item.s = Qt.binding(() => root.s);
                item.service = Qt.binding(() => root.service);
                item.busy = Qt.binding(() => !!root.service && root.service.lookupBusy);
                item.resultText = Qt.binding(() => root.service ? root.service.lookupResult : "");
                item.errorText = Qt.binding(() => root.service ? root.service.lookupError : "");
                item.canSave = Qt.binding(() => !!root.service
                    && root.service.lookupHits.length > 0
                    && root.service.lookupError === "");
                item.saveRequested.connect(function () {
                    if (root.service)
                        root.service.saveWord(root.service.lookupWord);
                });
                item.submitted.connect(function (word) {
                    if (root.service)
                        root.service.lookup(word);
                });
                item.closed.connect(function () { root.lookupOpen = false; });
                item.focusField();
            }
        }

        Item {
            width: parent.width
            visible: !root.lookupOpen
            height: visible ? Math.max(bodyCard.visible ? bodyCard.implicitHeight : 0,
                                       bodyEmpty.visible ? bodyEmpty.implicitHeight : 0) : 0

            CardFace {
                id: bodyCard
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.isCard && !!root.card
                card: root.card
                revealed: root.phase === "revealed"
                showRomaji: root.service ? root.service.showRomaji : true
                showFurigana: root.service ? root.service.showFurigana : true
                fontScale: root.service ? root.service.fontScale : 1.0
                firstRun: !!root.service && root.service.firstRun
                s: root.s
            }

            EmptyState {
                id: bodyEmpty
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !bodyCard.visible
                phase: root.phase === "waiting" ? "caught-up" : root.phase
                nextDueIn: root.service ? root.service.nextDueIn : 0
                errorText: root.service ? root.service.errorText : ""
                reviewsToday: root.service ? root.service.reviewsToday : 0
                dueCount: root.service ? root.service.dueCount : 0
                nextCardIn: root.service ? root.service.nextCardIn : 0
                onReviewNow: if (root.service) root.service.reviewNow()
                s: root.s
            }
        }

        // --- the one action available in this state -------------------------

        Item {
            width: parent.width
            height: (root.isCard && !root.lookupOpen) ? Math.max(revealBtn.height, grades.implicitHeight) : 0
            visible: root.isCard && !root.lookupOpen

            Rectangle {
                id: revealBtn
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.phase === "question"
                width: 108 * root.s
                height: 28 * root.s
                radius: 8 * root.s
                readonly property color rest: Scheme.role("primaryContainer", Theme.threadBg)
                color: revealHover.containsPress ? Qt.darker(revealBtn.rest, 1.18)
                     : revealHover.hovered       ? Qt.lighter(revealBtn.rest, 1.14)
                                                 : revealBtn.rest
                border.width: 1
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
                scale: revealHover.containsPress ? 0.96 : 1.0
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 110 } }

                Text {
                    anchors.centerIn: parent
                    text: "Reveal"
                    color: Scheme.role("onPrimaryContainer", Theme.bright)
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    font.weight: Font.Medium
                }

                HoverHandler { id: revealHover }
                TapHandler { onTapped: if (root.service) root.service.reveal() }
            }

            GradeRow {
                id: grades
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.phase === "revealed"
                preview: root.card ? root.card.preview : null
                showIntervals: root.service ? root.service.showIntervals : true
                s: root.s
                onGraded: rating => { if (root.service) root.service.grade(rating); }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.phase === "revealed" && !!root.service && root.service.firstRun
            height: visible ? implicitHeight : 0
            text: "how well did you know it?"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.italic: true
        }

        // Dictionary install prompt. The settings schema has no button type,
        // so the one action that uses the network lives here, on the tile,
        // behind an explicit tap - and only once `online` is switched on.
        Rectangle {
            width: parent.width
            visible: !!root.service && root.service.online && !root.service.dictReady
            height: visible ? 28 * root.s : 0
            radius: 8 * root.s
            readonly property color rest: Scheme.role("primaryContainer", Theme.threadBg)
            color: dictHover.containsPress ? Qt.darker(rest, 1.18)
                 : dictHover.hovered       ? Qt.lighter(rest, 1.14)
                                           : rest
            border.width: 1
            border.color: Scheme.line

            Text {
                anchors.centerIn: parent
                text: (root.service && root.service.dictBusy)
                    ? "installing dictionary\u2026"
                    : "install dictionary"
                color: Scheme.role("onPrimaryContainer", Theme.bright)
                font.family: Theme.font
                font.pixelSize: 11 * root.s
            }

            HoverHandler { id: dictHover }
            TapHandler {
                enabled: !!root.service && !root.service.dictBusy
                onTapped: if (root.service) root.service.fetchDict()
            }
        }

        // Undo. With auto-advance on, the next card replaces the last one
        // immediately, so this chip is the only way back to a misclick.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !!root.service && root.service.canUndo
            height: visible ? 22 * root.s : 0
            width: undoLabel.implicitWidth + 20 * root.s
            radius: 6 * root.s
            color: undoHover.containsPress
                ? Qt.darker(Scheme.role("secondaryContainer", Theme.sheen), 1.18)
                : undoHover.hovered
                    ? Scheme.role("secondaryContainer", Theme.sheen)
                    : "transparent"
            border.width: 1
            border.color: undoHover.hovered ? Scheme.line : "transparent"
            Behavior on color { ColorAnimation { duration: 110 } }

            Text {
                id: undoLabel
                anchors.centerIn: parent
                text: "\u21b6  " + (root.service ? root.service.undoLabel : "")
                color: undoHover.hovered ? Theme.bright : Theme.faint
                font.family: Theme.font
                font.pixelSize: 10 * root.s
            }

            HoverHandler { id: undoHover }
            TapHandler { onTapped: if (root.service) root.service.undo() }
        }

        // --- footer: the next-card clock and whatever credit is owed ---------

        Rectangle {
            width: parent.width
            height: 1
            color: Scheme.line
        }

        Item {
            width: parent.width
            height: Math.max(clock.implicitHeight, credit.implicitHeight)

            Text {
                id: clock
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (!root.service) return "";
                    const done = root.service.reviewsToday > 0
                        ? "  \u00b7  " + root.service.reviewsToday + " done today" : "";
                    if (root.phase === "question" || root.phase === "revealed")
                        return (root.service.reason === "new" ? "new word" : "review") + done;
                    return "next in " + root.humanGap(root.service.nextCardIn) + done;
                }
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
                font.letterSpacing: 1.1 * root.s
            }

            Text {
                id: credit
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - clock.implicitWidth - 12 * root.s)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                visible: !!root.service && root.service.attribution.length > 0
                text: root.service ? root.service.attribution : ""
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
            }
        }
    }

    // The whole tile is the reveal target: a flashcard you have to aim at is a
    // flashcard you stop using. Once revealed, only the grade buttons act, so
    // this never grades anything by accident.
    TapHandler {
        enabled: root.phase === "question"
        onTapped: if (root.service) root.service.reveal()
    }
}
