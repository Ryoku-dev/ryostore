pragma ComponentBehavior: Bound

import QtQuick
import shell.services as RyokuServices
import shell.barkit as Pill
import "../../.."
import "../../common"

Item {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    property bool mirrored: false
    property int bands: 14

    implicitWidth: vertical ? 24 : (bands * 5)
    implicitHeight: vertical ? (bands * 5) : 20

    Component.onCompleted: RyokuServices.AudioBars.setActive(root, true)
    Component.onDestruction: RyokuServices.AudioBars.setActive(root, false)
    onVisibleChanged: RyokuServices.AudioBars.setActive(root, visible)

    Pill.MusicBars {
        anchors.centerIn: parent
        orient: root.vertical ? "horizontal" : "vertical"
        bands: root.bands
        s: 0.9
        width: root.vertical ? 20 : (root.bands * 5)
        height: root.vertical ? (root.bands * 5) : 18
        lowColor: Appearance.colors.colPrimary
        highColor: Appearance.colors.colTertiary
        running: RyokuServices.Media.playing
        opacity: RyokuServices.Media.playing ? 1.0 : 0.4
        transform: Scale {
            xScale: !root.vertical && root.mirrored ? -1 : 1
            origin.x: width / 2
        }
    }
}
