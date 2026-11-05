pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "functions"

// The launcher's own settings, trimmed from the barstyle Config to the categories the ported search surface reads.
Singleton {
    id: root

    readonly property string filePath: FileUtils.trimFileProtocol(`${Directories.config}/ryoku/launcher-imi.json`)
    property alias options: configOptionsJsonAdapter
    property bool ready: false
    property int readWriteDelay: 75 // milliseconds
    // Grace windows, same rationale as the barstyle: a transient missing file
    // (hot-reload, store update swap) must not clobber the user's settings
    // with QML defaults.
    property real initTimestamp: Date.now()
    property int missingFileGracePeriod: 5000
    property int missingFileRetryInterval: 1500
    property int writeGuardDelay: 3000

    Timer {
        id: fileWriteTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            if (!root.ready) {
                fileWriteTimer.restart();
                return;
            }
            if (Date.now() - root.initTimestamp < root.writeGuardDelay) {
                fileWriteTimer.restart();
                return;
            }
            configFileView.writeAdapter();
        }
    }

    onOptionsChanged: fileWriteTimer.restart()

    Timer {
        id: missingFileRetryTimer
        interval: root.missingFileRetryInterval
        repeat: false
        onTriggered: configFileView.reload()
    }

    FileView {
        id: configFileView
        path: Qt.resolvedUrl(root.filePath)
        adapter: configOptionsJsonAdapter
        watchChanges: false
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                if (Date.now() - root.initTimestamp > root.missingFileGracePeriod)
                    configFileView.writeAdapter();
                else
                    missingFileRetryTimer.restart();
                return;
            }
            console.log("[imi-launcher] Config load error:", error);
        }
    }

    JsonAdapter {
        id: configOptionsJsonAdapter

        property JsonObject appearance: JsonObject {
            property real animationMultiplier: 1.0
            property int blurSize: 40
            property string borderColorType: "user"
            property bool borderless: true
            property int borderWidth: 1
            property real extraBackgroundTint: 0.0
            property int gapsOut: 0
            property int roundingValue: 12
            property string roundnessFull: "0.6"
            property JsonObject icons: JsonObject {
                property bool enableThemed: true
            }
            property JsonObject fonts: JsonObject {
                property string main: "Google Sans Flex"
                property string title: "Google Sans Flex"
                property string expressive: "Google Sans Flex"
                property string reading: "Google Sans Flex"
                property string numbers: "Google Sans Flex"
                property string monospace: "JetBrainsMono Nerd Font"
                property string iconNerd: "JetBrainsMono Nerd Font"
            }
            property JsonObject transparency: JsonObject {
                property bool enable: false
                property bool automatic: true
                property real backgroundTransparency: 0.14
                property real contentTransparency: 0.9
                property bool popups: false
            }
        }

        property JsonObject background: JsonObject {
            property JsonObject widgets: JsonObject {
                property int gridStep: 40
            }
        }

        property JsonObject bar: JsonObject {
            property bool bottom: true
            property bool verbose: false
            property JsonObject tooltips: JsonObject {
                property bool enableTooltips: true
            }
            property JsonObject sizes: JsonObject {
                property int height: 40
                property int width: 40
            }
        }

        property JsonObject dock: JsonObject {
            property int height: 70
        }

        property JsonObject apps: JsonObject {
            property string terminal: "foot"
        }

        property JsonObject launcher: JsonObject {
            property list<string> pinnedApps: []
        }

        property JsonObject overview: JsonObject {
            property bool enable: true
            property string animationStyle: "zoom" // "bounce", "smooth", "zoom", "none"
            property string position: ""
            property string cardDesign: "classic"
        }

        property JsonObject search: JsonObject {
            property bool alwaysListApps: false
            property int nonAppResultDelay: 30
            property string engineBaseUrl: "https://www.google.com/search?q="
            property list<string> excludedSites: []
            property bool sloppy: false
            property bool levenshtein: false
            property bool frecency: true
            property real fuzzyThreshold: 0.35
            property real fuzzyRelativeCutoff: 0.35
            property real scoreThreshold: 0.2
            property string algorithm: "fuzzy"
            property bool enableMathPreview: true
            property string fileSearchDirectory: ""
            property bool blurFileSearchResultPreviews: false
            property list<var> aliases: []
            property list<var> sectionOrder: [
                { "id": "suggested" },
                { "id": "aliases" },
                { "id": "best" },
                { "id": "apps" },
                { "id": "tools" },
                { "id": "sites" },
                { "id": "actions" },
                { "id": "other" },
                { "id": "files" },
                { "id": "continue" }
            ]
            property int baseWidth: 580
            property int baseHeight: 500

            // Media rows are a barstyle feature and are not ported; the flags
            // stay so the shared idle-search logic reads a stable false.
            property bool showNowPlayingBubble: false
            property JsonObject nowPlaying: JsonObject {
                property bool enable: false
            }

            property JsonObject bestMatch: JsonObject {
                property bool enable: false
                property int secondaryActions: 4
                property bool uniformList: true
            }

            property JsonObject typoTolerance: JsonObject {
                property bool enable: true
                property real threshold: 0.30
                property int maxResults: 8
                property bool keyboardLayouts: true
            }

            property JsonObject browserSites: JsonObject {
                property bool enable: true
                property string profilePath: ""
                property int maxIndexedSites: 300
                property int maxResults: 6
                property bool includeHistory: true
                property bool useLocalFavicons: true
                property bool allowRemoteFavicons: false
                property int refreshMinutes: 10
            }

            property JsonObject fileSearch: JsonObject {
                property bool inlineResults: true
                property int minimumQueryLength: 3
                property int maxResults: 8
                property int maxDepth: 0
                property int threads: 4
                property bool includeHidden: false
                property list<string> excludedDirectories: ["node_modules", ".git", ".cache", ".venv", "__pycache__", ".cargo", ".rustup", ".npm", ".local/share/Trash"]
            }

            property JsonObject fileContent: JsonObject {
                property int maxResults: 40
                property int maxFileSizeMb: 8
                property int minimumQueryLength: 3
            }

            property JsonObject calculator: JsonObject {
                property bool updateExchangeRates: true
                property int historyMaxItems: 30
            }

            property JsonObject prefix: JsonObject {
                property bool showDefaultActionsWithoutPrefix: true
                property string action: "/"
                property string app: ">"
                property string clipboard: ";"
                property string fileSearch: ","
                property string fileContent: "'"
                property string emojis: ":"
                property string math: "="
                property string shellCommand: "$"
                property string webSearch: "?"
                property string windowSearch: "#"
                // No file browser panel ships in this port, but folder results
                // and Tab completion still speak the same path query shape.
                property string fileBrowser: "~"
            }

            property JsonObject modules: JsonObject {
                property bool clipboard: true
                property bool windowSearch: true
                property bool fileSearch: true
                property bool fileContent: true
                property bool math: true
                property bool shellCommand: true
                property bool webSearch: true
                property JsonObject emojis: JsonObject {
                    property bool enable: true
                    property string skinTone: "none"
                    property int gridColumns: 8
                    property bool showRecents: true
                    property string defaultCategory: "all"
                }
            }

            property JsonObject resultKeybinds: JsonObject {
                property bool enable: true
            }

            property JsonObject favorites: JsonObject {
                property bool enable: true
            }

            property JsonObject history: JsonObject {
                property bool enable: true
                property int maxItems: 50
            }

            property JsonObject frecencyData: JsonObject {
                property bool trackPanels: true
            }

            property list<var> keybindings: [
                { actionId: "actions", shortcut: "Ctrl+K" },
                { actionId: "favorite", shortcut: "Ctrl+P" },
                { actionId: "historyPrevious", shortcut: "Up" },
                { actionId: "historyNext", shortcut: "Down" },
                { actionId: "section", shortcut: "Tab" },
                { actionId: "sectionPrevious", shortcut: "Ctrl+Up" },
                { actionId: "sectionNext", shortcut: "Ctrl+Down" },
                { actionId: "secondary", shortcut: "Ctrl+Enter" },
                { actionId: "copy", shortcut: "Ctrl+C" },
                { actionId: "save", shortcut: "Ctrl+S" },
                { actionId: "edit", shortcut: "Ctrl+E" },
                { actionId: "create", shortcut: "Ctrl+N" },
                { actionId: "copyDispatch", shortcut: "Ctrl+Shift+K" },
                { actionId: "delete", shortcut: "Shift+Delete" }
            ]

            property JsonObject appearance: JsonObject {
                property bool accentPanels: true
                property real accentStrength: 0.12
                property bool showKeyHints: true
                property bool showKeyHintBar: true
                property string resultsStyle: "classic"
                property int panelWidth: 860
                property int panelBodyHeight: 420
            }

            property JsonObject clipboard: JsonObject {
                property int panelWidth: 860
                property real listColumnRatio: 0.40
                property bool showMetadata: true
                property int imageHeight: 200
                property int previewFontSize: 12
                property bool enableSloppySearch: false
                property JsonObject detectors: JsonObject {
                    property bool hexColor: true
                    property bool url: true
                    property bool email: true
                    property bool phone: true
                    property bool json: true
                    property bool filePath: true
                    property bool markdown: true
                    property bool number: true
                    property bool multiline: true
                }
            }

            property JsonObject suggestions: JsonObject {
                property bool enable: false
                property int maxSuggestionsPerSection: 5
                property bool showFrecency: true
                property bool showCommands: false
                property bool showApps: true
                property bool showAliases: true
                property bool showToggles: true
                property bool showPanels: true
            }
        }
    }
}
