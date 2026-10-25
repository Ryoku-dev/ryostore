pragma Singleton

import QtQuick

// The lock face's timing set, at the shell's own figures (timing.speed 1.0).
// No duration is written anywhere else in the theme.
QtObject {
    id: root

    readonly property int open: 250
    readonly property int close: 150

    // One shape's own growth inside the opening cascade.
    readonly property int grow: 100

    // Delay between consecutive shapes in a staggered entrance.
    readonly property int stagger: 16

    // A state change with no live value behind it.
    readonly property int transition: 180

    // Wallpaper crossfade: the picture is the whole screen, and anything
    // quick here reads as a flicker rather than a change of scene.
    readonly property int wallpaper: 600

    // How long the welcome stays before the screen goes dark.
    readonly property int welcome: 900
    // The welcome's own pace, slower than the shell's: each line opens over
    // `welcomeOpen`, the next starting `welcomeStagger` after it, and the
    // screen darkens over `welcomeFade`.
    readonly property int welcomeOpen: 450
    readonly property int welcomeStagger: 100
    readonly property int welcomeFade: 1000

    // A staggered entrance as a fraction per shape: `cascade` runs 0 to 1
    // over the whole opening, each shape starts one `stagger` after the one
    // before it, and each grows over `grow`. The span depends on how many
    // shapes there are, so whoever draws a cascade passes its length.
    function stage(cascade, index, count) {
        const span = root.grow + root.stagger * Math.max(0, count - 1);
        const started = cascade * span - index * root.stagger;
        return Math.max(0, Math.min(1, started / root.grow));
    }
}
