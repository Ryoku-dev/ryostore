import QtQuick
import shell.services as ShellServices

// Adapts shell.services AudioBars (40 bands) to CavaProvider's configurable bar count.
QtObject {
    id: root

    property int bars: 0
    property bool hasStreams: false
    property var refs: []
    property bool hasSeenRef: false
    readonly property bool shouldClaim: root.bars > 0
        && (root.hasStreams || ShellServices.Media.playing)
        && (!root.hasSeenRef || root.refs.length > 0)
    readonly property var values: root.computeValues(ShellServices.AudioBars.levels, root.bars)

    function ref(sender: QtObject): void {
        root.hasSeenRef = true;
        if (!sender || root.refs.indexOf(sender) >= 0)
            return;
        if (sender.destroyed)
            sender.destroyed.connect(() => root.unref(sender));
        root.refs = root.refs.concat([sender]);
    }

    function unref(sender: QtObject): void {
        const idx = root.refs.indexOf(sender);
        if (idx >= 0)
            root.refs = root.refs.slice(0, idx).concat(root.refs.slice(idx + 1));
    }

    function computeValues(src: var, count: int): var {
        const n = Math.max(0, count);
        if (n === 0)
            return [];

        const raw = new Array(n);
        const srcLen = src ? src.length : 0;
        if (srcLen === 0) {
            raw.fill(0);
            return raw;
        }

        if (n === 1) {
            raw[0] = Math.max(0, Math.min(1, Number(src[0]) || 0));
        } else {
            for (let i = 0; i < n; ++i) {
                const pos = (i * (srcLen - 1)) / (n - 1);
                const lo = Math.floor(pos);
                const hi = Math.min(srcLen - 1, lo + 1);
                const frac = pos - lo;
                const v = (Number(src[lo]) || 0) * (1 - frac) + (Number(src[hi]) || 0) * frac;
                raw[i] = Math.max(0, Math.min(1, v));
            }
        }

        // Bidirectional neighbour falloff matching the C++ CavaProvider peak spread.
        const inv = 1.0 / 1.5;
        const out = new Array(n);
        let carry = 0;
        for (let i = 0; i < n; ++i) {
            carry = Math.max(raw[i], carry * inv);
            out[i] = carry;
        }
        carry = 0;
        for (let i = n - 1; i >= 0; --i) {
            carry = Math.max(raw[i], carry * inv);
            out[i] = Math.max(out[i], carry);
        }
        return out;
    }

    onShouldClaimChanged: ShellServices.AudioBars.setActive(root, root.shouldClaim)
    Component.onCompleted: ShellServices.AudioBars.setActive(root, root.shouldClaim)
    Component.onDestruction: ShellServices.AudioBars.setActive(root, false)
}
