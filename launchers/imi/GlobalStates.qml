pragma Singleton
import QtQuick
import Quickshell

// Launcher-local stand-in for the barstyle's GlobalStates.
Singleton {
    id: root

    // Owned by the launcher surface: true while Search is on screen.
    property bool overviewOpen: false
    // Published by SearchWidget while a hosted panel owns the input.
    property bool searchPanelActive: false
    // Output name the visible surface runs on; empty when closed.
    property string activeSearchMonitor: ""
    // The full shell's connect mode; always off for the standalone launcher.
    property bool searchConnectActive: false
    // Set while the user drags the island text in the barstyle; never here.
    property bool islandTextDragActive: false
    // A panel opened straight from a keybind has no plain-search step below it.
    property bool panelOpenedDirectly: false
    // The scrolling overview navigator is a window-grid surface, dropped from
    // this port; the field keeps every navigation key.
    property var scrollingOverviewNavigator: null

    // Panels requested through openSearchPanel wait here for the surface.
    property string pendingSearchPanel: ""
    property string pendingSearchPanelQuery: ""
    // Bumped by the barstyle when it wants panels to navigate; kept so the
    // ported Connections handler finds its signal.
    property string searchPanelNavigationRequest: ""
    // Overlay gates the ported widgets read. With the full shell absent they
    // are simply all closed.
    property bool sidebarRightOpen: false
    property bool sidebarLeftOpen: false
    property bool settingsOpen: false
    property bool osdVolumeOpen: false
    property bool wallpaperSelectorOpen: false
    property bool cheatsheetOpen: false
    property bool notesAppOpen: false
    property bool clockAppOpen: false
    property bool healthAppOpen: false
    property bool sessionOpen: false
    property bool usageOpen: false
    property bool modesOpen: false
    property bool editMode: false
    property bool islandDashboardOpen: false

    function closeSearchSurfaces() {
        root.overviewOpen = false;
    }

    function openSettings() {
    }

    function openSearchPanel(panelId, query) {
        root.pendingSearchPanel = String(panelId ?? "");
        root.pendingSearchPanelQuery = String(query ?? "");
    }

    function consumePendingSearchPanel() {
        const requested = root.pendingSearchPanel;
        root.pendingSearchPanel = "";
        return requested;
    }

    function consumePendingSearchPanelQuery() {
        const requested = root.pendingSearchPanelQuery;
        root.pendingSearchPanelQuery = "";
        return requested;
    }

    function clearFileBrowserSearchResults() {
    }
}
