pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

// content/Label.qml — the card's typography, the plugin's port of Lithic's
// Label: a text role from the type table (family, size, weight, line height)
// with plain-text safety and elision. Roles the card uses: name, title,
// label, detail, proof, caption, mono, monoSm.
Text {
    id: root

    property string typeRole: "body"
    property color ink: Theme.bright
    // counts, proofs and values that change in place keep their width
    property bool numeric: false

    readonly property var token: ({
        name: { family: Theme.font, line: 56, size: 52, weight: 700 },
        title: { family: Theme.display, line: 40, size: 34, weight: 700 },
        body: { family: Theme.font, line: 20, size: 14, weight: 400 },
        proof: { family: Theme.font, line: 21, size: 15, weight: 400 },
        label: { family: Theme.font, line: 16, size: 13, weight: 500 },
        caption: { family: Theme.font, line: 16, size: 12, weight: 400 },
        detail: { family: Theme.font, line: 18, size: 13, weight: 400 },
        mono: { family: Theme.mono, line: 16, size: 10, weight: 400 },
        monoSm: { family: Theme.mono, line: 15, size: 9, weight: 400 }
    })[root.typeRole] || { family: Theme.font, line: 20, size: 14, weight: 400 }

    textFormat: Text.PlainText
    color: root.ink
    font.family: root.token.family
    font.pixelSize: root.token.size
    font.weight: root.token.weight
    font.features: root.numeric ? { "tnum": 1 } : {}
    lineHeightMode: Text.FixedHeight
    lineHeight: root.token.line
    elide: Text.ElideRight
}
