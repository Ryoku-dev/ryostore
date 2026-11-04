pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import shell.services as HostServices
import "."
import "../modules/common"

// Adapter over the host's audio graph (shell.services Audio).
Singleton {
    id: root

    property bool ready: Pipewire.defaultAudioSink?.ready ?? false
    property PwNode sink: HostServices.Audio.sink
    property PwNode source: HostServices.Audio.source
    readonly property real hardMaxValue: 2.00
    property real value: 0
    property bool muted: false

    function friendlyDeviceName(node) {
        if (!node) return Translation.tr("Unknown");
        return (node.nickname || node.description || Translation.tr("Unknown"));
    }
    function appNodeDisplayName(node) {
        return (node.properties["application.name"] || node.description || node.name)
    }

    function correctType(node, isSink) {
        return (node.isSink === isSink) && node.audio
    }
    function isMultiOutputNode(node) {
        return false
    }
    function appNodes(isSink) {
        return (Pipewire.nodes?.values ?? []).filter((node) => {
            return root.correctType(node, isSink) && node.isStream && !root.isMultiOutputNode(node)
        })
    }
    function devices(isSink) {
        return (Pipewire.nodes?.values ?? []).filter(node => {
            return root.correctType(node, isSink) && !node.isStream && !root.isMultiOutputNode(node)
        })
    }
    readonly property list<var> outputAppNodes: root.appNodes(true)
    readonly property list<var> inputAppNodes: root.appNodes(false)
    readonly property list<var> outputDevices: root.devices(true)
    readonly property list<var> inputDevices: root.devices(false)

    signal sinkProtectionTriggered(string reason);

    function toggleMute() {
        if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
    }

    function toggleMicMute() {
        if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted
    }

    function incrementVolume() {
        if (!root.sink?.audio) return;
        const currentVolume = Audio.value;
        const step = currentVolume < 0.1 ? 0.01 : 0.02 || 0.2;
        Audio.sink.audio.volume = Math.min(1, Audio.sink.audio.volume + step);
    }

    function decrementVolume() {
        if (!root.sink?.audio) return;
        const currentVolume = Audio.value;
        const step = currentVolume < 0.1 ? 0.01 : 0.02 || 0.2;
        Audio.sink.audio.volume -= step;
    }

    function setDefaultSink(node) {
        HostServices.Audio.setOutput(node);
    }

    function setDefaultSource(node) {
        HostServices.Audio.setInput(node);
    }

    function routeStream(stream, sink) {
        const serial = stream?.properties["object.serial"];
        if (serial === undefined || !sink) return;
        Quickshell.execDetached(["pactl", "move-sink-input", String(serial), sink.name]);
    }

    function outputDeviceIcon(node) {
        if (!node) return "media_output";
        const name = node.name;
        const formFactor = node.properties["device.form-factor"] ?? "";
        if (name.startsWith("bluez_") || formFactor === "headphone" || formFactor === "headset") return "headphones";
        if (name.indexOf("hdmi") !== -1 || name.indexOf("HDMI") !== -1 || name.indexOf("DisplayPort") !== -1) return "tv";
        if (name === "easyeffects_sink") return "graphic_eq";
        return "speaker";
    }

    Connections { // Protection against sudden volume changes
        target: root.sink?.audio ?? null
        property bool lastReady: false
        property real lastVolume: 0
        function onVolumeChanged() {
            if (root.sink && root.sink.audio) {
                const oldValue = root.value;
                root.value = root.sink.audio.volume;
                if (!isNaN(root.value) && oldValue > 0 && Math.abs(root.value - oldValue) > 0.0001) {
                    SoundService.playEvent("volumeChange", "audio-volume-change");
                }
            }
            if (!Config.options.audio.protection.enable) return;
            const newVolume = root.sink.audio.volume;
            if (isNaN(newVolume) || newVolume === undefined || newVolume === null) {
                lastReady = false;
                lastVolume = 0;
                return;
            }
            if (!lastReady) {
                lastVolume = newVolume;
                lastReady = true;
                return;
            }
            const maxAllowedIncrease = Config.options.audio.protection.maxAllowedIncrease / 100;
            const maxAllowed = Config.options.audio.protection.maxAllowed / 100;

            if (newVolume - lastVolume > maxAllowedIncrease) {
                root.sink.audio.volume = lastVolume;
                root.sinkProtectionTriggered(Translation.tr("Illegal increment"));
            } else if (newVolume > maxAllowed || newVolume > root.hardMaxValue) {
                root.sinkProtectionTriggered(Translation.tr("Exceeded max allowed"));
                root.sink.audio.volume = Math.min(lastVolume, maxAllowed);
            }
            lastVolume = root.sink.audio.volume;
        }
        function onMutedChanged() {
            if (root.sink && root.sink.audio) {
                const wasMuted = root.muted;
                root.muted = root.sink.audio.muted;
                if (wasMuted && !root.muted) {
                    SoundService.playEvent("volumeChange", "audio-volume-change");
                }
            }
        }
    }
}
