import QtQuick
import "Icons.mjs" as Icons
Image {
    property string name: "keyboard"
    property color ink: Theme.ink
    source: Icons.svg[name] ? "data:image/svg+xml," + encodeURIComponent(Icons.svg[name].replace(/currentColor/g, String(ink))) : ""
    sourceSize.width: Math.ceil(width)
    sourceSize.height: Math.ceil(height)
    fillMode: Image.PreserveAspectFit
    smooth: true
    Accessible.ignored: true
}
