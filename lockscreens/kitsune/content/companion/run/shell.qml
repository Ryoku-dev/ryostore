import Quickshell
import QtQuick

FloatingWindow {
    width: 1120
    height: 940
    visible: true
    color: "#07070d"
    title: "kitsune-mantra"

    Loader {
        anchors.fill: parent
        source: "file://" + Quickshell.configDir.replace(/\/[^/]*$/, "") + "/MantraSetup.qml"
        onLoaded: {
            const e = Quickshell.env("KITSUNE_THEME_CONF");
            item.confPath = e && e.length > 0 ? e
                : Quickshell.env("HOME") + "/.local/share/qylock/themes/kitsune/theme.conf";
            const dir = Quickshell.env("KITSUNE_MANTRA_DIR")
                || Quickshell.configDir.replace(/\/[^/]*$/, "");
            item.writerPath = dir + "/mantraconf.py";
        }
    }
}
