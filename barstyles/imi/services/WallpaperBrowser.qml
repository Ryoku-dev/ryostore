pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// WallpaperBrowser is not in this port; members read as empty.
Singleton {
    property string currentProvider: ""
    property var currentSortType: null
    property real responses: 0
    property real runningRequests: 0
    property string showAnimeResults: ""
    property string similarImageId: ""
    property var unsplashApiToken: null
    function addSimilarImageMessage() {
    }
    function addSystemMessage() {
    }
    function clearResponses() {
    }
    function makeRequest() {
    }
    function moreLikeThisPicture() {
    }
    function setAnimeResults() {
    }
    function setProvider() {
    }
    function setSort() {
    }
}
