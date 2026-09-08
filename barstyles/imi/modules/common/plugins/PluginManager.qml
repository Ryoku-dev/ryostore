pragma Singleton
import QtQuick

QtObject {
    id: root

    property var availablePlugins: []
    property var installedPlugins: []
    property var plugins: []

    function getPlugin(id) { return null; }
    function isPluginEnabled(id) { return false; }
    function isPluginLoaded(id) { return false; }
}
