pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "MotionConfig.mjs" as MotionConfig
Singleton {
    id: motion
    property var desktop: ({})
    property var performance: ({})
    property var live: null
    function refresh() { if(Theme.adaptive&&!effective.running)effective.running=true; }
    Connections {target:Theme;function onAdaptiveChanged(){if(Theme.adaptive)motion.refresh();else motion.live=null;}}
    Process {
        id:effective
        command:["ryoku-hub","desktop","defaults"]
        stdout:StdioCollector { onStreamFinished:{try{const value=JSON.parse(text);if(value.wm)motion.live=value;}catch(e){}} }
    }
    readonly property var settings: MotionConfig.resolve(desktop,performance,live)
    readonly property int enterMs: settings.enter.ms
    readonly property int exitMs: settings.exit.ms
    readonly property int transitionMs: settings.transition.ms
    readonly property var enterCurve: settings.enter.curve
    readonly property var exitCurve: settings.exit.curve
    readonly property var transitionCurve: settings.transition.curve
    readonly property string configRoot: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME")+"/.config")+"/ryoku"
    Timer {id:refreshDelay;interval:120;onTriggered:motion.refresh()}
    FileView {
        path: motion.configRoot+"/desktop.json";watchChanges:true;printErrors:false
        onFileChanged:{reload();refreshDelay.restart();}
        onLoaded:{try{motion.desktop=JSON.parse(text());motion.refresh();}catch(e){}}
    }
    FileView {
        path: motion.configRoot+"/performance.json";watchChanges:true;printErrors:false
        onFileChanged:reload()
        onLoaded:{try{motion.performance=JSON.parse(text());}catch(e){}}
    }
}
