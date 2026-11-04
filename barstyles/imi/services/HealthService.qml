pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// HealthService is not in this port; members read as empty.
Singleton {
    property var attentionCount: null
    property var findings: null
    function action() {
    }
    function actionText() {
    }
    function isSnoozed() {
    }
    function notifyAlert() {
    }
    function openFinding() {
    }
    function primaryFix() {
    }
    function runPrimaryFix() {
    }
}
