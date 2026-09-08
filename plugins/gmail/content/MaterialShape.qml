import QtQuick

Rectangle {
    id: root
    enum Shape {
        Circle, Square, SoftBurst, Cookie4Sided, Cookie6Sided, Cookie7Sided,
        Cookie9Sided, Cookie12Sided, Pentagon, Pill, Sunny, VerySunny, Oval,
        Clover4Leaf, Clover8Leaf, Burst, Flower, Gem, Heart, Slanted, Arch,
        Fan, Arrow, SemiCircle, Triangle, Diamond, ClamShell
    }
    property int shape: MaterialShape.Shape.Circle
    property real implicitSize: 48
    implicitWidth: implicitSize
    implicitHeight: implicitSize
    radius: (shape === MaterialShape.Shape.Square) ? 8 : (implicitSize / 2)
    antialiasing: true
}
