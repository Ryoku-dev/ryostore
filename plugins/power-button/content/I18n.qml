pragma ComponentBehavior: Bound

import QtQuick

// Plugin-local i18n (R4 forbids Ryoku.Ui.Singletons.I18n). Same contract as the
// shell/greeter: English source keys, Qt.locale() for system language, miss → key.
QtObject {
    id: i18n

    // Exact regional codes first (pt_BR), then language base (pt), else English.
    readonly property string lang: {
        var n = Qt.locale().name; // e.g. pt_BR, en_US
        if (i18n.catalogs[n])
            return n;
        var base = n.split("_")[0];
        return i18n.catalogs[base] ? base : "en";
    }

    // en is implicit (keys are the strings). pt + pt_BR cover Portuguese locales.
    readonly property var catalogs: ({
        "pt": {
            "Session": "Sessão",
            "Shut Down": "Desligar",
            "Restart": "Reiniciar",
            "Hibernate": "Hibernar",
            "Lock screen": "Bloquear o ecrã"
        },
        "pt_BR": {
            "Session": "Sessão",
            "Shut Down": "Desligar",
            "Restart": "Reiniciar",
            "Hibernate": "Hibernar",
            "Lock screen": "Bloquear a tela"
        }
    })

    function tr(s) {
        if (s === undefined || s === null || s === "")
            return s;
        var map = i18n.catalogs[i18n.lang];
        if (!map)
            return s;
        var v = map["" + s];
        return v === undefined ? s : v;
    }
}
