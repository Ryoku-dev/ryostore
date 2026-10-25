import QtQuick

// One screen's share of the wallpaper: which part of the picture it shows,
// and how the picture is fitted.
//
// In the shell this component also cuts a `span` picture into per-screen
// slices (that half reads Quickshell's screen list and shells out to
// ImageMagick for the picture's size). A greeter shows one screen its own
// picture whole, so the port keeps the interface — source, mode, screen,
// density, status — and the fill / fit behaviour, and treats `span` as
// `fill`. The item fills its parent.
Item {
    id: root

    property string source: ""
    property string mode: "fill"
    property var screen: null

    // Decode at a fraction of the size shown. A picture that is going to be
    // blurred needs a quarter of its pixels, and the smooth upscale is the
    // first half of the blur.
    property real density: 1

    readonly property alias status: image.status

    anchors.fill: parent

    readonly property real decodeScale: (root.screen?.devicePixelRatio ?? 1) * root.density

    Image {
        id: image

        anchors.fill: parent

        source: {
            if (root.source.length === 0)
                return "";
            if (root.source.startsWith("file://") || root.source.startsWith("http"))
                return root.source;
            return "file://" + root.source;
        }
        // The box is covered, never stretched.
        fillMode: root.mode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true

        // Decode at the size actually needed: a 6000 px photograph on a
        // 1920 px monitor otherwise costs its full decoded size in memory.
        sourceSize.width: Math.round(width * root.decodeScale)
        sourceSize.height: Math.round(height * root.decodeScale)

        onStatusChanged: {
            if (status === Image.Error && root.source.length > 0)
                console.warn("Wallpaper: cannot load", root.source);
        }
    }
}
