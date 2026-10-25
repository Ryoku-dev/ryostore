import QtQuick

// The wall clock, in the shape Quickshell's SystemClock gives the shell's
// faces: a date that ticks, read as hours / minutes / seconds. Threshold
// binds to this type by name; here it is a local Timer-driven namesake, so
// the face's code stands unchanged. The root is an Item, not a QtObject:
// a QtObject has no default property to hold the Timer.
Item {
    id: root

    enum Precision { Seconds, Minutes }

    property int precision: 0   // Precision.Seconds

    property date date: new Date()

    readonly property int hours: root.date.getHours()
    readonly property int minutes: root.date.getMinutes()
    readonly property int seconds: root.date.getSeconds()

    Timer {
        interval: root.precision === 0 ? 250 : 1000   // 0 = Precision.Seconds
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.date = new Date()
    }
}
