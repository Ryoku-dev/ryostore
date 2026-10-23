import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Ryoku.Ui.Singletons

// The sheet Tatami spreads over one output: a paper wash across the desktop
// and, set on it, the search line, the section index, the shelf of apps and the
// key legend. It exists only while Tatami is open.
PanelWindow {
    id: sheet

    required property var tatami

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Not "launcher": that namespace gets the compositor's fixed blur. This sheet
    // draws its own, sized by Backdrop frost, and 0 means none.
    WlrLayershell.namespace: "launcher-noblur"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // 0 folded away, 1 laid out. Born folded so the first frame rises in.
    property real reveal: 0
    Behavior on reveal {
        NumberAnimation {
            duration: sheet.tatami.openRequested ? Tokens.dur(420) : Tokens.dur(180)
            easing.type: Easing.OutCubic
        }
    }
    // true while the mats first settle; tiles built after that appear at once
    property bool opening: true
    Timer {
        interval: Tokens.dur(900)
        running: true
        onTriggered: sheet.opening = false
    }
    Component.onCompleted: sheet.reveal = Qt.binding(() => sheet.tatami.openRequested ? 1 : 0)

    // The grid is columns x mat width and the sheet follows from that. On a
    // screen too narrow for it, columns drop and the mats keep their size.
    readonly property int matPx: Tokens.px(Math.max(90, sheet.cfg.matWidth))
    readonly property int availW: sheet.width - Tokens.s7 * 2
    readonly property int cols: Math.max(1, Math.min(Math.max(1, sheet.cfg.columns), Math.floor(sheet.availW / sheet.matPx)))

    readonly property int rows: Math.max(1, Math.floor(shelf.height / shelf.cellHeight))

    function clearQuery() {
        field.text = "";
        sheet.tatami.setQuery("");
    }

    function key(event) {
        const tatami = sheet.tatami;
        switch (event.key) {
        case Qt.Key_Escape:
            if (tatami.query.length > 0)
                sheet.clearQuery();
            else
                tatami.hide();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            tatami.launch(tatami.results[tatami.selected]);
            break;
        case Qt.Key_Left:
            tatami.move(-1);
            break;
        case Qt.Key_Right:
            tatami.move(1);
            break;
        case Qt.Key_Up:
            tatami.move(-shelf.columns);
            break;
        case Qt.Key_Down:
            tatami.move(shelf.columns);
            break;
        case Qt.Key_PageUp:
            tatami.move(-shelf.columns * sheet.rows);
            break;
        case Qt.Key_PageDown:
            tatami.move(shelf.columns * sheet.rows);
            break;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            // a section narrows the whole shelf, so it starts from no query
            sheet.clearQuery();
            tatami.cycleSection(event.key === Qt.Key_Tab ? 1 : -1);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // The desktop as it was when the sheet opened, blurred behind the wash
    // (Settings -> App Launcher -> Backdrop frost). Off at 0.
    readonly property var cfg: sheet.tatami.settings
    readonly property int blurPx: Math.max(0, Math.min(64, sheet.cfg.bgBlur | 0))
    ScreencopyView {
        id: frozen
        anchors.fill: parent
        captureSource: sheet.blurPx > 0 ? sheet.screen : null
        live: false
        onHasContentChanged: if (hasContent) frozenTex.scheduleUpdate()
    }
    ShaderEffectSource {
        id: frozenTex
        anchors.fill: parent
        sourceItem: frozen
        hideSource: true
        live: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: frozenTex
        visible: sheet.blurPx > 0 && frozen.hasContent
        blurEnabled: true
        blurMax: 64
        blur: Math.min(1, sheet.blurPx / 30)
        opacity: sheet.reveal
    }

    Rectangle {
        anchors.fill: parent
        color: Tokens.paper
        opacity: Math.max(0.3, Math.min(1, sheet.cfg.overlayOpacity)) * sheet.reveal
    }

    MouseArea {
        anchors.fill: parent
        onClicked: sheet.tatami.hide()
    }

    Item {
        id: page
        width: Math.min(sheet.availW, Math.max(sheet.cols * sheet.matPx, Tokens.px(760)))
        height: sheet.height - y - Tokens.s6
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(sheet.height * 0.08) + Math.round((1 - sheet.reveal) * Tokens.s3)
        opacity: sheet.reveal

        // a click inside the sheet is not a click away
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: masthead
            width: parent.width
            height: Tokens.s5

            Text {
                id: folio
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "01 \u00b7 " + I18n.tr("APPLICATIONS")
                color: Tokens.inkMuted
                font.family: Tokens.mono
                font.pixelSize: Tokens.fMicro
                font.letterSpacing: Tokens.trackMark
            }
            Rectangle {
                anchors {
                    left: folio.right; leftMargin: Tokens.s3
                    right: seal.left; rightMargin: Tokens.s3
                    verticalCenter: parent.verticalCenter
                }
                height: Tokens.border
                color: Tokens.line
            }
            Text {
                id: seal
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "\u7573"
                color: Tokens.ink
                font.family: Tokens.jp
                font.pixelSize: Tokens.fRow
            }
        }

        Item {
            id: searchLine
            anchors { top: masthead.bottom; topMargin: Tokens.s5; left: parent.left; right: parent.right }
            height: Tokens.px(64)

            TextInput {
                id: field
                anchors {
                    left: parent.left
                    right: tally.left; rightMargin: Tokens.s4
                    verticalCenter: parent.verticalCenter
                }
                focus: true
                color: Tokens.ink
                selectionColor: Tokens.tint16
                selectedTextColor: Tokens.ink
                font.family: Tokens.display
                font.pixelSize: Tokens.px(44)
                clip: true
                Component.onCompleted: field.forceActiveFocus()
                onTextEdited: sheet.tatami.setQuery(text)
                Keys.onPressed: event => sheet.key(event)

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: field.text.length === 0
                    text: I18n.tr("Search applications")
                    color: Tokens.inkFaint
                    font: field.font
                }
            }

            Column {
                id: tally
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    anchors.right: parent.right
                    text: String(sheet.tatami.results.length).padStart(3, "0")
                    color: Tokens.ink
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fRow
                }
                Text {
                    anchors.right: parent.right
                    text: I18n.tr("OF %1").arg(sheet.tatami.shelf.length)
                    color: Tokens.inkFaint
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fTiny
                    font.letterSpacing: Tokens.trackLabel
                }
            }
        }

        Rectangle {
            id: rule
            anchors { top: searchLine.bottom; topMargin: Tokens.s2; left: parent.left; right: parent.right }
            height: Tokens.border
            color: Tokens.lineStrong
        }

        Row {
            id: sectionIndex
            anchors { top: rule.bottom; topMargin: Tokens.s4; left: parent.left }
            spacing: Tokens.s2
            // a query searches every section, so the index steps back while one is typed
            opacity: sheet.tatami.query.length > 0 ? 0.4 : 1
            Behavior on opacity { NumberAnimation { duration: Tokens.snap } }

            Repeater {
                model: sheet.tatami.sections
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool on: sheet.tatami.query.length === 0 && chip.modelData.id === sheet.tatami.section
                    width: chipText.implicitWidth + Tokens.s3 * 2
                    height: Tokens.px(28)
                    radius: Tokens.radius
                    color: chip.on ? Tokens.bone : (chipMouse.containsMouse ? Tokens.tint5 : "transparent")
                    border.width: chip.on ? 0 : Tokens.border
                    border.color: Tokens.line
                    Behavior on color { ColorAnimation { duration: Tokens.snap } }

                    Row {
                        id: chipText
                        anchors.centerIn: parent
                        spacing: Tokens.s1
                        Text {
                            text: I18n.tr(chip.modelData.label).toUpperCase()
                            color: chip.on ? Tokens.inkOnBone : Tokens.inkDim
                            font.family: Tokens.mono
                            font.pixelSize: Tokens.fMicro
                            font.letterSpacing: Tokens.trackLabel
                        }
                        Text {
                            text: String(chip.modelData.count)
                            color: chip.on ? Tokens.inkOnBoneDim : Tokens.inkFaint
                            font.family: Tokens.mono
                            font.pixelSize: Tokens.fTiny
                        }
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sheet.clearQuery();
                            sheet.tatami.pickSection(chip.modelData.id);
                        }
                    }
                }
            }
        }

        GridView {
            id: shelf
            anchors {
                top: sectionIndex.bottom; topMargin: Tokens.s4
                bottom: legend.top; bottomMargin: Tokens.s3
                horizontalCenter: parent.horizontalCenter
            }
            width: sheet.cols * sheet.matPx
            readonly property int columns: sheet.cols
            cellWidth: sheet.matPx
            cellHeight: Tokens.px(128)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: -1
            model: ScriptModel {
                values: sheet.tatami.results
            }

            Connections {
                target: sheet.tatami
                function onSelectedChanged() {
                    shelf.positionViewAtIndex(sheet.tatami.selected, GridView.Contain);
                }
            }

            delegate: Tile {
                id: mat
                required property int index
                required property var modelData
                width: shelf.cellWidth
                height: shelf.cellHeight
                item: mat.modelData
                selected: mat.index === sheet.tatami.selected
                onPointed: sheet.tatami.selected = mat.index
                onActivated: sheet.tatami.launch(mat.modelData)

                // The first screen of mats rises in row by row, 40 ms apart, the
                // way the site's sheets reveal; anything built later just appears.
                property real rise: 1
                opacity: mat.rise
                transform: Translate { y: (1 - mat.rise) * Tokens.s3 }
                Component.onCompleted: {
                    if (!sheet.opening || Tokens.reduceMotion)
                        return;
                    mat.rise = 0;
                    riseIn.start();
                }
                SequentialAnimation {
                    id: riseIn
                    PauseAnimation { duration: Math.max(0, Math.min(6, Math.floor(mat.index / shelf.columns))) * Tokens.dur(40) }
                    NumberAnimation { target: mat; property: "rise"; to: 1; duration: Tokens.dur(420); easing.type: Easing.OutCubic }
                }
            }
        }

        Column {
            anchors.centerIn: shelf
            visible: sheet.tatami.results.length === 0
            spacing: Tokens.s2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("NOTHING ON THE SHELF")
                color: Tokens.inkMuted
                font.family: Tokens.mono
                font.pixelSize: Tokens.fMicro
                font.letterSpacing: Tokens.trackMark
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u201c" + sheet.tatami.query + "\u201d"
                color: Tokens.inkDim
                font.family: Tokens.display
                font.pixelSize: Tokens.px(24)
            }
        }

        Item {
            id: legend
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: Tokens.s6

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: Tokens.border
                color: Tokens.lineSoft
            }
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.s5
                Repeater {
                    model: [
                        ["\u21b5", I18n.tr("OPEN")],
                        ["\u21e5", I18n.tr("SECTION")],
                        ["\u2190\u2191\u2193\u2192", I18n.tr("MOVE")],
                        ["ESC", I18n.tr("CLOSE")]
                    ]
                    delegate: Row {
                        id: hint
                        required property var modelData
                        spacing: Tokens.s1
                        Text {
                            text: hint.modelData[0]
                            color: Tokens.ink
                            font.family: Tokens.mono
                            font.pixelSize: Tokens.fMicro
                        }
                        Text {
                            text: hint.modelData[1]
                            color: Tokens.inkMuted
                            font.family: Tokens.mono
                            font.pixelSize: Tokens.fMicro
                            font.letterSpacing: Tokens.trackLabel
                        }
                    }
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "\u529b"
                color: Tokens.alert
                font.family: Tokens.jp
                font.pixelSize: Tokens.fRow
            }
        }
    }
}
