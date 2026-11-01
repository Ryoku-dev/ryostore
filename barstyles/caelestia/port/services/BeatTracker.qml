import QtQuick

QtObject {
    id: root

    property var provider
    property real bpm: 120
    property var refs: []
    property real floor: 0
    property real previous: 0
    property real lastBeatMs: 0
    property var intervals: []

    signal beat(real bpm)

    function ref(sender: QtObject): void {
        if (!sender || refs.indexOf(sender) >= 0)
            return;
        const wasEmpty = refs.length === 0;
        refs = refs.concat([sender]);
        if (sender.destroyed)
            sender.destroyed.connect(() => root.unref(sender));
        if (wasEmpty)
            provider?.ref(root);
    }

    function unref(sender: QtObject): void {
        const index = refs.indexOf(sender);
        if (index < 0)
            return;
        refs = refs.slice(0, index).concat(refs.slice(index + 1));
        if (!refs.length)
            provider?.unref(root);
    }

    function sample(): void {
        const values = provider?.values || [];
        if (!values.length)
            return;
        const count = Math.max(1, Math.min(values.length, Math.ceil(values.length / 5)));
        let energy = 0;
        for (let index = 0; index < count; index++)
            energy += Number(values[index]) || 0;
        energy /= count;
        floor = floor * 0.94 + energy * 0.06;
        const now = Date.now();
        const rising = energy > previous && energy > Math.max(0.12, floor * 1.55);
        if (rising && now - lastBeatMs >= 240) {
            if (lastBeatMs > 0) {
                const interval = now - lastBeatMs;
                intervals = intervals.concat([interval]).slice(-8);
                const average = intervals.reduce((sum, value) => sum + value, 0) / intervals.length;
                bpm = Math.max(45, Math.min(220, 60000 / average));
            }
            lastBeatMs = now;
            beat(bpm);
        }
        previous = energy;
    }

    property Timer sampler: Timer {
        interval: 33
        repeat: true
        running: root.refs.length > 0
        onTriggered: root.sample()
    }

    Component.onDestruction: provider?.unref(root)
}
