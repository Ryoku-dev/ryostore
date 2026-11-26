import QtQuick

// A liquid-glass control surface: buttons, chips, toggles, icon wells.
//
// Self-contained on purpose (no singletons), so every package can carry the
// same file. Put content on top as children; the glass sits underneath.
//
// It refracts whatever the nearest ancestor offers as a backdrop. An ancestor
// opts in by declaring three properties:
//
//     property var glassSource      // a ShaderEffectSource of the backdrop
//     property Item glassSpace      // the item that texture covers
//     property color glassBase      // the surface colour around it
//
// With no backdrop in reach the surface colour stands in, so the glass still
// reads correctly on a plain black island. `flat: true` swaps the shader for
// a cheap solid fill (Settings -> Appearance -> Liquid Glass off).
Item {
    id: root

    default property alias content: holder.data

    property real radius: Math.min(width, height) / 2
    property color tint: "#ffffff"
    property real tintAmount: 0          // 0 = clear glass, 1 = solid tint
    property bool hovered: false
    property bool pressed: false
    property bool flat: false
    property real strength: 1            // scales refraction and rim together
    property real frost: 0.10
    property real blur: 7
    property real shadow: 0.6
    // the nearest ancestor that offers a backdrop (see the header); its
    // properties are bound live, so an owner can switch refraction on and off
    property Item _owner: null
    property color base: _owner && _owner.glassBase !== undefined ? _owner.glassBase : "#000000"
    property var backdrop: _owner && _owner.glassSource ? _owner.glassSource : null
    property Item backdropSpace: _owner ? _owner.glassSpace : null

    readonly property real pad: 6
    // ShaderEffectSource leaves textureSize at (0, 0) when it sizes itself, so
    // fall back to what it covers; the shader divides by this
    readonly property size _texSize: {
        const b = root.backdrop;
        if (!b) return Qt.size(1, 1);
        const t = b.textureSize;
        if (t && t.width > 0 && t.height > 0) return t;
        const it = b.sourceItem || root.backdropSpace;
        const w = it ? it.width : 0, h = it ? it.height : 0;
        return Qt.size(Math.max(1, w), Math.max(1, h));
    }
    readonly property bool live: !flat && glass.status !== ShaderEffect.Error
    property real _light: pressed ? 1 : hovered ? 0.55 : 0
    Behavior on _light { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    function _find() {
        let p = root.parent;
        while (p) {
            if (p.glassSource !== undefined && p.glassSpace !== undefined) { root._owner = p; return; }
            p = p.parent;
        }
        root._owner = null;
    }
    Component.onCompleted: { _find(); _place(); }
    onParentChanged: _find()

    // where this control sits inside the backdrop texture
    property point _origin: Qt.point(0, 0)
    function _place() {
        if (!root.backdrop || !root.backdropSpace || !root.visible) return;
        const pt = root.mapToItem(root.backdropSpace, -root.pad, -root.pad);
        const sx = root.backdropSpace.width > 0 ? root._texSize.width / root.backdropSpace.width : 1;
        const sy = root.backdropSpace.height > 0 ? root._texSize.height / root.backdropSpace.height : 1;
        root._origin = Qt.point(pt.x * (sx || 1), pt.y * (sy || 1));
    }
    onXChanged: _place()
    onYChanged: _place()
    onWidthChanged: _place()
    onHeightChanged: _place()
    onVisibleChanged: _place()
    onBackdropChanged: _place()
    Connections {
        target: root.backdropSpace
        enabled: root.live && root.backdrop !== null
        function onWidthChanged() { root._place(); }
        function onHeightChanged() { root._place(); }
    }

    // a 1x1 stand-in texture for when there is no backdrop to sample
    Rectangle { id: nullRect; width: 1; height: 1; color: "black"; visible: false }
    ShaderEffectSource { id: nullTex; sourceItem: nullRect; hideSource: true; width: 1; height: 1; visible: false }

    ShaderEffect {
        id: glass
        visible: root.live
        anchors.fill: parent
        anchors.margins: -root.pad
        fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb")
        blending: true

        property var src: root.backdrop ? root.backdrop : nullTex
        property size itemSize: Qt.size(width, height)
        property point srcOrigin: root._origin
        property size srcSize: root._texSize
        property color base: root.base
        property color tint: root.tint
        property real pad: root.pad
        property real radius: root.radius
        property real bezel: Math.max(3, Math.min(root.height, root.width) * 0.22)
        property real refraction: 5.5 * root.strength
        property real blur: root.blur
        property real frost: root.frost + 0.03 * root._light
        property real dispersion: 0.35
        property real rim: 0.9 * root.strength
        property real tintAmt: root.tintAmount
        property real hasSrc: root.backdrop ? 1 : 0
        property real light: root._light
        property real shadow: root.shadow
    }

    // cheap stand-in: flat mode, or a GPU without shader support
    Rectangle {
        visible: !root.live
        anchors.fill: parent
        radius: root.radius
        color: Qt.tint(Qt.rgba(1, 1, 1, 0.10 + 0.06 * root._light),
                       Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.tintAmount))
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10 + 0.08 * root._light)
    }

    Item { id: holder; anchors.fill: parent }
}
