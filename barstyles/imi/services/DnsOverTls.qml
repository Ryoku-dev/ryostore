pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// DnsOverTls is not in this port; members read as empty.
Singleton {
    property string active: ""
    property string activeServers: ""
    property string available: ""
    property string busy: ""
    property var installCommand: null
    property var link: null
    property var polkitRuleInstalled: null
    property string presetLabel: ""
    property var presets: null
    property string resolvedAvailable: ""
    property string statusText: ""
    function applyNow() {
    }
    function applyPreset() {
    }
    function disable() {
    }
    function enable() {
    }
    function refresh() {
    }
    function toggle() {
    }
}
