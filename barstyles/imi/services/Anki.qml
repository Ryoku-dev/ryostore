pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Anki is not in this port; members read as empty.
Singleton {
    property var card: null
    property var cardBusy: null
    property real cardCount: 0
    property list<var> decks: []
    property var decksLoaded: null
    property string fatal: ""
    property var importing: null
    property var installError: null
    property string installStep: ""
    property bool installed: false
    property bool installing: false
    property string lastError: ""
    property var lastSyncMessage: null
    property string loggedIn: ""
    property var qml: null
    property string ready: ""
    property var revealed: null
    property var studiedToday: null
    property var studyDeck: ({})
    property string studying: ""
    property var syncConflict: null
    property string syncError: ""
    property string syncing: ""
    property real themeFontPx: 0
    property real themeMaxWidth: 0
    property var totals: null
    property var username: null
    property var version: null
    function addNote() {
    }
    function answer() {
    }
    function cardAction() {
    }
    function createDeck() {
    }
    function endStudy() {
    }
    function hold() {
    }
    function importPackage() {
    }
    function install() {
    }
    function login() {
    }
    function logout() {
    }
    function play() {
    }
    function playSide() {
    }
    function release() {
    }
    function resolveConflict() {
    }
    function retryStart() {
    }
    function reveal() {
    }
    function study() {
    }
    function sync() {
    }
    function undo() {
    }
}
