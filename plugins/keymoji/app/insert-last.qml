import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Input.mjs" as Input

// A resident, windowless paste service. No layer or keyboard focus is taken.
ShellRoot {
    id: root
    readonly property var activeTarget: ToplevelManager.activeToplevel
    property var queue: []
    property var current: null
    property int completed: 0
    property int lastLatencyMs: 0
    property string lastError: ""
    function request() {
        try {
            history.reload();
            const emoji=Input.lastEmoji(JSON.parse(history.text()));
            Input.command(emoji,activeTarget,activeTarget,false);
            // Bound repeat backlog so releasing the shortcut cannot leave a long tail.
            if(queue.length>=8)return;
            queue=queue.concat([{emoji:emoji,target:activeTarget,time:Date.now()}]);
            pump();
        } catch(e) {lastError=String(e.message||e);console.error("Keymoji: "+lastError);}
    }
    function pump() {
        if(current||!queue.length)return;
        current=queue[0];queue=queue.slice(1);
        try {
            if(Date.now()-current.time>500)throw new Error("Expired repeat request");
            Input.command(current.emoji,current.target,activeTarget,false);
            clipboard.command=["wl-copy","--type","text/plain;charset=utf-8","--",current.emoji];
            watchdog.restart();clipboard.running=true;
        } catch(e) {finish(String(e.message||e));}
    }
    function finish(error) {
        watchdog.stop();
        if(!current)return;
        if(error){lastError=error;queue=[];console.error("Keymoji: "+error);}
        else {completed++;lastLatencyMs=Date.now()-current.time;lastError="";}
        current=null;
        Qt.callLater(root.pump);
    }
    FileView {
        id: history
        path: Quickshell.env("KEYMOJI_STATE_DIR")+"/history.json"
        blockLoading:true;printErrors:false
    }
    // Only a cold start waits for initial foreign-toplevel discovery.
    Timer {interval:100;running:true;onTriggered:root.request()}
    IpcHandler {
        target:"keymoji-last"
        function insert():void {root.request();}
        function state():string {return JSON.stringify({completed:root.completed,queued:root.queue.length,busy:!!root.current,lastLatencyMs:root.lastLatencyMs,lastError:root.lastError});}
    }
    Timer {
        id:watchdog;interval:2000
        onTriggered:{clipboard.running=false;backend.running=false;root.finish("Paste backend timed out");}
    }
    Process {
        id:clipboard
        onExited:code=>{
            if(!root.current)return;
            if(code!==0){root.finish("Could not copy last emoji");return;}
            try {
                Input.command(root.current.emoji,root.current.target,root.activeTarget,false);
                backend.running=true;
            } catch(e) {root.finish(String(e.message||e));}
        }
    }
    Process {
        id:backend
        command:Quickshell.env("KEYMOJI_PASTE_HELPER") ? [Quickshell.env("KEYMOJI_PASTE_HELPER")] : ["wtype","-m","logo","-m","shift","-M","ctrl","-k","v","-m","ctrl"]
        onExited:code=>root.finish(code===0?"":"Could not paste last emoji")
    }
}
