pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// service/Main.qml — logic, no UI (R2).
//
// Runs the plugin's collector and exposes the normalized model to the views.
// Contract rules this file obeys:
//   R6/R9 — the external command is an argv array, NEVER `sh -c`.
//   R7    — no network of its own: the network belongs to `ai-usagebar`, never to us.
//   R8    — nothing is written from here; the only write target is stateDir
//           (which this plugin does not use — the collector is pure stdout).
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    // The normalized model the views draw. `null` before the first read; not
    // `{}`, because empty is a legitimate datum (0 providers).
    property var model: null
    property bool loading: false
    property string lastError: ""
    // When THIS machine last read the report successfully, in seconds since the
    // epoch. Distinct from each provider's `fetched_at`, which is when the
    // upstream collected it — a report can be seconds old here and hours old
    // upstream. The footer says how fresh OUR reading is, so it uses this.
    property real lastSuccessEpoch: 0

    // Error DISCRIMINATOR, not prose. `lastError` carries the collector's
    // diagnostic, the UI is English — matching text would be fragile. The stable
    // channel is the collector's EXIT CODE:
    //   "dep-missing" — rc exactly 3: the `ai-usagebar` binary is not on the
    //                   PATH. There is a way out on the user's side (install it).
    //   "upstream"    — any other rc != 0, or rc 0 with no model: the upstream
    //                   failed. There is nothing for the user to install.
    //   ""            — no error.
    property string errorKind: ""

    // Set by the stdout handler: this run's stdout became the model.
    // It has to be per run — a stale `model` from a previous run cannot let an
    // rc 0 with empty output pass as success.
    property bool _stdoutOk: false
    property string _stderrText: ""
    property string _parseError: ""

    // Up to six secondaries by default to preserve the height; the setting can raise it.
    readonly property int maxSecondary: {
        var v = settings ? Number(settings.maxSecondary) : NaN;
        return isFinite(v) && v >= 0 ? Math.min(v, 12) : 6;
    }

    // Read interval in seconds. Default 300s: the upstream caches and does an
    // OAuth fetch; aggressive polling is waste for a quota widget that changes in
    // hours, not seconds. Min 60s so it does not thrash.
    readonly property int intervalSec: {
        var v = settings ? Number(settings.pollSeconds) : NaN;
        return isFinite(v) && v >= 60 ? Math.min(v, 3600) : 300;
    }

    readonly property string providerOrder: {
        var v = settings ? String(settings.order || "upstream") : "upstream";
        return ["upstream", "highest", "lowest", "alphabetical", "manual"]
               .indexOf(v) >= 0 ? v : "upstream";
    }

    // Manual id sequence (`anthropic,openai@work,...`). Only effective with
    // `order: manual`; the collector ignores it outside that mode and the argv
    // below does not even forward it. Empty is valid: it degrades to the report's
    // order, never an error.
    readonly property string orderSequence: {
        return settings ? String(settings.orderSequence || "").trim() : "";
    }

    // Primary pinned by the user (a report id). Empty = pin nothing and let the
    // collector choose by order. `--primary` ALWAYS existed in the collector, but
    // no setting forwarded it: it was unreachable code (T16).
    //
    // T41 — TWO ways to pin, one precedence rule: the TEXT field wins whenever it
    // is filled, because only text can name an account (`openai@work`) and the
    // chips cannot. The chip is the convenience path for the bare vendor ids.
    // `auto` is the absence of a choice, never an id: sending `--primary auto`
    // would ask the collector for a provider called "auto".
    readonly property string pinnedChip: {
        var v = settings ? String(settings.primaryChoice || "auto").trim() : "auto";
        return (v === "" || v === "auto") ? "" : v;
    }
    readonly property string pinnedPrimary: {
        var text = settings ? String(settings.primary || "").trim() : "";
        return text !== "" ? text : svc.pinnedChip;
    }

    // The collector's path is NEVER hardcoded: it comes from the host's pluginDir
    // (R8/R6).
    readonly property string collectorPath:
        pluginApi && pluginApi.pluginDir ? pluginApi.pluginDir + "/bin/ai-usage-collect" : ""

    // Run without `sh -c` — a literal argv array (R9). `--from-file` would come
    // from a development setting; at runtime it is the binary.
    //
    // The setting flags are passed in argv: the collector limits the list BEFORE
    // serializing, so the secondary slider really responds.
    readonly property var collectorCmd: {
        var a = [svc.collectorPath];
        if (svc.maxSecondary !== 6) a.push("--max-secondary", String(svc.maxSecondary));
        if (svc.providerOrder !== "upstream") a.push("--order", svc.providerOrder);
        // `--order manual` REQUIRES `--sequence` (rc 2 without it). The service
        // therefore ALWAYS forwards the pair — including with an empty sequence,
        // which the collector treats as "the report's order" (contract item 2).
        // Omitting the flag with the field blank would turn a blank field into a
        // usage error on screen; sending `--sequence ""` keeps the CLI strict for
        // whoever types it in a terminal while the Hub user never sees a failure
        // from a blank field.
        if (svc.providerOrder === "manual")
            a.push("--sequence", svc.orderSequence);
        // Pinning the primary is orthogonal to order (it applies in any mode). A
        // blank field does NOT become a flag: an empty string is not an id and the
        // collector would treat it as "no primary" anyway — omitting it is more
        // honest in the argv and avoids a pointless `--primary ""`.
        if (svc.pinnedPrimary !== "") a.push("--primary", svc.pinnedPrimary);
        return a;
    }

    // Defer the start until AFTER the setting change has finished propagating.
    //
    // Why not call it directly: QML's `onXChanged` handlers fire DURING the
    // property change, when the `Process.command: svc.collectorCmd` binding has
    // NOT re-evaluated yet. Calling `collector.running = true` there starts the
    // process with the PREVIOUS command — measured: switching `primary` from
    // "copilot" to "zai" produced two invocations and BOTH with `--primary
    // copilot`; the new value only took effect on the next poll (up to 300s
    // later). `Qt.callLater` runs on the next event loop cycle, when the bindings
    // already reflect the new setting.
    function refresh() {
        if (collectorPath === "") return;
        Qt.callLater(() => svc.doRefresh(false));
    }

    // A SETTING changed: the in-flight read used the old arguments, so it has to
    // be replaced. This is the only case that may kill a running collection.
    function refreshNow() {
        if (collectorPath === "") return;
        Qt.callLater(() => svc.doRefresh(true));
    }

    // Set when THIS code stops the process on purpose, so `onExited` can tell a
    // deliberate cancel apart from a failure of the collector. Without it, the
    // SIGTERM we send to ourselves surfaced as "collector returned no output
    // (rc=15)" — the owner saw exactly that on screen (P4, 2026-10-29).
    property bool _cancelling: false

    function doRefresh(force) {
        if (collectorPath === "") return;
        // Already collecting, and nothing changed: let it FINISH.
        //
        // Restarting here was a quiet disaster. Opening the popout fires more than
        // one refresh (the view mounts, becomes active, and the poll may tick), and
        // every one of them killed the read in flight and started another. Measured
        // on 2026-10-29: ONE popout opening produced FOUR collections, each
        // SIGTERMing the previous one, so with a slow upstream NONE of them ever
        // finished and the screen sat on "no data" — then the next tick did the
        // same. A collection that is allowed to finish is the whole point.
        if (collector.running && !force) return;
        // `running = false` sends SIGTERM to a process that may be mid-collection.
        // That is intended (a new setting must not wait for the old read), but the
        // death it causes is NOT a failure and must never reach the screen.
        if (collector.running) {
            svc._cancelling = true;
            collector.running = false;
        }
        collector.running = true;
    }

    // `command` is a property: changing the setting without re-running leaves the
    // old value until the next poll tick (up to 186s in your tuning). Firing the
    // refresh on the spot is what makes the slider respond while you drag it.
    onMaxSecondaryChanged: refreshNow()
    onProviderOrderChanged: refreshNow()
    onOrderSequenceChanged: {
        // Re-collect only if the sequence matters right now; changing the text in
        // another mode must not spawn a process.
        if (svc.providerOrder === "manual") svc.refreshNow();
    }
    // The primary applies in ANY mode, so changing it always re-collects.
    onPinnedPrimaryChanged: refreshNow()

    Process {
        id: collector
        command: svc.collectorCmd
        // `onFinished` in Quickshell calls the parsers' streamEnded() BEFORE
        // emitting `exited` (src/io/process.cpp:274-282) — so `onExited` always
        // sees stdout/stderr already processed. That is why the error judgement
        // lives there: one place, with everything at hand.
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text.trim();
                if (raw === "") return;
                try {
                    svc.model = JSON.parse(raw);
                    svc._stdoutOk = true;
                } catch (e) {
                    // The collector emits JSON only on rc 0, but cheap defence: a
                    // view must never break on a parse.
                    svc._stdoutOk = false;
                    svc._parseError = "collector output is not JSON: " + e;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // Prose, not a discriminator: it goes to `lastError` (contract item 4).
                svc._stderrText = this.text.trim();
            }
        }
        onExited: (code) => {
            // A deliberate cancel (see `doRefresh`) is not a failure: the NEW run
            // is already starting. Reporting it would blank the screen on every
            // setting change and every reopen — measured as the "NO DATA · rc=15"
            // the owner reported with some frequency when opening the popout.
            if (svc._cancelling) {
                svc._cancelling = false;
                return;
            }
            svc.loading = false;
            if (code === 0 && svc._stdoutOk) {
                svc.errorKind = "";
                svc.lastError = "";
                svc.lastSuccessEpoch = Date.now() / 1000;
                return;
            }
            // rc 3 is the only case with a way out on the user's side: install the
            // binary. Any other rc (including argparse's 2) is upstream.
            svc.errorKind = (code === 3) ? "dep-missing" : "upstream";
            // Failure AFTER a success: KEEP the last good model, marked as failing.
            //
            // This used to clear the model, on the argument that stale data with no
            // warning is a lie. The argument was half right — the warning is what
            // makes it honest, not the blank screen. Clearing turned a TRANSIENT
            // upstream failure (a VPN that dropped the route, a token refresh that
            // timed out) into "NO DATA" for a whole poll interval, which is how the
            // owner read it: "parece que o plugin quebrou" (P4, 2026-10-29).
            //
            // The age of the data is already on screen in the footer, the failure
            // is in `errorKind`/`lastError`, and the view draws a staleness warning
            // from them. Keeping the numbers is strictly more information.
            // Only the very first read (no model yet) leaves the screen empty.
            if (svc._stderrText !== "") svc.lastError = svc._stderrText;
            else if (svc._parseError !== "") svc.lastError = svc._parseError;
            else svc.lastError = "collector returned no output (rc=" + code + ")";
        }
        onRunningChanged: {
            if (!running) return;
            svc.loading = true;
            // Error state is PER RUN: without the reset, a stale `_stdoutOk` would
            // let an rc 0 with empty output pass as success.
            svc._stdoutOk = false;
            svc._stderrText = "";
            svc._parseError = "";
        }
    }

    Timer {
        id: poll
        interval: Math.max(1, svc.intervalSec) * 1000
        running: svc.collectorPath !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: svc.refresh()
    }

    // The service has no counting Timer. The reset countdown tick is the VIEW's
    // responsibility: the view only exists when the host mounts it (on the
    // desktop, when the tile is placed; in the popout, at prog > 0.5). A Timer in
    // the service would run even with the screen closed.

    Component.onCompleted: if (svc.collectorPath !== "") svc.refresh()
}
