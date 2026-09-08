pragma Singleton
import QtQuick

QtObject {
    id: root
    function tr(sourceText) {
        return String(sourceText || "");
    }
}
