pragma ComponentBehavior: Bound

import QtQuick

// The radial menu's picture: DragShift's radial.py paintEvent in QML. The glass
// is service/shaders/glass.frag; labels are drawn white and recoloured for the
// backdrop by ink.frag, except the hovered slice's label, which stays white like
// radial.py's warm-lit petal. No input handling here: RadialMenu.qml drives it.
Item {
    id: view

    // ---- inputs ------------------------------------------------------------
    property Item backdrop                 // mipmapped texture provider, size x size
    property var items: []                 // [{label, glyph, hint}] of the current ring
    property var ringNames: []
    property int ringIdx: 0
    property int hover: -1                 // slice index, -2 = hub, -1 = none
    property var springs: []               // per-slice hover amount 0..1
    property string hubText: "Drop here"
    property string unsupported: ""        // ".mp3" when nothing can be done
    property real t: 1                     // pop-in 0..1
    property real swap: 1                  // ring swap 0..1

    // radial.py geometry
    readonly property real size: 400
    readonly property real rOut: 158
    readonly property real rIn: 60
    readonly property real rHub: 50
    readonly property real gapDeg: 3.2
    readonly property real corner: 10
    readonly property string family: "Inter"

    // with nothing to show yet, draw empty petals like radial.py's speculative 7
    readonly property int n: items.length > 0 ? items.length : 7

    width: size
    height: size

    function angles(i) {
        const span = 360 / view.n;
        const start = 90 + span / 2 - (i + 1) * span;
        return [start + gapDeg / 2, start + span - gapDeg / 2];
    }
    function spring(i) {
        return i < springs.length ? springs[i] : 0;
    }
    function hv(base) {
        return Qt.vector4d(spring(base), spring(base + 1), spring(base + 2), spring(base + 3));
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: Math.min(1, Math.max(0, view.t * 1.5))
        scale: 0.80 + 0.20 * view.t
        transformOrigin: Item.Center

        ShaderEffect {
            id: glass
            anchors.fill: parent
            visible: !!view.backdrop
            property Item source: view.backdrop
            property vector2d size: Qt.vector2d(view.size, view.size)
            property real n: view.items.length > 0 ? view.items.length : 7
            property real rIn: view.rIn
            property real rOut: view.rOut
            property real rHub: view.rHub
            property real gapDeg: view.gapDeg
            property real corner: view.corner
            property vector4d hov0: view.hv(0)
            property vector4d hov1: view.hv(4)
            property vector4d hov2: view.hv(8)
            property real erase: 60
            fragmentShader: Qt.resolvedUrl("shaders/glass.frag.qsb")
        }

        // ---- labels that follow the backdrop (dark on light, white on dark)
        Item {
            id: inked
            anchors.fill: parent
            layer.enabled: true
            layer.effect: ShaderEffect {
                property vector2d size: Qt.vector2d(view.size, view.size)
                property Item backdrop: view.backdrop
                fragmentShader: Qt.resolvedUrl("shaders/ink.frag.qsb")
            }
            Labels { lit: false }
            Hub { }
        }
        // ---- the hovered slice's label: always white, with a soft shadow
        Item {
            anchors.fill: parent
            Labels { lit: true }
        }
    }

    component Labels: Item {
        id: labels
        property bool lit: false
        anchors.fill: parent
        opacity: 0.25 + 0.75 * view.swap
        Repeater {
            model: view.items
            delegate: Item {
                id: slot
                required property var modelData
                required property int index
                readonly property real h: view.spring(slot.index)
                readonly property var a: view.angles(slot.index)
                readonly property real ang: (a[0] + a[1]) / 2 + (1 - view.swap) * -22
                readonly property real r: (view.rIn + view.rOut) / 2 + slot.h * 4 + 6 * slot.h
                readonly property real px: view.size / 2 + slot.r * Math.cos(ang * Math.PI / 180)
                readonly property real py: view.size / 2 - slot.r * Math.sin(ang * Math.PI / 180)
                // each label is drawn in exactly one of the two layers
                visible: labels.lit === (slot.h > 0.5)

                Text {   // glyph (Tools ring)
                    visible: !!slot.modelData.glyph
                    x: slot.px - 30
                    y: slot.py - 24
                    width: 60
                    height: 24
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignBottom
                    text: slot.modelData.glyph || ""
                    color: "white"
                    style: labels.lit ? Text.Raised : Text.Normal
                    styleColor: Qt.rgba(0, 0, 0, 0.43)
                    font.family: view.family
                    font.pixelSize: Math.round(18 + 3 * slot.h)
                }
                Text {   // label: under the glyph, or alone and larger
                    readonly property bool withGlyph: !!slot.modelData.glyph
                    x: slot.px - 42
                    y: withGlyph ? slot.py + 1 : slot.py - 12
                    width: 84
                    height: withGlyph ? 16 : 24
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: withGlyph ? String(slot.modelData.label).toUpperCase() : slot.modelData.label
                    color: "white"
                    style: labels.lit ? Text.Raised : Text.Normal
                    styleColor: Qt.rgba(0, 0, 0, 0.43)
                    font.family: view.family
                    font.bold: true
                    font.pixelSize: withGlyph ? 10 : Math.round(14 + 2 * slot.h)
                    font.letterSpacing: withGlyph ? 0.7 : 0.9
                    elide: Text.ElideRight
                }
            }
        }
    }

    component Hub: Item {
        anchors.fill: parent
        readonly property var hov: (view.hover >= 0 && view.hover < view.items.length) ? view.items[view.hover] : null
        readonly property string topText: hov ? (hov.glyph ? titled(hov.label) : hov.label) : view.hubText
        // Only the ring you are on, and where it sits: "PAGES · 3/4".
        readonly property string subText: hov ? (hov.hint || "")
            : view.ringNames.length > 1 ? String(view.ringNames[view.ringIdx]).toUpperCase()
                + " · " + (view.ringIdx + 1) + "/" + view.ringNames.length
            : view.ringNames.length === 1 ? String(view.ringNames[0]).toUpperCase() : ""

        function titled(s) {
            return String(s).toLowerCase().replace(/(^|\s)\S/g, c => c.toUpperCase());
        }

        Text {
            x: view.size / 2 - view.rHub + 4
            y: view.size / 2 - 21
            width: 2 * view.rHub - 8
            height: 20
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: parent.topText
            color: "white"
            font.family: view.family
            font.bold: true
            font.pixelSize: 14
            elide: Text.ElideRight
        }
        Text {
            x: view.size / 2 - view.rHub + 6
            y: view.size / 2 + 2
            width: 2 * view.rHub - 12
            height: 28
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: parent.subText
            color: Qt.rgba(1, 1, 1, 0.72)
            font.family: view.family
            font.pixelSize: 10
        }
        // nothing to offer: say so in the top band, clear of the cursor (radial.py)
        Text {
            visible: view.unsupported !== ""
            x: view.size / 2 - view.rOut
            y: view.size / 2 - (view.rIn + view.rOut) / 2 - 18
            width: 2 * view.rOut
            height: 18
            horizontalAlignment: Text.AlignHCenter
            text: "Can't convert " + view.unsupported
            color: "white"
            font.family: view.family
            font.bold: true
            font.pixelSize: 13
        }
        Text {
            visible: view.unsupported !== ""
            x: view.size / 2 - view.rOut
            y: view.size / 2 - (view.rIn + view.rOut) / 2 + 1
            width: 2 * view.rOut
            height: 16
            horizontalAlignment: Text.AlignHCenter
            text: "Images · PDF · Word · Text"
            color: Qt.rgba(1, 1, 1, 0.72)
            font.family: view.family
            font.pixelSize: 10
        }
    }
}
