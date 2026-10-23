import QtQuick
import "FontBuilder.js" as FB

// One font style (headline, title, body, label, mono or icon) of Tokens.font.
QtObject {
    id: style

    property QtObject cfg
    property real scale: 1

    readonly property var largeSpec: FB.specFor(cfg.large, cfg.family, scale)
    readonly property var mediumSpec: FB.specFor(cfg.medium, cfg.family, scale)
    readonly property var smallSpec: FB.specFor(cfg.small, cfg.family, scale)
    readonly property var extraLargeSpec: cfg.extraLarge ? FB.specFor(cfg.extraLarge, cfg.family, scale) : ({})

    readonly property font large: Qt.font(largeSpec)
    readonly property font medium: Qt.font(mediumSpec)
    readonly property font small: Qt.font(smallSpec)
    readonly property font extraLarge: cfg.extraLarge ? Qt.font(extraLargeSpec) : Qt.application.font

    readonly property QtObject builders: QtObject {
        readonly property var large: FB.make(style.largeSpec)
        readonly property var medium: FB.make(style.mediumSpec)
        readonly property var small: FB.make(style.smallSpec)
        readonly property var extraLarge: FB.make(style.extraLargeSpec)
    }

    function size(pointSize: int): var {
        return FB.make(smallSpec).size(pointSize);
    }
}
