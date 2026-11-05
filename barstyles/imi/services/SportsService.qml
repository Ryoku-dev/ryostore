pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// SportsService is not in this port; members read as empty.
Singleton {
    property list<var> allGames: []
    property var currentGame: ({})
    property real currentGameIndex: 0
    property real customOrder: 0
    property var loading: null
    function acquireWidgetSubscriber() {
    }
    function compactMatchStatus() {
    }
    function nextGame() {
    }
    function releaseWidgetSubscriber() {
    }
}
