pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Wallpapers is not in this port; members read as empty.
Singleton {
    property string directoryLoading: ""
    property var effectiveDirectory: null
    property var effectiveWallpaperPath: null
    property list<var> recordRecent: []
    property list<var> sortedFolderModel: []
    function apply() {
    }
    function applyLightModeWallpaper() {
    }
    function applyLockscreen() {
    }
    function generateThumbnail() {
    }
    function isVideoFile() {
    }
    function load() {
    }
    function openFallbackPicker() {
    }
    function randomFromCurrentFolder() {
    }
    function select() {
    }
    function selectLightmode() {
    }
    function selectLockscreen() {
    }
}
