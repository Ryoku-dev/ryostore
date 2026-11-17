import QtQuick
import Quickshell.Io
Item {
    id: root
    property var pluginApi
    property string error: ""
    function launch() {
        if(!pluginApi || launchProcess.running)return;
        error="";
        launchProcess.command=["env","KEYMOJI_STATE_DIR="+pluginApi.stateDir,pluginApi.pluginDir+"/bin/keymoji"];
        launchProcess.running=true;
        pluginApi.closePanel();
    }
    Process {
        id:launchProcess
        stderr:StdioCollector { onStreamFinished:if(text.trim())root.error=text.trim() }
    }
}
