pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// AiStatusService is not in this port; members read as empty.
Singleton {
    property var agentCount: null
    property bool agents: false
    property var hasActiveAgents: null
    property var primaryAgent: null
    function focusAgent() {
    }
    function formatTokens() {
    }
    function metricsFor() {
    }
    function runtimeFor() {
    }
    function statusLabel() {
    }
}
