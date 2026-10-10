pragma ComponentBehavior: Bound
import QtQuick
import "." as Shared

Item {
    id: root
    property var pluginApi
    property bool attached: false
    property var attachedApi: null
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property bool enabled: Shared.Monitor.enabled
    readonly property int lowThreshold: Shared.Monitor.lowThreshold
    readonly property int criticalThreshold: Shared.Monitor.criticalThreshold
    readonly property int percentage: Shared.Monitor.percentage
    readonly property string status: Shared.Monitor.status
    readonly property string lastResult: Shared.Monitor.lastResult
    function sync() {
        if (!pluginApi) return;
        if (attached && attachedApi !== pluginApi) {
            Shared.Monitor.detach(attachedApi);
            attached = false;
        }
        if (!attached) {
            attached = true;
            attachedApi = pluginApi;
            Shared.Monitor.attach(pluginApi);
        }
        Shared.Monitor.settings = settings || ({});
    }
    function testNotification() { Shared.Monitor.testNotification(); }
    onPluginApiChanged: sync()
    onSettingsChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (attached) Shared.Monitor.detach(attachedApi)
}
