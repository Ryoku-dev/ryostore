pragma Singleton

import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../utils"

Searcher {
    id: root

    property string currentScheme
    property string currentVariant

    function transformSearch(search: string): string {
        return search.slice(`${GlobalConfig.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        return `${item.name} ${item.flavour}`;
    }

    function reload(): void {
        getSchemes.running = true;
    }

    list: schemes.instances
    useFuzzy: GlobalConfig.launcher.useFuzzy.schemes
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    Variants {
        id: schemes

        Scheme {}
    }

    Process {
        id: getSchemes

        running: true
        command: ["ryoku-shell", "theme", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const cards = JSON.parse(text);
                    schemes.model = cards.map(card => ({
                        id: card.id,
                        name: card.label || card.id,
                        flavour: card.provider || "",
                        colours: card.sw || []
                    }));
                } catch (error) {
                    console.warn("caelestia.launcher: could not read Ryoku themes", error);
                    schemes.model = [];
                }
            }
        }
    }

    Process {
        id: getCurrent

        command: ["true"]
    }

    component Scheme: QtObject {
        required property var modelData
        readonly property string id: modelData.id
        readonly property string name: modelData.name
        readonly property string flavour: modelData.flavour
        readonly property var colours: modelData.colours

        function onClicked(list: AppList): void {
            list.screenState.launcher = false;
            root.currentScheme = name;
            Quickshell.execDetached(["ryoku-shell", "theme", id]);
        }
    }
}
