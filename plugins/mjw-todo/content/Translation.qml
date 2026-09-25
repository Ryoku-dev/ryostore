pragma Singleton
import QtQuick

// Trivial translation facade for the MJW kit: the ported widgets call
// Translation.tr(...) on every visible string; identity keeps the upstream
// behavior (en) without dragging the whole qs i18n pipeline into a plugin.
QtObject {
    id: root
    function tr(sourceText) {
        return String(sourceText || "");
    }
}
