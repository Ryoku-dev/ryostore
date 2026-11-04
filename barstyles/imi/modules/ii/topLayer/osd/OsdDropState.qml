import QtQuick
import "../../../common"

QtObject {
    id: root

    required property string mode
    property real contentWidth: 0
    property real contentHeight: 0
    property real screenWidth: 1920

    readonly property bool isOsd: mode === "osd"

    readonly property real targetW: {
        if (!isOsd) return 0;
        return contentWidth > 0 ? contentWidth : Appearance.sizes.osdWidth + 2 * Appearance.sizes.elevationMargin;
    }

    readonly property real targetH: {
        if (!isOsd) return 0;
        return contentHeight > 0 ? contentHeight : 0;
    }
}
