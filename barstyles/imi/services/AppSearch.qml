pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Singleton {
    id: root
    function guessIcon(name) {
        return name || "application-x-executable";
    }
    function getAppList() {
        return [];
    }
}
