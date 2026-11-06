pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

// content/CalculatorView.qml -- the complete calculator surface. Mounted
// directly by content/Widget.qml at "full" density (the framePopout
// placement) and by content/Panel.qml (the bar-glyph placement); both pass
// the same pluginApi through, so this never needs to know which one it's in
// except when grabbing focus and when closing itself.
//
// Focus: a bar panel's content is created once at shell startup and just
// toggles visible from then on -- "active" is set exactly once by the host's
// configure callback and never rebound, so Component.onCompleted and
// onActiveChanged below only ever fire once, long before anyone has clicked
// the glyph. pluginApi.panelOpen IS kept live the whole time on that
// placement, so hostPanelOpen below is what actually catches "the panel just
// opened, grab focus now" for that case; the framePopout placement still
// gets active rebound live by its own host, so onActiveChanged still covers it.
//
// Closing: there is no "please close me" signal the host listens for on
// EITHER placement's content. A framePopout closes by re-running the exact
// external command that opened it (`ryoku-shell plugin quickcalc`,
// the same trick the shipped `emoji` plugin uses on itself); a bar panel
// closes through the real, host-provided `pluginApi.closePanel()`. Calling
// the popout trick while hosted in a panel would be a silent no-op AND -- if
// it still marks the key event accepted -- would swallow the Escape press
// that the panel's own host chrome needs to close itself, so closeSelf()
// below picks whichever one actually exists on this pluginApi instead of
// guessing from context.
Item {
    id: root
    anchors.fill: parent
    property var pluginApi
    property bool active: true
    // Set by content/FloatingWindow.qml, which has the service but no
    // pluginApi of its own, and closes itself rather than through a host.
    property var serviceOverride: null
    property var closeHandler: null
    // Plate corner radius. The bar panel is clipped and rounded by the shell;
    // the floating window draws its own rounding to match.
    property real cornerRadius: Theme.radius

    readonly property var service: serviceOverride ? serviceOverride : (pluginApi ? pluginApi.mainInstance : null)
    readonly property string layout: service ? service.layout : "basic"
    readonly property bool showKeypad: service ? service.showKeypad : false

    readonly property bool hostPanelOpen: !!(pluginApi && pluginApi.panelOpen)
    onHostPanelOpenChanged: if (hostPanelOpen) Qt.callLater(function () { if (exprInput) exprInput.forceActiveFocus(); })

    function closeSelf() {
        if (typeof root.closeHandler === "function") root.closeHandler();
        else if (root.pluginApi && typeof root.pluginApi.closePanel === "function") root.pluginApi.closePanel();
        else if (root.service) root.service.close();
    }

    // Run a named service action from a mouse click, then hand the keyboard
    // straight back to the expression field.
    function act(name) {
        if (name === "close") { root.closeSelf(); return; }
        if (name === "clearHistory") { root.requestClearHistory(); exprInput.forceActiveFocus(); return; }
        if (root.service && typeof root.service[name] === "function") root.service[name]();
        exprInput.forceActiveFocus();
    }

    // Wiping the (persisted) history takes two presses of Ctrl+L, or two
    // clicks, within 3 s: the first only arms it and says so, so a stray
    // press can't silently erase the tape.
    property bool clearArmed: false
    Timer { id: disarmTimer; interval: 3000; onTriggered: root.clearArmed = false }
    function requestClearHistory() {
        if (!root.service || root.service.history.length === 0) { root.clearArmed = false; return; }
        if (root.clearArmed) {
            root.clearArmed = false;
            disarmTimer.stop();
            root.service.clearHistory();
        } else {
            root.clearArmed = true;
            disarmTimer.restart();
        }
    }

    // Shortcut panel entries: keys (drawn as keycaps), label, and the action
    // a click performs -- every shortcut doubles as a mouse button.
    readonly property var hints: {
        var h = [
            { keys: ["Enter"], label: "Evaluate", action: "evaluate" },
            { keys: ["\u2191", "\u2193"], label: "History", action: "historyUp" },
            { keys: ["Del"], label: "Clear", action: "clearEntry" },
            { keys: ["\u21e7", "Del"], label: "Clear all", action: "clearAll" },
            { keys: ["Ctrl", "C"], label: "Copy result", action: "copyResult" },
            { keys: ["Ctrl", "\u21e7", "C"], label: "Copy all", action: "copyCalculation" },
            { keys: ["Ctrl", "M"], label: "Next mode", action: "cycleLayout" }
        ];
        if (root.layout === "scientific") h.push({ keys: ["Ctrl", "B"], label: "Deg / Rad", action: "toggleAngleMode" });
        if (root.layout === "programmer") h.push({ keys: ["Ctrl", "B"], label: "Next base", action: "cycleBase" });
        h.push({ keys: ["Ctrl", "L"], label: root.clearArmed ? "Again to clear" : "Clear history", action: "clearHistory" });
        h.push({ keys: ["Ctrl", "K"], label: "Keypad", action: "toggleKeypad" });
        h.push({ keys: ["Ctrl", "H"], label: "Hide shortcuts", action: "toggleHints" });
        h.push({ keys: ["Esc"], label: "Close", action: "close" });
        return h;
    }

    // ---- small building blocks -------------------------------------------

    // One key, drawn as a keycap.
    component Keycap: Rectangle {
        id: cap
        property string label
        implicitWidth: Math.max(capText.implicitWidth + 8, 16)
        implicitHeight: 16
        radius: 3
        color: Theme.tileBg
        border.width: 1
        border.color: Theme.border
        Text {
            id: capText
            anchors.centerIn: parent
            text: cap.label
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: 9
        }
    }

    // A Material Symbols icon button for the header.
    component IconButton: Rectangle {
        id: ib
        property string icon
        property bool on: false
        signal activated()
        implicitWidth: 24
        implicitHeight: 24
        radius: Theme.radius
        color: ibArea.containsMouse ? Theme.tileBg : "transparent"
        Text {
            anchors.centerIn: parent
            text: ib.icon
            font.family: "Material Symbols Rounded"
            renderType: Text.QtRendering
            font.pixelSize: 16
            color: ib.on ? Theme.accent : (ibArea.containsMouse ? Theme.bright : Theme.dim)
        }
        MouseArea {
            id: ibArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.activated()
        }
    }

    // A segmented control: options [{value, label}], the current value, and
    // picked(value) on click.
    component Segmented: Rectangle {
        id: seg
        property var options: []
        property string current
        property int fontSize: 11
        signal picked(string value)
        implicitWidth: segRow.implicitWidth + 4
        implicitHeight: segRow.implicitHeight + 4
        radius: Theme.radius
        color: Theme.tileBg
        border.width: 1
        border.color: Theme.border
        Row {
            id: segRow
            x: 2
            y: 2
            Repeater {
                model: seg.options
                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    readonly property bool sel: seg.current === modelData.value
                    implicitWidth: cellText.implicitWidth + 16
                    implicitHeight: cellText.implicitHeight + 6
                    radius: Theme.radius - 1
                    color: sel ? Theme.accent : (cellArea.containsMouse ? Theme.hair : "transparent")
                    Text {
                        id: cellText
                        anchors.centerIn: parent
                        text: cell.modelData.label
                        color: cell.sel ? Theme.cardBot : (cellArea.containsMouse ? Theme.bright : Theme.dim)
                        font.family: Theme.font
                        font.pixelSize: seg.fontSize
                    }
                    MouseArea {
                        id: cellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.picked(cell.modelData.value)
                    }
                }
            }
        }
    }

    // One shortcut-panel entry: keycaps + label; clickable.
    component HintChip: Rectangle {
        id: chip
        property var keys: []
        property string label
        signal activated()
        implicitHeight: 22
        radius: Theme.radius
        color: chipArea.containsMouse ? Theme.hair : "transparent"
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 4
            spacing: 6
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: chip.keys
                    delegate: Keycap {
                        required property var modelData
                        label: modelData
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chipArea.containsMouse ? Theme.bright : Theme.dim
                font.family: Theme.font
                font.pixelSize: 10
            }
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.activated()
        }
    }

    implicitWidth: 348
    implicitHeight: column.implicitHeight + 24

    onActiveChanged: if (active) Qt.callLater(function () { if (exprInput) exprInput.forceActiveFocus(); })
    Component.onCompleted: exprInput.forceActiveFocus()

    // Solid plate: frameBg alone is a 10% accent tint, so over another
    // window the text was unreadable. An opaque base, with the tint on top.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.cardTop.r, Theme.cardTop.g, Theme.cardTop.b, 1)
        radius: root.cornerRadius
        Rectangle {
            anchors.fill: parent
            color: Theme.frameBg
            border.width: Theme.border2
            border.color: Theme.frameBorder
            radius: root.cornerRadius
        }
    }

    Column {
        id: column
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 10

        // Header: mode switch on the left, view toggles + close on the right.
        Item {
            width: parent.width
            implicitHeight: Math.max(modeSeg.implicitHeight, tools.implicitHeight)
            Segmented {
                id: modeSeg
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                options: [{ value: "basic", label: "Basic" }, { value: "scientific", label: "Scientific" },
                          { value: "programmer", label: "Programmer" }]
                current: root.layout
                onPicked: (value) => { if (root.service) root.service.setLayout(value); exprInput.forceActiveFocus(); }
            }
            Row {
                id: tools
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                IconButton {
                    icon: "dialpad"
                    on: root.showKeypad
                    onActivated: root.act("toggleKeypad")
                }
                IconButton {
                    icon: "keyboard"
                    on: !!(root.service && root.service.showHints)
                    onActivated: root.act("toggleHints")
                }
                IconButton {
                    icon: "close"
                    onActivated: root.act("close")
                }
            }
        }

        // History tape: oldest at top, newest just above the input. It is
        // persisted (service/Main.qml), so it needs its own way out.
        Text {
            visible: historyList.visible
            anchors.right: parent.right
            text: root.clearArmed ? "Click again to clear history" : "Clear history"
            color: root.clearArmed ? Theme.vermBurn : Theme.dim
            font.family: Theme.font
            font.pixelSize: 10
            opacity: 0.7
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.act("clearHistory")
            }
        }
        ListView {
            id: historyList
            width: parent.width
            height: Math.min(contentHeight, 96)
            visible: root.service && root.service.history.length > 0
            clip: true
            model: root.service ? root.service.history : []
            onCountChanged: positionViewAtEnd()
            // Click the expression to edit it again; click the result to
            // insert it into the current expression.
            delegate: Column {
                id: histRow
                required property var modelData
                required property int index
                width: historyList.width
                // Long entries are elided (keeping the end of the
                // expression and the start of the result) so they never run
                // outside the plate.
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    text: histRow.modelData.expr
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.service) { root.service.setExpression(histRow.modelData.expr); exprInput.forceActiveFocus(); }
                    }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: "= " + histRow.modelData.result
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 13
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.service) { root.service.useHistoryResult(histRow.index); exprInput.forceActiveFocus(); }
                    }
                }
            }
        }

        // Display: a real text field (native cursor/selection/paste), plus a
        // live preview / error line underneath.
        Column {
            width: parent.width
            spacing: 2
            TextInput {
                id: exprInput
                width: parent.width
                horizontalAlignment: TextInput.AlignRight
                clip: true // a long expression scrolls inside the field instead of spilling out
                font.family: Theme.mono
                font.pixelSize: 24
                color: root.service && root.service.errorText.length > 0 ? Theme.vermBurn : Theme.bright
                selectByMouse: true
                text: ""
                onTextChanged: if (root.service && text !== root.service.expression) root.service.setExpression(text)
                Connections {
                    target: root.service
                    function onExpressionChanged() {
                        if (root.service && exprInput.text !== root.service.expression) {
                            exprInput.text = root.service.expression;
                            exprInput.cursorPosition = exprInput.text.length;
                        }
                    }
                }
                Keys.onReturnPressed: (event) => {
                    if (root.service) root.service.evaluate();
                    event.accepted = true;
                }
                Keys.onEnterPressed: (event) => {
                    if (root.service) root.service.evaluate();
                    event.accepted = true;
                }
                Keys.onEscapePressed: (event) => { root.closeSelf(); event.accepted = true; }
                Keys.onUpPressed: (event) => { if (root.service) root.service.historyUp(); event.accepted = true; }
                Keys.onDownPressed: (event) => { if (root.service) root.service.historyDown(); event.accepted = true; }
                Keys.onDeletePressed: (event) => {
                    if (root.service) {
                        if (event.modifiers & Qt.ShiftModifier) root.service.clearAll();
                        else root.service.clearEntry();
                    }
                    event.accepted = true;
                }
                Keys.onPressed: (event) => {
                    if (!root.service) return;
                    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    var shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                    if (ctrl && event.key === Qt.Key_C) {
                        if (shift) { root.service.copyCalculation(); event.accepted = true; }
                        else if (exprInput.selectedText.length === 0) { root.service.copyResult(); event.accepted = true; }
                        return;
                    }
                    if (ctrl && event.key === Qt.Key_B) {
                        root.service.toggleSecondary();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && event.key === Qt.Key_K) {
                        root.service.toggleKeypad();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && event.key === Qt.Key_L) {
                        root.requestClearHistory();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && event.key === Qt.Key_H) {
                        root.service.toggleHints();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && event.key === Qt.Key_M) {
                        root.service.cycleLayout();
                        event.accepted = true;
                        return;
                    }
                    // Typing a number/name right after a result starts a new
                    // expression; an operator continues from the result. Not
                    // accepted, so the TextInput still inserts the character.
                    if (!ctrl && !(event.modifiers & Qt.AltModifier) && root.service.justEvaluated
                            && event.text.length === 1 && root.service.startsFresh(event.text)
                            && exprInput.selectedText.length === 0
                            && exprInput.cursorPosition === exprInput.text.length)
                        exprInput.text = "";
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: root.clearArmed ? "Press Ctrl+L again to clear the history"
                    : root.service ? (root.service.errorText.length > 0 ? root.service.errorText : root.service.preview) : ""
                color: root.clearArmed || (root.service && root.service.errorText.length > 0) ? Theme.vermBurn : Theme.dim
                font.family: Theme.font
                font.pixelSize: 13
            }
        }

        // Scientific: angle unit switch (Ctrl+B) + memory badge.
        Row {
            visible: root.layout === "scientific"
            spacing: 8
            Segmented {
                anchors.verticalCenter: parent.verticalCenter
                fontSize: 10
                options: [{ value: "deg", label: "DEG" }, { value: "rad", label: "RAD" }]
                current: root.service ? root.service.angleMode : "deg"
                onPicked: (value) => {
                    if (root.service && root.service.angleMode !== value) root.service.toggleAngleMode();
                    exprInput.forceActiveFocus();
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!(root.service && root.service.hasMemory)
                implicitWidth: memText.implicitWidth + 10
                implicitHeight: memText.implicitHeight + 4
                radius: Theme.radius
                color: Theme.threadBg
                Text {
                    id: memText
                    anchors.centerIn: parent
                    text: "M"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }
        }

        // Programmer mode: the current value in every base at once; the
        // highlighted row is the input/display base. Click a row, or Ctrl+B,
        // to switch.
        Column {
            width: parent.width
            visible: root.layout === "programmer"
            spacing: 1
            Repeater {
                model: [16, 10, 8, 2]
                delegate: Item {
                    id: baseRow
                    required property int modelData
                    readonly property bool current: root.service && root.service.base === modelData
                    readonly property real value: root.service ? (Math.trunc(root.service.currentValue()) | 0) : 0
                    width: parent.width
                    height: baseValue.implicitHeight + 2
                    Text {
                        id: baseLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        text: baseRow.modelData === 16 ? "HEX" : (baseRow.modelData === 10 ? "DEC" : (baseRow.modelData === 8 ? "OCT" : "BIN"))
                        color: baseRow.current ? Theme.accent : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                    Text {
                        id: baseValue
                        anchors.left: baseLabel.right
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        text: {
                            if (!root.service) return "";
                            var str = root.service.formatIn(baseRow.value, baseRow.modelData);
                            if (baseRow.modelData === 2 || baseRow.modelData === 16) return root.service.groupDigits(str, 4);
                            if (baseRow.modelData === 8) return root.service.groupDigits(str, 3);
                            return root.service.thousandsSeparator
                                ? str.replace(/\B(?=(\d{3})+(?!\d))/g, ",") : str;
                        }
                        color: baseRow.current ? Theme.bright : Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.service) { root.service.setBase(baseRow.modelData); exprInput.forceActiveFocus(); }
                    }
                }
            }
        }

        // Keypad (Ctrl+K): rolls in/out. An explicit animated height, not a
        // Loader -- a Loader keeps its last implicit height after unloading,
        // so the window never shrank back.
        Item {
            id: padBox
            width: parent.width
            height: root.showKeypad ? pad.implicitHeight : 0
            visible: height > 0
            clip: true
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Keypad {
                id: pad
                width: parent.width
                height: implicitHeight
                opacity: root.showKeypad ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                service: root.service
                mode: root.layout
                base: root.service ? root.service.activeBase : 10
            }
        }

        // Shortcut panel (Ctrl+H, or the keyboard button): two columns of
        // keycap + label entries, each one also a button. Rolls in/out like
        // the keypad.
        Item {
            id: hintBox
            readonly property bool shown: !!(root.service && root.service.showHints)
            width: parent.width
            height: shown ? hintCol.implicitHeight : 0
            visible: height > 0
            clip: true
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Column {
                id: hintCol
                width: parent.width
                opacity: hintBox.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                spacing: 6
                Rectangle { width: parent.width; height: 1; color: Theme.hair }
                Grid {
                    id: hintGrid
                    width: parent.width
                    columns: 2
                    columnSpacing: 4
                    rowSpacing: 0
                    Repeater {
                        model: root.hints
                        delegate: HintChip {
                            required property var modelData
                            width: (hintGrid.width - hintGrid.columnSpacing) / 2
                            keys: modelData.keys
                            label: modelData.label
                            onActivated: root.act(modelData.action)
                        }
                    }
                }
            }
        }
    }
}
