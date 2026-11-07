pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "MotionConfig.mjs" as MotionConfig
Singleton {
    id: motion
    property var desktop: ({})
    property var performance: ({})
    readonly property var settings: MotionConfig.resolve(desktop,performance)
    readonly property int enterMs: settings.enter.ms
    readonly property int exitMs: settings.exit.ms
    readonly property int transitionMs: settings.transition.ms
    readonly property var enterCurve: settings.enter.curve
    readonly property var exitCurve: settings.exit.curve
    readonly property var transitionCurve: settings.transition.curve
    readonly property string configRoot: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME")+"/.config")+"/ryoku"
    FileView {
        path: motion.configRoot+"/desktop.json";watchChanges:true;printErrors:false
        onFileChanged:reload()
        onLoaded:{try{motion.desktop=JSON.parse(text());}catch(e){}}
    }
    FileView {
        path: motion.configRoot+"/performance.json";watchChanges:true;printErrors:false
        onFileChanged:reload()
        onLoaded:{try{motion.performance=JSON.parse(text());}catch(e){}}
    }
}
