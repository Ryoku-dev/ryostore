pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// PhoneContactsService is not in this port; members read as empty.
Singleton {
    property var contacts: ({})
    property var count: null
    property real filteredContacts: 0
    property var hiddenCount: null
    property real ready: 0
    function composeSms() {
    }
    function copyPhone() {
    }
    function isFavorite() {
    }
    function openDialer() {
    }
    function refresh() {
    }
    function setSearchQuery() {
    }
    function toggleFavorite() {
    }
}
