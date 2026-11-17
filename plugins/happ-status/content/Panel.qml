pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

// Panel under the glyph: the full picture plus two explicit actions.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 320
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    component Field: Row {
        id: f
        property string k
        property string v
        visible: v !== ""
        width: parent ? parent.width : 0
        spacing: 8 * root.s
        Text {
            width: 90 * root.s
            text: f.k
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
        Text {
            width: f.width - 98 * root.s
            text: f.v
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 13 * root.s
            wrapMode: Text.Wrap
        }
    }

    component Btn: Rectangle {
        id: b
        property string text
        signal clicked()
        width: lbl.implicitWidth + 24 * root.s
        height: lbl.implicitHeight + 12 * root.s
        radius: Theme.radius
        color: ma.pressed ? Theme.vermDeep : Theme.accent
        Text {
            id: lbl
            anchors.centerIn: parent
            text: b.text
            color: Theme.cardBot
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
        MouseArea { id: ma; anchors.fill: parent; onClicked: b.clicked() }
    }

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.width - 24 * root.s
        spacing: 8 * root.s

        readonly property var sv: root.service
        function t(en, ruText) { return col.sv ? col.sv.t(en, ruText) : en; }

        Text {
            text: !col.sv ? "Happ"
                : !col.sv.running ? col.t("Happ is not running", "Happ не запущен")
                : !col.sv.tun ? col.t("Tunnel is down", "Туннель не поднят")
                : (col.sv.flag(col.sv.cc) + " " + (col.sv.country || col.t("Connected", "Подключено"))).trim()
            color: Theme.bright
            font.family: Theme.display
            font.pixelSize: 16 * root.s
        }

        Field { k: col.t("Server", "Сервер"); v: col.sv ? col.sv.server : "" }
        Field { k: col.t("Exit IP", "IP выхода"); v: col.sv && col.sv.connected ? col.sv.ip : "" }
        Field { k: col.t("City", "Город"); v: col.sv && col.sv.connected ? col.sv.city : "" }
        Field { k: col.t("Provider", "Провайдер"); v: col.sv && col.sv.connected ? col.sv.isp : "" }
        Field {
            k: col.t("Checked", "Проверено")
            v: col.sv && col.sv.connected && col.sv.checkedAt && !isNaN(col.sv.checkedAt)
               ? Qt.formatTime(col.sv.checkedAt, "HH:mm:ss") : ""
        }

        Row {
            spacing: 8 * root.s
            Btn {
                text: col.sv && col.sv.geoBusy ? col.t("CHECKING…", "ПРОВЕРЯЮ…") : col.t("REFRESH", "ОБНОВИТЬ")
                visible: !!col.sv && col.sv.connected
                onClicked: if (col.sv) col.sv.refresh()
            }
            Btn {
                text: col.t("OPEN HAPP", "ОТКРЫТЬ HAPP")
                onClicked: { if (col.sv) col.sv.openHapp(); if (root.pluginApi) root.pluginApi.closePanel(); }
            }
        }
    }
}
