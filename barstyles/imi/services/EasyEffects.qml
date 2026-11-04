pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "."
import shell.services as HostServices

// Audio effects for the bar's equalizer controls, over the host's 10-band
// Equalizer service (ryoku-eq). The old EasyEffects daemon had bypass states,
// per-device presets and preset files; none of that exists here, so bypass maps
// to the equalizer's on/off and the preset list is the service's fixed eight.
Singleton {
    id: root

    readonly property bool available: true
    // ryoku-eq is always the native build here.
    property bool bothInstalled: false
    property bool preferFlatpak: false
    property int flatpakMajor: 0
    property int nativeMajor: 0
    function setPreferFlatpak(value: bool): void {
    }

    readonly property bool running: HostServices.Equalizer.running
    readonly property bool starting: HostServices.Equalizer.on && !HostServices.Equalizer.running
    // Bypass is "the filter is in the graph but muted"; the closest thing the
    // equalizer has is being switched off.
    readonly property bool bypassed: !HostServices.Equalizer.on
    readonly property bool active: HostServices.Equalizer.on && HostServices.Equalizer.running

    readonly property string outputPreset: HostServices.Equalizer.preset
    readonly property var outputPresets: HostServices.Equalizer.presets
    readonly property var devicePresets: HostServices.Equalizer.presets
    // No autoload concept on the host: no preset is tied to a device.
    readonly property string outputDeviceDefault: ""

    readonly property var outputDevice: Audio.defaultAudioSink

    property var _holds: ({})

    function iconFor(name: string): string {
        const label = root.shortName(name);
        const rules = [
            [/music|song|hifi|hi-fi|harman|studio|reference|bass|flat|pop|rock|jazz|classic/i, "music_note"],
            [/movie|film|cinema|video|tv|series/i, "movie"],
            [/voice|vocal|speech|podcast|talk|call|meeting/i, "record_voice_over"],
            [/game|gaming|fps/i, "sports_esports"],
            [/night|late|quiet|sleep/i, "bedtime"],
            [/treble/i, "graphic_eq"],
            [/flat|neutral|off|none|bypass|default/i, "horizontal_rule"]
        ];
        for (const rule of rules)
            if (rule[0].test(label))
                return rule[1];
        return "graphic_eq";
    }

    // The part worth showing where the device is already on screen.
    function shortName(name: string): string {
        const text = String(name || "");
        for (const separator of [" · ", " • ", " — ", " – ", " - ", ": ", " | ", " / "]) {
            const at = text.indexOf(separator);
            if (at > 0 && at + separator.length < text.length)
                return text.slice(at + separator.length);
        }
        return text;
    }

    function enable() {
        HostServices.Equalizer.setOn(true);
    }

    function disable() {
        HostServices.Equalizer.setOn(false);
    }

    function toggle() {
        HostServices.Equalizer.setOn(root.bypassed);
    }

    function setBypass(on: bool) {
        HostServices.Equalizer.setOn(!on);
    }

    function toggleBypass() {
        root.setBypass(!root.bypassed);
    }

    function loadPreset(name: string, pipeline = "output", announce = false) {
        if (name.length === 0)
            return;
        // The host Equalizer spawns ryoku-eq itself, but its Process swallows
        // stderr; spawn directly so a failure is at least visible here.
        presetProc.command = ["ryoku-eq", "preset", name];
        presetProc.running = true;
    }

    Process {
        id: presetProc

        stdout: StdioCollector { onStreamFinished: {
            if (this.text.trim().length > 0)
                HostServices.Equalizer.ingest(this.text);
        } }
        stderr: StdioCollector { onStreamFinished: {
            if (this.text.trim().length > 0)
                console.warn("[EasyEffects] preset error:", this.text.trim());
        } }
        onExited: (code, status) => {
            console.log("[EasyEffects] preset proc exited", code, status);
            HostServices.Equalizer.refresh();
        }
    }

    function cyclePreset(step = 1) {
        const names = Array.from(root.devicePresets);
        if (names.length === 0)
            return;
        const index = names.indexOf(root.outputPreset);
        const next = index === -1
            ? (step >= 0 ? names[0] : names[names.length - 1])
            : names[((index + step) % names.length + names.length) % names.length];
        root.loadPreset(next);
    }

    // The equalizer refreshes itself off its state file; a held surface has
    // nothing to poll, the key just keeps the old hold-bookkeeping honest.
    function hold(key: string, on: bool) {
        const next = Object.assign({}, root._holds);
        if (on)
            next[key] = true;
        else
            delete next[key];
        root._holds = next;
    }

    function refreshPresets() {
        HostServices.Equalizer.refresh();
    }
}
