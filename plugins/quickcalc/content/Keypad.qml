pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

// content/Keypad.qml -- optional on-screen button grid (the "showKeypad"
// setting). Purely additive: every button calls the exact same service
// function a keyboard key would, so the calculator stays fully usable from
// the keyboard alone with this off.
Item {
    id: root
    property var service
    property string mode: "basic"
    property int base: 10

    // Programmer mode: a digit key is live only when it is a digit of the
    // current base (A-F only in HEX, 8/9 not in OCT, 2-9 not in BIN), so the
    // pad can't type something the engine will reject.
    function keyEnabled(k) {
        if (k.l === "") return false;
        if (root.mode !== "programmer" || !k.a || !/^[0-9A-F]$/.test(k.a)) return true;
        return parseInt(k.a, 16) < root.base;
    }

    function keysFor(m) {
        if (m === "programmer") {
            return { cols: 4, keys: [
                {l:"AND",a:"and("}, {l:"OR",a:"or("}, {l:"XOR",a:"xor("}, {l:"NOT",a:"not("},
                {l:"<<",a:"<<"}, {l:">>",a:">>"}, {l:"(",a:"("}, {l:")",a:")"},
                {l:"A",a:"A"}, {l:"B",a:"B"}, {l:"C",a:"C"}, {l:"\u00f7",a:"/"},
                {l:"D",a:"D"}, {l:"E",a:"E"}, {l:"F",a:"F"}, {l:"\u00d7",a:"*"},
                {l:"7",a:"7"}, {l:"8",a:"8"}, {l:"9",a:"9"}, {l:"\u2212",a:"-"},
                {l:"4",a:"4"}, {l:"5",a:"5"}, {l:"6",a:"6"}, {l:"+",a:"+"},
                {l:"1",a:"1"}, {l:"2",a:"2"}, {l:"3",a:"3"}, {l:"=",f:"evaluate"},
                {l:"0",a:"0"}, {l:"CE",f:"clearEntry"}, {l:"\u232b",f:"backspace"}, {l:"AC",f:"clearAll"}
            ] };
        }
        if (m === "scientific") {
            return { cols: 5, keys: [
                {l:"sin",a:"sin("}, {l:"cos",a:"cos("}, {l:"tan",a:"tan("}, {l:"^",a:"^"}, {l:"\u221a",a:"sqrt("},
                {l:"ln",a:"ln("}, {l:"log",a:"log("}, {l:"(",a:"("}, {l:")",a:")"}, {l:"!",a:"!"},
                {l:"\u03c0",a:"pi"}, {l:"e",a:"e"}, {l:"MC",f:"memClear"}, {l:"MR",f:"memRecall"}, {l:"M+",f:"memAdd"},
                {l:"7",a:"7"}, {l:"8",a:"8"}, {l:"9",a:"9"}, {l:"\u00f7",a:"/"}, {l:"CE",f:"clearEntry"},
                {l:"4",a:"4"}, {l:"5",a:"5"}, {l:"6",a:"6"}, {l:"\u00d7",a:"*"}, {l:"\u232b",f:"backspace"},
                {l:"1",a:"1"}, {l:"2",a:"2"}, {l:"3",a:"3"}, {l:"\u2212",a:"-"}, {l:"AC",f:"clearAll"},
                {l:"0",a:"0"}, {l:".",a:"."}, {l:"%",a:"%"}, {l:"+",a:"+"}, {l:"=",f:"evaluate"}
            ] };
        }
        return { cols: 4, keys: [
            {l:"7",a:"7"}, {l:"8",a:"8"}, {l:"9",a:"9"}, {l:"\u00f7",a:"/"},
            {l:"4",a:"4"}, {l:"5",a:"5"}, {l:"6",a:"6"}, {l:"\u00d7",a:"*"},
            {l:"1",a:"1"}, {l:"2",a:"2"}, {l:"3",a:"3"}, {l:"\u2212",a:"-"},
            {l:"0",a:"0"}, {l:".",a:"."}, {l:"\u232b",f:"backspace"}, {l:"+",a:"+"},
            {l:"(",a:"("}, {l:")",a:")"}, {l:"%",a:"%"}, {l:"=",f:"evaluate"},
            {l:"CE",f:"clearEntry"}, {l:"AC",f:"clearAll"}, {l:"",a:null}, {l:"",a:null}
        ] };
    }

    readonly property var spec: keysFor(root.mode)
    // Keys stretch to the width the view gives the pad (falling back to a
    // 42 px key when unsized); height is fixed so the pad stays compact.
    readonly property int gap: 6
    readonly property real cellW: width > 0 ? (width - gap * (spec.cols - 1)) / spec.cols : 42
    readonly property int cellH: 34

    implicitWidth: spec.cols * (42 + gap) - gap
    implicitHeight: Math.ceil(spec.keys.length / spec.cols) * (cellH + gap) - gap

    Grid {
        columns: root.spec.cols
        columnSpacing: root.gap
        rowSpacing: root.gap
        Repeater {
            model: root.spec.keys
            delegate: Rectangle {
                id: key
                required property var modelData
                readonly property bool isBlank: modelData.l === ""
                readonly property bool live: root.keyEnabled(modelData)
                readonly property bool isPrimary: modelData.f === "evaluate"
                property bool down: false
                width: root.cellW
                height: root.cellH
                radius: Theme.radius
                color: isBlank ? "transparent" : (down ? Theme.vermDeep : (isPrimary ? Theme.accent : Theme.tileBg))
                border.width: isBlank ? 0 : Theme.border2
                border.color: Theme.border
                opacity: isBlank || live ? 1 : 0.35
                Text {
                    anchors.centerIn: parent
                    text: key.modelData.l
                    color: key.isPrimary ? Theme.cardBot : Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 13
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: key.live
                    onPressed: key.down = true
                    onReleased: key.down = false
                    onCanceled: key.down = false
                    onClicked: {
                        if (!root.service) return;
                        if (key.modelData.f) root.service[key.modelData.f]();
                        else if (key.modelData.a) root.service.typeToken(key.modelData.a);
                    }
                }
            }
        }
    }
}
