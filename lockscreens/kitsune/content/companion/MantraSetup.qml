/* MantraSetup.qml — kitsune-mantra's one window.
 *
 * Speak your order by tapping the cards or typing their numbers;
 * both are the same act, as at the door. Sealing hands the result
 * to mantraconf.py, which writes theme.conf at mode 600.
 */
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../gotchi"

Item {
    id: root
    focus: true

    property string confPath: ""
    property string writerPath: ""

    readonly property var _foldIds: ["truth", "power", "wisdom", "judgment", "life", "love", "discipline"]
    readonly property var _foldLabels: ["THE EYE", "THE PHANTOM", "THE BLADE", "THE SAGE", "THE SHROUD", "THE FORGE", "THE MIRROR"]
    readonly property var _foldPrinciples: ["TRUTH", "POWER", "WISDOM", "JUDGMENT", "LIFE", "LOVE", "DISCIPLINE"]
    readonly property var _foldColors: ["#4ade80", "#f43f5e", "#00B4D8", "#9B1FA0", "#818cf8", "#f59e0b", "#6366f1"]
    readonly property color palText: "#e8e6df"
    readonly property color palPrimary: "#3fd9e8"
    readonly property string fontFace: "3270 Nerd Font Mono, Fira Code, monospace"

    property var _order: []
    property bool _touched: false
    property var _standingOrder: []
    property bool _gate: false
    property int _attempts: 3
    property bool _keySet: false
    property string _keyAction: "keep"
    property bool _rehearse: false
    property var _deal: []
    property var _tryEntry: []
    property bool _tryReady: false
    property real _time: 0
    property bool _loaded: false
    property string _status: "reading your current settings…"

    Timer { interval: 50; running: true; repeat: true; onTriggered: root._time += 0.05 }
    Timer { interval: 1500; running: true; repeat: false; onTriggered: if (!root._loaded) root._defaults() }

    function _read() {
        if (!root.confPath || !root.writerPath) return;
        reader.command = ["python3", root.writerPath, root.confPath, "read"];
        reader.running = true;
    }
    onConfPathChanged: root._read()
    onWriterPathChanged: root._read()
    Process {
        id: reader
        stdout: SplitParser { onRead: (line) => root._applyState(line) }
        onExited: (code) => { if (code !== 0 && !root._loaded) root._defaults(); }
    }
    function _applyState(line) {
        try {
            const r = JSON.parse(line);
            root._gate = r.gate;
            root._attempts = r.attempts;
            root._standingOrder = r.order;
            root._keySet = r.keySet;
            root._loaded = true;
            root._status = r.exists ? "your standing settings — speak a new order, or leave the fan be"
                                     : "no settings file yet — the canon order stands as the example";
        } catch (e) { root._defaults(); }
    }
    function _defaults() {
        root._standingOrder = root._foldIds.slice();
        root._loaded = true;
        root._status = "no settings file yet — the canon order stands as the example";
    }

    function _effectiveOrder() {
        if (root._touched && root._order.length === 7) return root._order;
        return root._standingOrder.length === 7 ? root._standingOrder : root._foldIds;
    }
    function _words(ids) {
        return ids.map(id => {
            const i = root._foldIds.indexOf(id);
            return root._foldLabels[i] + " · " + root._foldPrinciples[i];
        }).join("    ");
    }

    function _speakFold(id) {
        if (root._order.indexOf(id) >= 0 || root._order.length >= 7) return;
        root._touched = true;
        root._order = root._order.concat([id]);
        root._status = root._order.length === 7 ? "your order is whole — seal it, or rehearse it first"
                                                 : "spoken · " + root._order.length + " of 7";
    }
    function _unspeak() {
        if (!root._order.length) return;
        root._touched = true;
        root._order = root._order.slice(0, -1);
    }

    function _startRehearsal() {
        root._rehearse = true;
        root._redeal();
        root._status = "practice deals — answer in your order, then invoke with enter · the door keeps her three-strike rule; practice has none";
        root.forceActiveFocus();
    }
    function _redeal() {
        const ids = root._foldIds.slice();
        for (let i = ids.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const t = ids[i]; ids[i] = ids[j]; ids[j] = t;
        }
        root._deal = ids;
        root._tryEntry = [];
        root._tryReady = false;
    }
    function _speakSlot(pos) {
        if (root._tryEntry.indexOf(pos) >= 0 || root._tryEntry.length >= 7) return;
        root._tryEntry = root._tryEntry.concat([pos]);
        if (root._tryEntry.length === 7) {
            root._tryReady = true;
            root._status = "spoken whole — invoke with enter";
        }
    }
    function _trySubmit() {
        if (root._tryEntry.length < 7) { root._status = "the mantra is sevenfold — speak it whole, then invoke"; return; }
        const spoken = root._tryEntry.map(p => root._deal[p - 1]);
        if (spoken.join(",") === root._effectiveOrder().join(",")) {
            root._status = "the door would open · your mantra holds";
            root._tryEntry = [];
            root._tryReady = false;
        } else {
            root._status = "she would redeal — again";
            root._redeal();
        }
    }

    function _seal() {
        if (root._touched && root._order.length < 7) {
            root._status = "your order is sevenfold — speak it whole before sealing, or start over";
            return;
        }
        root._status = "sealing…";
        writer.command = ["python3", root.writerPath, root.confPath];
        writer.running = true;
        sealWatch.restart();
    }
    Timer {
        id: sealWatch
        interval: 4000
        repeat: false
        onTriggered: if (root._status === "sealing…") root._status = "the writer did not answer — nothing was sealed";
    }
    Process {
        id: writer
        stdinEnabled: true
        stdout: SplitParser { onRead: (line) => root._report = line }
        onStarted: {
            const action = pwField.text.length > 0 ? "set" : root._keyAction;
            writer.write(JSON.stringify({
                gate: root._gate, attempts: root._attempts,
                order: root._effectiveOrder(),
                passAction: action, pass: pwField.text }) + "\n");
        }
        onExited: (code) => {
            if (code !== 0) { root._status = "the writer refused — nothing was sealed"; return; }
            try {
                const r = JSON.parse(root._report);
                root._keySet = r.keySet;
                root._standingOrder = r.order;
            } catch (e) {}
            pwField.text = "";
            root._keyAction = "keep";
            root._touched = false;
            root._order = [];
            root._status = "sealed · the door will deal your order" + (root._keySet ? ", and your key is stored" : "");
            root._read();
            root.forceActiveFocus();
        }
    }
    property string _report: ""

    Keys.onPressed: (event) => {
        const d = parseInt(event.text);
        if (pwField.activeFocus) return;
        if (d >= 1 && d <= 7) {
            if (root._rehearse) root._speakSlot(d); else root._speakFold(root._foldIds[d - 1]);
        } else if (event.key === Qt.Key_Backspace) {
            if (root._rehearse) { if (root._tryEntry.length) { root._tryEntry = root._tryEntry.slice(0, -1); root._tryReady = false; } }
            else root._unspeak();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root._rehearse) root._trySubmit(); else root._seal();
        } else if (event.key === Qt.Key_Escape) {
            if (root._rehearse) { root._rehearse = false; root._status = "back to your settings"; }
        } else if (event.text === "g" && !root._rehearse) {
            root._gate = !root._gate;
        } else if ((event.text === "-" || event.text === "+") && !root._rehearse) {
            root._attempts = Math.max(1, Math.min(9, root._attempts + (event.text === "+" ? 1 : -1)));
        } else if (event.text === "p" && !root._rehearse) {
            pwField.forceActiveFocus();
        } else if (event.text === "v" && !root._rehearse) {
            pwField.echoMode = pwField.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password;
        }
    }

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 28
        spacing: 2
        Text {
            text: "KITSUNE — SET YOUR MANTRA"
            color: root.palText
            font.family: root.fontFace
            font.pixelSize: 15
            font.letterSpacing: 3
        }
        Text {
            text: root._status
            color: Qt.alpha(root.palText, 0.6)
            font.family: root.fontFace
            font.pixelSize: 12
        }
    }

    InseiScene {
        id: scene
        anchors.top: parent.top
        anchors.topMargin: 116
        anchors.left: parent.left
        anchors.right: parent.right
        height: 560
        setupMode: true
        layout: root._rehearse
            ? root._deal.map((id, i) => ({ id: id, color: root._foldColors[root._foldIds.indexOf(id)], position: i + 1 }))
            : root._foldIds.map((id, i) => ({ id: id, color: root._foldColors[i], position: i + 1 }))
        tappedFolds: root._rehearse ? root._tryEntry.map(p => root._deal[p - 1]) : root._order
        lockedCount: root._rehearse ? root._tryEntry.length : root._order.length
        sequenceStr: (root._rehearse ? root._tryEntry.map(p => root._deal[p - 1]) : root._order).join(":")
        time: root._time
        whisper: ""
        onCardTapped: function(foldId, position, px, py) {
            if (root._rehearse) root._speakSlot(position); else root._speakFold(foldId);
            root.forceActiveFocus();
        }
    }

    Column {
        anchors.top: scene.bottom
        anchors.topMargin: 48
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        spacing: 12

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: {
                if (root._rehearse) return root._tryEntry.length
                    ? root._words(root._tryEntry.map(p => root._deal[p - 1])) : "—";
                if (root._order.length) return root._words(root._order);
                return "standing order · " + root._words(root._standingOrder);
            }
            color: Qt.alpha(root.palText, 0.8)
            font.family: root.fontFace
            font.pixelSize: 12
        }

        Row {
            visible: !root._rehearse
            spacing: 42
            Row {
                spacing: 10
                Text {
                    text: "mantra gate"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.palText, 0.85)
                    font.family: root.fontFace
                    font.pixelSize: 12
                }
                Rectangle {
                    width: 30; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: root._gate ? Qt.alpha(root.palPrimary, 0.35) : Qt.alpha("#0a0a12", 0.55)
                    border.width: 1
                    border.color: Qt.alpha(root.palText, root._gate ? 0.5 : 0.22)
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        y: 2
                        x: root._gate ? 17 : 3
                        color: root._gate ? root.palPrimary : Qt.alpha(root.palText, 0.45)
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root._gate = !root._gate; root.forceActiveFocus(); } }
                }
                Text {
                    text: root._gate ? "standing" : "down"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.palText, 0.55)
                    font.family: root.fontFace
                    font.pixelSize: 11
                }
            }
            Row {
                spacing: 10
                Text {
                    text: "attempts before stand-down"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.palText, 0.85)
                    font.family: root.fontFace
                    font.pixelSize: 12
                }
                Text {
                    text: "−"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.palText, 0.9)
                    font.family: root.fontFace
                    font.pixelSize: 15
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                onClicked: { root._attempts = Math.max(1, root._attempts - 1); root.forceActiveFocus(); } }
                }
                Text {
                    text: root._attempts
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.palText
                    font.family: root.fontFace
                    font.pixelSize: 12
                }
                Text {
                    text: "+"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.palText, 0.9)
                    font.family: root.fontFace
                    font.pixelSize: 15
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                onClicked: { root._attempts = Math.min(9, root._attempts + 1); root.forceActiveFocus(); } }
                }
            }
        }

        Row {
            visible: !root._rehearse
            spacing: 12
            Text {
                text: "stored key"
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(root.palText, 0.85)
                font.family: root.fontFace
                font.pixelSize: 12
            }
            TextField {
                id: pwField
                objectName: "pwField"
                width: 260
                placeholderText: "your account password"
                echoMode: TextInput.Password
                color: root.palText
                font.family: root.fontFace
                font.pixelSize: 12
                background: Rectangle { color: Qt.alpha("#ffffff", 0.05); radius: 8; border.width: 1; border.color: Qt.alpha(root.palText, 0.18) }
                onAccepted: root._seal()
                Keys.onPressed: (event) => { if (event.key === Qt.Key_Escape) root.forceActiveFocus(); }
            }
            Text {
                text: pwField.echoMode === TextInput.Password ? "show" : "hide"
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(root.palText, 0.6)
                font.family: root.fontFace
                font.pixelSize: 11
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                            onClicked: { pwField.echoMode = pwField.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password; root.forceActiveFocus(); } }
            }
            Text {
                visible: root._keySet && root._keyAction !== "clear"
                text: "remove key"
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(root.palText, 0.6)
                font.family: root.fontFace
                font.pixelSize: 11
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                            onClicked: { root._keyAction = "clear"; pwField.text = ""; root._status = "the stored key will be removed when you seal"; root.forceActiveFocus(); } }
            }
        }

        Text {
            visible: !root._rehearse
            text: root._keySet
                ? (root._keyAction === "clear" ? "the stored key will be removed on seal"
                                               : "a key is stored — entering a password replaces it; the key is your password in plain text, in a file only you can read")
                : "no key stored — without one, a right sequence opens the password field"
            color: Qt.alpha(root.palText, 0.55)
            font.family: root.fontFace
            font.pixelSize: 11
        }

        Row {
            visible: !root._rehearse
            spacing: 26
            Text {
                text: "start over"
                color: Qt.alpha(root.palText, 0.6)
                font.family: root.fontFace
                font.pixelSize: 12
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                            onClicked: { root._order = []; root._touched = true; root._status = "speak your order anew"; root.forceActiveFocus(); } }
            }
            Text {
                text: "try your mantra"
                color: Qt.alpha(root.palText, 0.85)
                font.family: root.fontFace
                font.pixelSize: 12
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                            onClicked: root._startRehearsal() }
            }
            Text {
                text: "seal it"
                color: root.palPrimary
                font.family: root.fontFace
                font.pixelSize: 12
                font.letterSpacing: 1.5
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                            onClicked: root._seal() }
            }
        }

        Text {
            visible: !root._rehearse
            text: "keys · 1–7 speak · backspace un-speak · g gate · − + attempts · p password · v show · enter seal"
            color: Qt.alpha(root.palText, 0.4)
            font.family: root.fontFace
            font.pixelSize: 11
        }

        Row {
            visible: root._rehearse
            spacing: 26
            Text {
                text: "esc — back to your settings"
                color: Qt.alpha(root.palText, 0.6)
                font.family: root.fontFace
                font.pixelSize: 12
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                            onClicked: root._rehearse = false }
            }
            Text {
                text: "keys · 1–7 answer · backspace un-speak · enter invoke"
                color: Qt.alpha(root.palText, 0.4)
                font.family: root.fontFace
                font.pixelSize: 11
            }
        }
    }
}
