import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import "../../.."
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"

/**
 * About & Updates.
 *
 * What this shell is running, whether the fork's remote has moved on, and
 * what the waiting update contains — in that order, since that is what the
 * page is opened for. The checkout itself is only ever changed from a
 * terminal window (see ShellUpdates.launchInTerminal), so the log outlives
 * the shell restart the setup script performs. Fork and branch switching,
 * the projects this shell builds on and the people who built this fork
 * follow on the same page.
 */
Item {
    id: root
    anchors.fill: parent

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    // People who contributed to this fork, as credited by its author, read
    // from CONTRIBUTORS.json at the top of the ii folder: GitHub login,
    // display name and a one-line role each; the avatar comes from GitHub.
    property var contributors: []

    FileView {
        path: Directories.shellPath("CONTRIBUTORS.json")
        onLoaded: {
            let parsed = null;
            try {
                parsed = JSON.parse(text());
            } catch (e) {
                console.warn("[About] CONTRIBUTORS.json is not valid JSON:", e);
                return;
            }
            const list = Array.isArray(parsed?.contributors) ? parsed.contributors : [];
            root.contributors = list.filter(c => c && typeof c.login === "string" && c.login !== "");
        }
        onLoadFailed: error => console.warn("[About] CONTRIBUTORS.json could not be read:", error)
    }

    readonly property var forkPresets: [
        { "id": "p3drovfx", "label": "II-P3DROVFX", "icon": "fork_right" },
        { "id": "end4", "label": "end-4", "icon": "deployed_code" },
        { "id": "vynx", "label": "ii-vynx", "icon": "cloud_download" }
    ]

    // What the confirmation dialog is about: "branch" or "fork", the
    // argument the script gets, and how the dialog names it.
    property string pendingKind: ""
    property string pendingTarget: ""
    property string pendingLabel: ""
    // Keep the optional AI graph out of About until the user enables automatic
    // summaries or explicitly asks for one. The manual action remains visible
    // without probing the heavyweight Ai singleton just by opening Settings.
    property bool manualSummaryRequested: false

    function confirm(kind, target, label) {
        root.pendingKind = kind;
        root.pendingTarget = target;
        root.pendingLabel = label;
        confirmDialog.show = true;
    }

    // Both switches replace the whole ii folder, so each is confirmed with
    // what exactly gets replaced, then handed to a terminal window and the
    // Settings window closes: the setup script restarts the shell partway
    // through, and only a terminal keeps the log readable across that.
    function runPending() {
        confirmDialog.show = false;
        if (root.pendingKind === "branch")
            ShellUpdates.launchBranchSwitch(root.pendingTarget);
        else if (root.pendingKind === "fork")
            ShellUpdates.launchForkSwitch(root.pendingTarget);
        else
            return;
        GlobalStates.settingsOpen = false;
    }

    readonly property bool hasUpdate: ShellUpdates.hasUpdate
    readonly property bool checking: ShellUpdates.checking
    readonly property int behind: ShellUpdates.commitsBehind
    readonly property string forkLabel: ShellUpdates.forkLabel(ShellUpdates.activeFork)
    readonly property bool onP3drovfx: ShellUpdates.activeFork === "p3drovfx" || ShellUpdates.activeFork === "mine"
    readonly property string shortCommit: ShellUpdates.activeCommit.substring(0, 7)
    readonly property string repoUrl: {
        const slug = ShellUpdates.githubSlug(ShellUpdates.activeRemote);
        return slug === "" ? "" : `https://github.com/${slug}`;
    }

    // With AI summaries on, the summary is the headline and the commit list is
    // detail that folds away; without them the list is all there is to read,
    // so it stays open.
    readonly property bool summaryRequested: Config.options.update.aiSummary || root.manualSummaryRequested
    readonly property bool listsFold: Config.options.update.aiSummary
    readonly property var listedCommits: root.hasUpdate ? ShellUpdates.commits : ShellUpdates.recentCommits
    readonly property bool listVisible: root.hasUpdate
        ? (ShellUpdates.commits.length > 0 || (root.summaryRequested && ShellUpdateSummary.current))
        : (ShellUpdates.recentCommits.length > 0 || ShellUpdates.recentLoading)

    function refreshRecent() {
        if (!root.visible || root.hasUpdate || root.checking)
            return;
        ShellUpdates.loadRecent();
    }

    Component.onCompleted: {
        FeatureDeps.refresh();
        ShellUpdates.reloadState();
        if (!ShellUpdates.probed)
            ShellUpdates.refresh();
        else
            root.refreshRecent();
    }

    // A page opened to see whether there is an update should not show a
    // shrug: if nothing has been asked of the remote since the shell started,
    // ask once now, whatever the automatic interval says.
    onVisibleChanged: {
        if (!visible)
            return;
        ShellUpdates.reloadState();
        if (!ShellUpdates.probed) {
            ShellUpdates.refresh();
            return;
        }
        root.refreshRecent();
    }

    onHasUpdateChanged: root.refreshRecent()
    onCheckingChanged: root.refreshRecent()

    // One cell of the 2×2 lineage grid: the title on top, the project's mark
    // large in the middle, its name, home link and buttons under it. Corner
    // radii are set per cell by the caller.
    component LineageTile: ContentSubsection {
        id: tile
        property string name: ""
        property string url: ""
        property Component logo: null
        // [{icon, label, url, fill}]
        property var links: []

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        topLeftRadius: Appearance.rounding.verysmall
        topRightRadius: Appearance.rounding.verysmall
        bottomLeftRadius: Appearance.rounding.verysmall
        bottomRightRadius: Appearance.rounding.verysmall

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            spacing: 12

            Loader {
                Layout.preferredWidth: 50
                Layout.preferredHeight: 50
                sourceComponent: tile.logo
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: tile.name
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: tile.url !== ""
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.small
                    text: `<a href='${tile.url}'>${tile.url.replace(/^https?:\/\/(www\.)?/, "")}</a>`
                    textFormat: Text.RichText
                    elide: Text.ElideRight
                    onLinkActivated: link => Qt.openUrlExternally(link)
                    PointingHandLinkHover {}
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: tile.links

                delegate: RippleButtonWithIcon {
                    required property var modelData
                    materialIcon: modelData.icon
                    materialIconFill: modelData.fill ?? true
                    mainText: modelData.label
                    onClicked: Qt.openUrlExternally(modelData.url)
                }
            }
        }
    }

    // One credited person: GitHub avatar (initial until it loads), name, role.
    // The whole card opens the profile. Cards sit in a two-column grid, so
    // the big corners go on the grid's outer corners, not on each card.
    component ContributorRow: RippleButton {
        id: person
        property string login: ""
        property string name: ""
        property string role: ""
        // Position in the grid. Named apart from the delegate's `index`: a
        // property redeclared by the delegate is invisible to bindings here.
        property int slot: 0
        property int count: 1
        readonly property int lastRow: Math.ceil(count / 2) - 1
        readonly property int row: Math.floor(slot / 2)
        readonly property bool leftCol: slot % 2 === 0
        readonly property bool rightEdge: !leftCol || slot === count - 1

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: personLayout.implicitHeight + 20
        topLeftRadius: row === 0 && leftCol ? Appearance.rounding.large : Appearance.rounding.verysmall
        topRightRadius: row === 0 && rightEdge ? Appearance.rounding.large : Appearance.rounding.verysmall
        bottomLeftRadius: row === lastRow && leftCol ? Appearance.rounding.large : Appearance.rounding.verysmall
        bottomRightRadius: row === lastRow && rightEdge ? Appearance.rounding.large : Appearance.rounding.verysmall
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        onClicked: Qt.openUrlExternally(`https://github.com/${person.login}`)

        StyledToolTip {
            text: `github.com/${person.login}`
        }

        contentItem: RowLayout {
            id: personLayout
            spacing: 12

            Item {
                Layout.leftMargin: 2
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Appearance.colors.colSecondaryContainer
                    visible: avatar.status !== Image.Ready

                    StyledText {
                        anchors.centerIn: parent
                        text: person.name.charAt(0).toUpperCase()
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }

                Image {
                    id: avatar
                    anchors.fill: parent
                    source: person.login !== "" ? `https://avatars.githubusercontent.com/${person.login}?s=96` : ""
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: avatar.width
                            height: avatar.height
                            radius: width / 2
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: person.name
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: person.role
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                Layout.rightMargin: 4
                text: "open_in_new"
                iconSize: 20
                color: Appearance.colors.colSubtext
            }
        }
    }

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress
        visible: opacity > 0

        // ── Identity: fork, branch, commit, and whether the remote moved ──
        //
        // The logo is the card. It spans the card's height on the left, and
        // everything else - name, branch, status, actions - sits in one column
        // beside it, so the mark is never a small badge above a row of buttons.
        Rectangle {
            id: hero
            Layout.fillWidth: true
            implicitHeight: heroRow.implicitHeight + 48
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            readonly property real logoSize: 112

            RowLayout {
                id: heroRow
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 24
                }
                spacing: 24

                // The fork's own mark where it has one; a custom remote gets a
                // plain symbol rather than someone else's logo.
                Item {
                    Layout.preferredWidth: hero.logoSize
                    Layout.preferredHeight: hero.logoSize
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.fill: parent
                        visible: true
                        source: "file://" + Directories.shellPath("assets/icons/ii-p3drovfx.png")
                        sourceSize: Qt.size(hero.logoSize * 2, hero.logoSize * 2)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }

                    IconImage {
                        anchors.fill: parent
                        visible: ShellUpdates.activeFork === "end4"
                        implicitSize: hero.logoSize
                        source: Quickshell.iconPath("illogical-impulse")
                    }

                    CustomIcon {
                        anchors.fill: parent
                        width: hero.logoSize
                        height: hero.logoSize
                        visible: ShellUpdates.activeFork === "vynx" || ShellUpdates.activeFork === "upstream"
                        source: "ii-vynx"
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colLayer2

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "hub"
                            iconSize: 56
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            StyledText {
                                Layout.fillWidth: true
                                text: "IMI - Dodo986"
                                font.pixelSize: 32
                                font.weight: Font.Bold
                                font.variableAxes: Appearance.font.variableAxes.titleRounded
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: Translation.tr("ported and derived from pedrovfx's ii setup")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colSubtext
                            }
                        }

                        // Status, top right, with the last check time under it.
                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            spacing: 6

                            Rectangle {
                                id: statusPill
                                Layout.alignment: Qt.AlignRight
                                implicitWidth: statusRow.implicitWidth + 24
                                implicitHeight: 36
                                radius: Appearance.rounding.full
                                color: root.checking ? Appearance.colors.colLayer2 : root.hasUpdate ? Appearance.colors.colTertiaryContainer : ShellUpdates.remoteCommit !== "" ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                                readonly property color fg: root.checking ? Appearance.colors.colOnLayer1 : root.hasUpdate ? Appearance.colors.colOnTertiaryContainer : ShellUpdates.remoteCommit !== "" ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1

                                Behavior on color {
                                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                }

                                RowLayout {
                                    id: statusRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    MaterialLoadingIndicator {
                                        visible: root.checking
                                        implicitSize: 16
                                    }

                                    MaterialSymbol {
                                        visible: !root.checking
                                        text: root.hasUpdate ? "deployed_code_update" : ShellUpdates.remoteCommit !== "" ? "check_circle" : ShellUpdates.probed ? "cloud_off" : "help"
                                        fill: 1
                                        iconSize: 18
                                        color: statusPill.fg
                                    }

                                    StyledText {
                                        text: {
                                            if (root.checking)
                                                return Translation.tr("Checking…");
                                            if (ShellUpdates.remoteCommit === "")
                                                return ShellUpdates.probed ? Translation.tr("Remote unreachable") : Translation.tr("Not checked yet");
                                            if (!root.hasUpdate)
                                                return Translation.tr("Up to date");
                                            return root.behind > 0 ? Translation.tr("%1 commits behind").arg(root.behind) : Translation.tr("Update available");
                                        }
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.DemiBold
                                        color: statusPill.fg
                                    }
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignRight
                                Layout.rightMargin: 4
                                visible: text !== ""
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                text: {
                                    if (ShellUpdates.lastCheck <= 0)
                                        return "";
                                    return Translation.tr("Last checked %1").arg(new Date(ShellUpdates.lastCheck).toLocaleString(Qt.locale(), Locale.ShortFormat));
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RippleButtonWithIcon {
                            Layout.preferredHeight: 44
                            buttonRadius: Appearance.rounding.full
                            colBackground: root.hasUpdate ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
                            colBackgroundHover: root.hasUpdate ? Appearance.colors.colPrimaryHover : Appearance.colors.colSecondaryContainerHover
                            colRipple: root.hasUpdate ? Appearance.colors.colPrimaryActive : Appearance.colors.colSecondaryContainerActive
                            colText: root.hasUpdate ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                            materialIcon: "terminal"
                            mainText: Translation.tr("Update")
                            onClicked: {
                                Quickshell.execDetached(["kitty", "-1", "--hold=yes", "ryoku", "update"]);
                                GlobalStates.settingsOpen = false;
                            }

                            StyledToolTip {
                                text: Translation.tr("Runs ryoku update in a terminal. This window closes so the log stays readable while the shell reloads.")
                            }
                        }

                        RippleButtonWithIcon {
                            Layout.preferredHeight: 44
                            buttonRadius: Appearance.rounding.full
                            materialIcon: "refresh"
                            mainText: Translation.tr("Check now")
                            enabled: !root.checking
                            onClicked: ShellUpdates.refresh()
                        }

                        RippleButtonWithIcon {
                            visible: root.repoUrl !== ""
                            Layout.preferredHeight: 44
                            buttonRadius: Appearance.rounding.full
                            materialIcon: "open_in_new"
                            mainText: root.hasUpdate && ShellUpdates.compareUrl !== "" ? Translation.tr("Compare on GitHub") : Translation.tr("GitHub")
                            onClicked: Qt.openUrlExternally(root.hasUpdate && ShellUpdates.compareUrl !== "" ? ShellUpdates.compareUrl : root.repoUrl)
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // ── What the update contains, or what changed lately ──
        // Updates and fork management are the shell's to own.

        // ── How updates are found and applied ──
        // Updates and fork management are the shell's to own.

        // ── Where the checkout comes from ──
        // Updates and fork management are the shell's to own.

        // ── What this shell builds on ──
        ContentSection {
            icon: "account_tree"
            title: Translation.tr("About this shell")
            tooltip: Translation.tr("Each project builds on the next one.")

            StyledText {
                Layout.fillWidth: true
                text: "Imi 2.0.0 - maintained by Dodo986"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 2
                columnSpacing: 2

                LineageTile {
                    topLeftRadius: Appearance.rounding.large
                    title: Translation.tr("This style")
                    icon: "call_split"
                    name: "IMI"
                    url: "https://github.com/dodo986"
                    links: [
                        { "icon": "person", "label": "Dodo986", "url": "https://github.com/dodo986" },
                        { "icon": "code", "label": Translation.tr("GitHub"), "url": "https://github.com/dodo986", "fill": false }
                    ]
                    logo: Image {
                        anchors.fill: parent
                        source: "file://" + Directories.shellPath("assets/icons/ii-p3drovfx.png")
                        sourceSize: Qt.size(width * 2, height * 2)
                        fillMode: Image.PreserveAspectFit
                    }
                }

                LineageTile {
                    topRightRadius: Appearance.rounding.large
                    title: Translation.tr("Upstream")
                    icon: "code"
                    name: "II-P3DROVFX"
                    url: "https://github.com/P3DROVFX/ii-p3drovfx"
                    links: [
                        { "icon": "auto_stories", "label": Translation.tr("Wiki"), "url": "https://github.com/P3DROVFX/ii-p3drovfx/wiki" },
                        { "icon": "adjust", "label": Translation.tr("Issues"), "url": "https://github.com/P3DROVFX/ii-p3drovfx/issues", "fill": false }
                    ]
                    logo: Image {
                        anchors.fill: parent
                        source: "file://" + Directories.shellPath("assets/icons/ii-p3drovfx.png")
                        sourceSize: Qt.size(width * 2, height * 2)
                        fillMode: Image.PreserveAspectFit
                    }
                }

                LineageTile {
                    bottomLeftRadius: Appearance.rounding.large
                    title: Translation.tr("Parent dots")
                    icon: "deployed_code"
                    name: "illogical-impulse"
                    url: "https://github.com/end-4/dots-hyprland"
                    links: [
                        { "icon": "auto_stories", "label": Translation.tr("Wiki"), "url": "https://end-4.github.io/dots-hyprland-wiki/en/ii-qs/02usage/" },
                        { "icon": "favorite", "label": Translation.tr("Sponsor"), "url": "https://github.com/sponsors/end-4" }
                    ]
                    logo: IconImage {
                        anchors.fill: parent
                        source: Quickshell.iconPath("illogical-impulse")
                    }
                }

                LineageTile {
                    bottomRightRadius: Appearance.rounding.large
                    title: Translation.tr("Distribution")
                    icon: "developer_board"
                    name: SystemInfo.distroName
                    url: SystemInfo.homeUrl
                    links: [
                        { "icon": "auto_stories", "label": Translation.tr("Docs"), "url": SystemInfo.documentationUrl },
                        { "icon": "bug_report", "label": Translation.tr("Bugs"), "url": SystemInfo.bugReportUrl }
                    ]
                    logo: IconImage {
                        anchors.fill: parent
                        source: Quickshell.iconPath(SystemInfo.logo)
                    }
                }
            }
        }

        // ── Who built this fork ──
        ContentSection {
            icon: "group"
            title: Translation.tr("Contributors")
            tooltip: Translation.tr("People credited by the fork's author. The list lives at the top of this page's source file.")

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 2
                columnSpacing: 2

                Repeater {
                    model: root.contributors

                    delegate: ContributorRow {
                        required property var modelData
                        required property int index
                        slot: index
                        login: modelData.login
                        name: modelData.name
                        role: modelData.role
                        count: root.contributors.length
                    }
                }
            }
        }
    }

    ConfigSubPageHost {
        id: subPageOverlay
        anchors.fill: parent
        z: 10
    }

    WindowDialog {
        id: confirmDialog
        parent: root
        anchors.fill: parent
        show: false
        backgroundWidth: root.pendingKind === "fork" ? 620 : 400
        z: 100000
        onDismiss: show = false

        WindowDialogTitle {
            text: Translation.tr("Switch to %1?").arg(root.pendingLabel)
        }

        WindowDialogParagraph {
            Layout.fillWidth: true
            text: root.pendingKind === "branch"
                ? Translation.tr("The ii folder is replaced with the %1 branch of %2. Your settings are kept and the shell restarts. The run happens in a terminal window and this window closes.").arg(root.pendingLabel).arg(root.forkLabel)
                : Translation.tr("The ii folder is replaced with that fork's latest and your settings are reset to its defaults, since its options differ. A backup of both is kept. The run happens in a terminal window and this window closes.")
        }

        // Another fork has no such page, so the way back is the CLI. Only
        // shown for fork switches: a branch switch keeps these buttons.
        NoticeBox {
            visible: root.pendingKind === "fork"
            Layout.fillWidth: true
            materialIcon: "info"
            text: Translation.tr("Switching forks replaces your ii folder. You'll lose these visual buttons until you return.\n\n" +
                                 "To return or switch again from a terminal, run:\n" +
                                 "  II-P3DROVFX fork p3drovfx\n\n" +
                                 "Or run the setup script directly:\n" +
                                 "  ~/.local/share/ii-p3drovfx/setup-ii-p3drovfx.sh switch --fork p3drovfx\n\n" +
                                 "Useful subcommands and flags:\n" +
                                 "  switch: change fork or branch without reinstalling dependencies\n" +
                                 "  update: refresh the fork and branch you are already on\n" +
                                 "  --fork <name|url>: a preset (p3drovfx, end4, vynx) or a GitHub URL\n" +
                                 "  --branch <name>: main or dev\n" +
                                 "  --keep-config: keep your current settings")
        }

        WindowDialogButtonRow {
            DialogButton {
                buttonText: Translation.tr("Cancel")
                onClicked: confirmDialog.show = false
            }

            DialogButton {
                buttonText: Translation.tr("Switch")
                onClicked: root.runPending()
            }
        }
    }
}
