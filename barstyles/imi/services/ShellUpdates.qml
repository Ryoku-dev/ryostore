pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// ShellUpdates is not in this port; members read as empty.
Singleton {
    // Members the About page probes; updates are the shell's to own, so all
    // of this reads as "nothing pending".
    property string activeRemote: ""
    property bool probed: false
    property bool recentLoading: false
    property list<var> recentCommits: []
    function commitAuthor(): string {
        return "";
    }
    function githubSlug(remote: string): string {
        return "";
    }
    function reloadState(): void {
    }
    function loadRecent(): void {
    }
    function refresh(): void {
    }
    function launchInTerminal(): void {
    }
    function launchBranchSwitch(target: string): void {
    }
    function launchForkSwitch(target: string): void {
    }
    property var activeBranch: null
    property string activeCommit: ""
    property var activeFork: null
    property var checking: null
    property real commits: 0
    property int commitsBehind: 0
    property real commitsTruncated: 0
    property string compareUrl: ""
    property var hasUpdate: null
    property var remoteCommit: null
    function commitUrl() {
    }
    function forkLabel() {
    }
    function launchUpdate() {
    }
}
