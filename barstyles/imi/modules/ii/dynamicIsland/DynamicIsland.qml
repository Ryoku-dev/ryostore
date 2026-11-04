import "../../.."
import "../../common"
import "core"
import "styles/notch"
import QtQuick
import Quickshell

Scope {
    id: root

    LazyLoader {
        id: islandLoader
        // One place decides whether the island exists; see IslandPolicy for why.
        active: IslandPolicy.enabled

        component: NotchIsland {}
    }
}
