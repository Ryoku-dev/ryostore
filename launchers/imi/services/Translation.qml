pragma Singleton

import QtQuick
import Quickshell
import Ryoku.Ui.Singletons as RyokuUi

// Adapter over the host's I18n.
Singleton {
    id: root

    property var translations: ({})
    property var generatedTranslations: ({})
    property var availableLanguages: RyokuUi.I18n.langs ?? ["en_US"]
    property var availableGeneratedLanguages: []
    property var allAvailableLanguages: availableLanguages
    property bool isScanning: false
    property bool isLoading: false
    property string languageCode: RyokuUi.I18n.lang ?? "en_US"

    function tr(text) {
        if (text === undefined || text === null)
            return "";
        const s = String(text);
        const out = RyokuUi.I18n.tr(s);
        return out === undefined || out === null ? s : out;
    }

    function trWithSuffix(text, suffix) {
        return root.tr(text) + (suffix ?? "");
    }

    function refresh() {
    }
}
