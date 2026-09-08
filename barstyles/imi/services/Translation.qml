pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Singleton {
    id: root
    property var translations: ({})
    property string currentLanguage: "en"
    function t(key, fallback) {
        return (translations[key] !== undefined) ? translations[key] : (fallback !== undefined ? fallback : (key || ""));
    }
    function tr(key, fallback) {
        return root.t(key, fallback);
    }
}
