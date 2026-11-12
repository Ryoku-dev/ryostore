pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import shell.services as Shell
import Ryoku.Ui.Singletons

// Live system state + services the island reacts to.
Singleton {
    id: root

    // ═══════════════════════════ CLOCK ═══════════════════════════
    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property date now: clock.date
    function pad2(n) { return (n < 10 ? "0" : "") + n; }
    // Qt's "h" is still 24-hour unless "AP" is in the format, so build the string by hand.
    function fmtClock(d, withSeconds, ampm) {
        if (!d) return "";
        const h = d.getHours();
        let s = Config.s.use24h ? pad2(h) : String(h % 12 || 12);
        s += ":" + pad2(d.getMinutes());
        if (withSeconds) s += ":" + pad2(d.getSeconds());
        if (!Config.s.use24h && (ampm ?? Config.s.showAmPm)) s += h < 12 ? " AM" : " PM";
        return s;
    }
    function hourLabel(h) {
        h = ((h % 24) + 24) % 24;
        return Config.s.use24h ? pad2(h) : (h % 12 || 12) + (h < 12 ? "AM" : "PM");
    }
    readonly property string clockText: fmtClock(now, false)
    readonly property string clockTextSec: fmtClock(now, Config.s.showSeconds)
    readonly property string ampm: Config.s.use24h ? "" : (now.getHours() < 12 ? "AM" : "PM")
    readonly property bool isNight: now.getHours() < 6 || now.getHours() >= 19
    readonly property string greeting: {
        const h = now.getHours();
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : h < 22 ? "Good evening" : "Good night";
    }
    function fmtTime(sec) {
        sec = Math.max(0, Math.floor(sec || 0));
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
        return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // ═══════════════════════ ISLAND STATE ════════════════════════
    property bool expanded: false
    property string expandedScreen: ""
    property int tab: 0
    property bool settingsOpen: false

    function focusedScreen() {
        if (Wm.focusedOutput !== "") return Wm.focusedOutput;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }
    function openTab(screenName, t) {
        Notifs.centerOpen = false;
        expandedScreen = screenName || focusedScreen();
        if (t >= 0) tab = t;
        clearEvent();
        expanded = true;
    }
    function toggle(screenName) {
        if (expanded) expanded = false;
        else openTab(screenName, -1);
    }
    function openSettings() { expanded = false; Notifs.centerOpen = false; settingsOpen = true; }

    // ── Launcher (Super+Space): the island morphs into a search field ──
    property bool launcherOpen: false
    property string launcherScreen: ""
    function openLauncher(screenName) {
        expanded = false;
        Notifs.centerOpen = false;
        clearEvent();
        launcherScreen = screenName || focusedScreen();
        launcherOpen = true;
    }
    function closeLauncher() { launcherOpen = false; }
    function toggleLauncher() { if (launcherOpen) closeLauncher(); else openLauncher(""); }

    // ═════════════════ TRANSIENT EVENTS (OSD etc.) ═══════════════
    property string event: ""        // "", "osd", "workspace", "device"
    property string eventIcon: ""
    property string eventLabel: ""
    property string eventSub: ""
    property real eventValue: -1     // 0..1 shows a bar, -1 shows the label
    property color eventColor: "white"
    property bool eventTinted: false
    property int eventSerial: 0
    property bool armed: false
    Timer { interval: 2500; running: true; onTriggered: root.armed = true }
    Timer { id: eventTimer; onTriggered: root.event = "" }

    function flash(kind, icon, label, value, color, ms, sub) {
        // The shell draws its own volume/mic/brightness OSD; the island's pills
        // are opt-in so exactly one of each paints out of the box.
        if (kind === "osd" && !Config.s.osdPopups) return;
        if (!armed) return;
        eventIcon = icon ?? "";
        eventLabel = label ?? "";
        eventSub = sub ?? "";
        eventValue = (value === undefined || value === null) ? -1 : value;
        eventTinted = color !== undefined && color !== null;
        eventColor = eventTinted ? color : Theme.fg;
        event = kind;
        eventSerial++;
        eventTimer.interval = ms ?? Config.s.osdTimeout;
        eventTimer.restart();
    }
    function clearEvent() { eventTimer.stop(); event = ""; }
    function holdEvent(hold) {
        if (event === "") return;
        if (hold) eventTimer.stop(); else eventTimer.restart();
    }

    // ═══════════════════════════ MEDIA ═══════════════════════════
    property MprisPlayer pinnedPlayer: null
    // The player that most recently *started* playing. After you pause it stays the
    // target, so play/pause resumes your music instead of whatever paused tab
    // (e.g. a Brave video) happens to be first on the bus.
    property MprisPlayer lastPlayer: null
    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: {
        const ps = players;
        if (pinnedPlayer && ps.indexOf(pinnedPlayer) >= 0) return pinnedPlayer;
        const last = lastPlayer && ps.indexOf(lastPlayer) >= 0 ? lastPlayer : null;
        if (last && last.isPlaying) return last;
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i];
        if (last) return last;
        return ps.length > 0 ? ps[0] : null;
    }
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() {
                if (!modelData.isPlaying) return;
                root.lastPlayer = modelData;
                // a different player starting overrides a manual pick from the switcher
                if (root.pinnedPlayer && root.pinnedPlayer !== modelData) root.pinnedPlayer = null;
            }
            Component.onCompleted: if (modelData.isPlaying && !root.lastPlayer) root.lastPlayer = modelData
        }
    }
    function playPause() { if (player) player.togglePlaying(); }
    function pausePlayer() { if (player && player.isPlaying && player.canPause) player.pause(); }
    function nextTrack() { if (player && player.canGoNext) player.next(); }
    function prevTrack() { if (player && player.canGoPrevious) player.previous(); }
    readonly property bool playing: player !== null && player.isPlaying
    readonly property real progress: player && player.length > 0
        ? Math.max(0, Math.min(1, player.position / player.length)) : 0
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""

    Timer {
        running: root.playing; interval: 500; repeat: true
        onTriggered: root.player.positionChanged()
    }
    // keep the media activity around briefly after pausing, like iOS
    property bool mediaLinger: false
    Timer { id: lingerTimer; interval: 45000; onTriggered: root.mediaLinger = false }
    onPlayingChanged: { if (!playing && player) { mediaLinger = true; lingerTimer.restart(); } }

    property bool trackFlash: false
    Timer { id: trackFlashTimer; interval: 3400; onTriggered: root.trackFlash = false }
    Connections {
        target: root.player
        function onTrackTitleChanged() {
            if (!root.armed || !Config.s.trackChangePeek || !root.player || root.player.trackTitle === "") return;
            root.trackFlash = true;
            trackFlashTimer.restart();
        }
    }
    function cycleLoop(p) {
        if (!p || !p.loopSupported) return;
        if (p.loopState === MprisLoopState.None) p.loopState = MprisLoopState.Playlist;
        else if (p.loopState === MprisLoopState.Playlist) p.loopState = MprisLoopState.Track;
        else p.loopState = MprisLoopState.None;
    }

    // Album colour
    ColorQuantizer {
        id: quantizer
        source: root.artUrl
        depth: 3
        rescaleSize: 64
    }
    readonly property var albumPick: {
        const cs = quantizer.colors;
        if (!player || !cs || cs.length === 0) return null;
        let best = null, score = -1;
        for (let i = 0; i < cs.length; i++) {
            const c = cs[i];
            const s = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.55));
            if (s > score) { score = s; best = c; }
        }
        return best && best.hslSaturation >= 0.15 ? best : null;
    }
    readonly property bool albumColorValid: albumPick !== null
    readonly property color albumColor: albumPick ?? "#0a84ff"

    // Visualizer (cava, fake fallback)
    property bool cavaAvailable: false
    property var bars: []
    Process {
        running: true
        command: ["sh", "-c", "command -v cava"]
        onExited: code => root.cavaAvailable = code === 0
    }
    readonly property string cavaConf:
        "[general]\nbars = 16\nframerate = 60\nautosens = 1\nsleep_timer = 3\n" +
        "[input]\nmethod = pulse\nsource = auto\n" +
        "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\n" +
        "ascii_max_range = 100\nbar_delimiter = 59\nframe_delimiter = 10\n" +
        "[smoothing]\nnoise_reduction = 55\n"
    Process {
        running: Config.s.visualizer && root.cavaAvailable && root.playing
        command: ["sh", "-c",
            "f=\"${XDG_RUNTIME_DIR:-/tmp}/qs-island-cava.conf\"; printf '%s' \"$1\" > \"$f\" && exec cava -p \"$f\"",
            "sh", root.cavaConf]
        stdout: SplitParser {
            onRead: data => {
                const out = [];
                const parts = data.split(";");
                for (let i = 0; i < parts.length; i++) if (parts[i] !== "") out.push(Number(parts[i]));
                root.bars = out;
            }
        }
        onRunningChanged: if (!running) root.bars = []
    }
    Timer {
        interval: 110; repeat: true
        running: Config.s.visualizer && !root.cavaAvailable && root.playing
        onTriggered: {
            const a = [];
            for (let i = 0; i < 16; i++) a.push(15 + Math.random() * 80);
            root.bars = a;
        }
        onRunningChanged: if (!running) root.bars = []
    }

    // ═══════════════════════════ AUDIO ═══════════════════════════
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source].filter(n => n !== null) }

    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    readonly property string volumeIcon:
        (muted || volume <= 0.001) ? "volume_off" : volume < 0.34 ? "volume_mute" : volume < 0.67 ? "volume_down" : "volume_up"
    readonly property string sinkName: sink ? (sink.description || sink.nickname || sink.name) : ""
    function sinkIcon() {
        const n = (sink ? sink.name : "").toLowerCase();
        if (n.includes("bluez")) return "headphones";
        if (n.includes("hdmi")) return "tv";
        if (n.includes("usb")) return "headset_mic";
        return "speaker";
    }
    function setVolume(v) {
        if (!sink || !sink.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted; }
    function toggleMic() { if (source && source.audio) source.audio.muted = !source.audio.muted; }

    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() { root.flash("osd", root.volumeIcon, "Volume", root.muted ? 0 : root.volume); }
        function onMutedChanged() { root.flash("osd", root.volumeIcon, root.muted ? "Muted" : "Volume", root.muted ? 0 : root.volume); }
    }
    Connections {
        target: root.source ? root.source.audio : null
        function onMutedChanged() {
            root.flash("osd", root.micMuted ? "mic_off" : "mic", root.micMuted ? "Microphone Off" : "Microphone On", -1,
                       root.micMuted ? Theme.red : Theme.green);
        }
    }
    onSinkChanged: if (sink) flash("osd", sinkIcon(), sinkName, -1, null, 2200)

    // ═════════════════════════ BRIGHTNESS ════════════════════════
    property bool hasBacklight: false
    property real brightness: 0
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -1"]
        stdout: StdioCollector { onStreamFinished: root.hasBacklight = this.text.trim() !== "" }
    }
    Process {
        id: brightRead
        property bool osd: false
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split(",");
                if (f.length < 4) return;
                root.brightness = parseInt(f[3]) / 100;
                if (brightRead.osd)
                    root.flash("osd", root.brightness < 0.5 ? "brightness_5" : "brightness_7", "Brightness", root.brightness, Theme.yellow);
            }
        }
    }
    function showBrightness() { brightRead.osd = true; brightRead.running = true; }
    function refreshBrightness() { brightRead.osd = false; brightRead.running = true; }
    function setBrightness(v) {
        brightness = Math.max(0.01, Math.min(1, v));
        Quickshell.execDetached(["brightnessctl", "-q", "s", Math.round(brightness * 100) + "%"]);
    }

    // ═════════════════════════ WORKSPACES ════════════════════════
    // The neutral Wm facade reports workspace identity as provider-defined
    // names; the island orders them by index and numbers the dots.
    readonly property var wsList: Wm.workspaces || []
    readonly property var focusedWs: Wm.focusedWorkspace
    readonly property int wsId: focusedWs && typeof focusedWs.index === "number"
        ? focusedWs.index : 1
    readonly property var occupied: wsList.filter(w => !w.special && (w.windows || 0) > 0)
        .map(w => typeof w.index === "number" ? w.index : 0).filter(i => i > 0)
    readonly property int wsCount: Math.min(10, Math.max(5, wsId, ...occupied))
    onWsIdChanged: if (Config.s.workspaceFlash && wsId > 0) flash("workspace", "", "Desktop " + wsId, -1, null, 1100)

    readonly property var activeWindow: ToplevelManager.activeToplevel
    readonly property string activeTitle: activeWindow ? activeWindow.title : ""
    readonly property string activeAppId: activeWindow ? activeWindow.appId : ""
    function appIcon(id) {
        if (!id) return "";
        const e = DesktopEntries.byId(id) ?? DesktopEntries.byId(id.toLowerCase());
        return Quickshell.iconPath(e ? e.icon : id.toLowerCase(), true);
    }
    readonly property string activeIcon: appIcon(activeAppId)
    readonly property string activeName: {
        const id = activeAppId;
        if (!id) return "";
        const e = DesktopEntries.byId(id) ?? DesktopEntries.byId(id.toLowerCase());
        return e ? e.name : id;
    }

    // ═════════════════════════ BATTERY ═══════════════════════════
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery
    readonly property real batPct: {
        if (!battery) return 0;
        const p = battery.percentage;
        return p > 1 ? p / 100 : p;
    }
    readonly property bool batCharging: hasBattery && !UPower.onBattery
    readonly property string batteryIcon: {
        if (batCharging) return "battery_charging_full";
        if (batPct > 0.95) return "battery_full";
        return "battery_" + Math.max(0, Math.min(6, Math.floor(batPct * 7))) + "_bar";
    }
    property bool lowWarned: false
    Connections {
        target: UPower
        function onOnBatteryChanged() {
            if (!root.hasBattery) return;
            if (UPower.onBattery) root.flash("osd", root.batteryIcon, "On Battery", root.batPct, null, 2200);
            else root.flash("osd", "bolt", "Charging", root.batPct, Theme.green, 2600);
        }
    }
    onBatPctChanged: {
        if (!hasBattery) return;
        if (UPower.onBattery && batPct <= 0.15 && !lowWarned) {
            lowWarned = true;
            flash("osd", "battery_alert", "Low Battery", batPct, Theme.red, 4500);
        } else if (batPct > 0.2) lowWarned = false;
    }

    // ═════════════════════════ BLUETOOTH ═════════════════════════
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter !== null && btAdapter.enabled
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)
    property var btSeen: []
    function btIcon(icon) {
        const i = (icon || "").toLowerCase();
        if (i.includes("headset") || i.includes("headphone") || i.includes("audio-card")) return "headphones";
        if (i.includes("gaming") || i.includes("joystick")) return "stadia_controller";
        if (i.includes("keyboard")) return "keyboard";
        if (i.includes("mouse")) return "mouse";
        if (i.includes("phone")) return "smartphone";
        if (i.includes("watch")) return "watch";
        if (i.includes("speaker") || i.includes("audio")) return "speaker";
        return "bluetooth";
    }
    property var eventDevice: null
    onBtConnectedChanged: {
        const addrs = btConnected.map(d => d.address);
        if (armed) {
            for (let i = 0; i < btConnected.length; i++) {
                const d = btConnected[i];
                if (btSeen.indexOf(d.address) < 0) {
                    eventDevice = d;
                    flash("device", btIcon(d.icon), d.name || d.deviceName, d.batteryAvailable ? d.battery : -1, null, 3200, "Connected");
                }
            }
        }
        btSeen = addrs;
    }
    function toggleBt() { if (btAdapter) btAdapter.enabled = !btAdapter.enabled; }
    function setBt(on) { if (btAdapter) btAdapter.enabled = on; }
    readonly property string btSub: !btOn ? "Off" : btConnected.length === 1 ? (btConnected[0].name || btConnected[0].deviceName)
                                    : btConnected.length > 1 ? btConnected.length + " Devices" : "On"

    // device lists for the Bluetooth menu
    function btNamed(d) { const n = d.name || d.deviceName || ""; return n !== "" && !/^([0-9a-f]{2}[-:]){5}[0-9a-f]{2}$/i.test(n); }
    readonly property var btPaired: Bluetooth.devices.values.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || String(a.name).localeCompare(String(b.name)))
    readonly property var btOthers: Bluetooth.devices.values.filter(d => !d.paired && !d.bonded && btNamed(d))
        .sort((a, b) => String(a.name).localeCompare(String(b.name)))
    readonly property bool btScanning: btAdapter !== null && btAdapter.discovering
    function btScan(on) { if (btAdapter && btAdapter.enabled) btAdapter.discovering = on; }
    function btState(d) {
        if (!d) return "";
        if (btPendingAddr === d.address && !d.paired) return "Pairing…";
        if (d.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        if (d.connected) return d.batteryAvailable ? "Connected · " + Math.round(d.battery * 100) + "%" : "Connected";
        return d.paired ? "Not Connected" : "";
    }
    property string btPendingAddr: ""
    property var btPending: null
    property string btError: ""
    function btActivate(d) {
        if (!d) return;
        btError = "";
        if (d.connected) { d.disconnect(); return; }
        if (d.paired) { d.connect(); return; }
        // pair → trust → connect
        btPending = d;
        btPendingAddr = d.address;
        d.trusted = true;
        d.pair();
        btPairWatch.ticks = 0;
        btPairWatch.start();
    }
    function btForget(d) { if (d) d.forget(); }
    Timer {
        id: btPairWatch
        property int ticks: 0
        interval: 500; repeat: true
        onTriggered: {
            const d = root.btPending;
            ticks++;
            if (!d) { stop(); return; }
            if (d.paired) { stop(); d.trusted = true; d.connect(); root.btPendingAddr = ""; root.btPending = null; return; }
            if (ticks > 60 || (ticks > 4 && !d.pairing)) {
                stop();
                root.btError = "Couldn't pair with " + (d.name || "the device") + ". Put it in pairing mode and try again.";
                root.btPendingAddr = ""; root.btPending = null;
            }
        }
    }
    readonly property var batteryDevices: {
        const out = [];
        if (hasBattery) out.push({ icon: "laptop", name: "This device", level: batPct, charging: batCharging });
        const ds = btConnected;
        for (let i = 0; i < ds.length; i++)
            if (ds[i].batteryAvailable) out.push({ icon: btIcon(ds[i].icon), name: ds[i].name || ds[i].deviceName, level: ds[i].battery, charging: false });
        return out;
    }

    // ═══════════════════════════ PRIVACY + SCREEN RECORDING ══════════════════
    // Ryoku owns recording: the shell's Recorder service tracks the active
    // session, so the island mirrors it instead of pgrep-ing recorders.
    property bool micInUse: false
    property bool camInUse: false
    property int recordSeconds: 0
    readonly property bool recording: Shell.Recorder.anyActive
    Process {
        id: privacyProc
        command: ["sh", "-c",
            "m=0; c=0; " +
            "n=$(pactl list source-outputs 2>/dev/null | grep 'application.process.binary' | grep -vc '\"cava\"'); " +
            "[ \"${n:-0}\" -gt 0 ] && m=1; " +
            "find /proc/[0-9]*/fd -lname '/dev/video*' -print -quit 2>/dev/null | grep -q . && c=1; " +
            "echo \"$m $c\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(" ");
                root.micInUse = p[0] === "1";
                root.camInUse = p[1] === "1";
            }
        }
    }
    Timer { interval: 3000; repeat: true; triggeredOnStart: true; running: true; onTriggered: privacyProc.running = true }
    Timer { interval: 1000; repeat: true; running: root.recording; onTriggered: root.recordSeconds++ }
    Connections {
        target: Shell.Recorder
        function onAnyActiveChanged() {
            if (Shell.Recorder.anyActive) {
                root.recordSeconds = 0;
                root.flash("osd", "radio_button_checked", "Screen Recording", -1, Theme.red, 2000);
            } else root.flash("osd", "stop_circle", "Recording Saved", -1, null, 2000);
        }
    }
    function stopRecording() { Shell.Recorder.stop(); }

    // ═════════════════════ LOCATION + WEATHER ════════════════════
    // Location: GeoClue (Wi-Fi positioning, precise) → IP geolocation → or a city you pick.
    // Weather: Open-Meteo (no key needed).
    property real locLat: NaN
    property real locLon: NaN
    property string locName: ""
    property string locSource: ""        // "Wi-Fi (GeoClue)" | "IP address" | "Manual"
    property real locAccuracy: -1        // metres, GeoClue only
    property string locStatus: "Locating…"
    readonly property bool hasLocation: !isNaN(locLat) && !isNaN(locLon)

    function resolveLocation() {
        if (!Config.s.weather) return;
        const mode = Config.s.locationMode;
        if (mode === "manual" && Config.s.manualName !== "") {
            locLat = Config.s.manualLat; locLon = Config.s.manualLon;
            locName = Config.s.manualName; locSource = "Manual"; locAccuracy = -1;
            locStatus = "";
            fetchWeather();
            return;
        }
        locStatus = "Locating…";
        if (mode === "auto") {
            if (geoProc.running) return;
            geoProc.lat = NaN; geoProc.lon = NaN; geoProc.acc = -1; geoProc.handled = false;
            geoProc.running = true;
        } else ipProc.running = true;
    }
    function useGeo(lat, lon, acc) {
        // Ignore coarse fixes (> 25 km) — the IP lookup is usually as good then.
        if (isNaN(lat) || isNaN(lon) || acc > 25000) { ipProc.running = true; return; }
        locLat = lat; locLon = lon; locAccuracy = acc;
        locSource = "Wi-Fi (GeoClue)";
        locStatus = "";
        revProc.running = true;
        fetchWeather();
    }

    // GeoClue demo client: prints Latitude/Longitude/Accuracy once it has a fix.
    Process {
        id: geoProc
        property real lat: NaN
        property real lon: NaN
        property real acc: -1
        property bool handled: false
        command:["sh", "-c",
            "for p in /usr/lib/geoclue-2.0/demos/where-am-i /usr/libexec/geoclue-2.0/demos/where-am-i; do " +
            "[ -x \"$p\" ] && exec timeout 14 \"$p\" -t 12 -a 8; done; exit 127"]
        stdout: SplitParser {
            onRead: l => {
                const m = l.match(/^\s*(Latitude|Longitude|Accuracy):\s*(-?[0-9.]+)/);
                if (!m) return;
                const v = parseFloat(m[2]);
                if (m[1] === "Latitude") geoProc.lat = v;
                else if (m[1] === "Longitude") geoProc.lon = v;
                else geoProc.acc = v;
                if (!geoProc.handled && !isNaN(geoProc.lat) && !isNaN(geoProc.lon) && geoProc.acc >= 0) {
                    geoProc.handled = true;
                    root.useGeo(geoProc.lat, geoProc.lon, geoProc.acc);
                    geoProc.running = false;
                }
            }
        }
        onExited: {
            if (handled) return;
            handled = true;
            root.useGeo(lat, lon, acc);
        }
    }
    Process {
        id: ipProc
        command: ["sh", "-c",
            "curl -sf --max-time 8 https://ipinfo.io/json || curl -sf --max-time 8 https://ipapi.co/json/ || curl -sf --max-time 8 http://ip-api.com/json/"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    let lat = NaN, lon = NaN;
                    if (j.loc) { const p = j.loc.split(","); lat = parseFloat(p[0]); lon = parseFloat(p[1]); }
                    else if (j.latitude !== undefined) { lat = j.latitude; lon = j.longitude; }
                    else if (j.lat !== undefined) { lat = j.lat; lon = j.lon; }
                    if (isNaN(lat) || isNaN(lon)) throw "no coords";
                    root.locLat = lat; root.locLon = lon; root.locAccuracy = -1;
                    const region = j.region || j.regionName || "";
                    root.locName = [j.city, region].filter(x => x && x !== "").join(", ");
                    root.locSource = "IP address";
                    root.locStatus = "";
                    root.fetchWeather();
                } catch (e) { root.locStatus = "Couldn't find your location. Set it manually in Settings → Weather."; }
            }
        }
    }
    // Reverse-geocode GeoClue coordinates to a place name
    Process {
        id: revProc
        command: ["sh", "-c",
            "curl -sf --max-time 8 \"https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$1&longitude=$2&localityLanguage=en\"",
            "sh", String(root.locLat), String(root.locLon)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    const place = j.city || j.locality || "";
                    root.locName = [place, j.principalSubdivision].filter(x => x && x !== "").join(", ") || root.locName;
                } catch (e) {}
            }
        }
    }

    // City search for Settings
    property var locResults: []
    property bool locSearching: false
    Process {
        id: geoSearch
        property string q: ""
        command: ["sh", "-c",
            "curl -sf --max-time 8 \"https://geocoding-api.open-meteo.com/v1/search?count=8&language=en&format=json&name=$1\"",
            "sh", encodeURIComponent(q)]
        stdout: StdioCollector {
            onStreamFinished: {
                root.locSearching = false;
                try {
                    const j = JSON.parse(this.text);
                    root.locResults = (j.results || []).map(r => ({
                        name: r.name, region: [r.admin1, r.country].filter(x => x).join(", "),
                        lat: r.latitude, lon: r.longitude
                    }));
                } catch (e) { root.locResults = []; }
            }
        }
    }
    function searchLocation(q) {
        q = (q || "").trim();
        if (q.length < 2) { locResults = []; return; }
        geoSearch.q = q;
        locSearching = true;
        geoSearch.running = true;
    }
    function setManualLocation(r) {
        Config.s.manualLat = r.lat;
        Config.s.manualLon = r.lon;
        Config.s.manualName = r.name + (r.region ? ", " + r.region.split(", ")[0] : "");
        Config.s.locationMode = "manual";
        locResults = [];
        resolveLocation();
    }

    // ── Weather ──
    property string wTemp: ""
    property string wDesc: ""
    property string wHigh: ""
    property string wLow: ""
    property string wFeels: ""
    property int wHumidity: 0
    property bool wIsDay: true
    property var wHourly: []
    readonly property string wPlace: locName
    readonly property bool wImperial: Config.s.units === "imperial"
    readonly property string weatherTemp: wTemp
    readonly property string weatherDesc: wDesc

    readonly property var wmo: ({
        0: "Clear", 1: "Mostly Clear", 2: "Partly Cloudy", 3: "Cloudy", 45: "Fog", 48: "Fog",
        51: "Light Drizzle", 53: "Drizzle", 55: "Heavy Drizzle", 56: "Freezing Drizzle", 57: "Freezing Drizzle",
        61: "Light Rain", 63: "Rain", 65: "Heavy Rain", 66: "Freezing Rain", 67: "Freezing Rain",
        71: "Light Snow", 73: "Snow", 75: "Heavy Snow", 77: "Snow Grains",
        80: "Showers", 81: "Rain Showers", 82: "Heavy Showers", 85: "Snow Showers", 86: "Snow Showers",
        95: "Thunderstorm", 96: "Thunderstorm", 99: "Thunderstorm"
    })
    Process {
        id: weatherProc
        command: ["sh", "-c",
            "curl -sf --max-time 12 \"https://api.open-meteo.com/v1/forecast?latitude=$1&longitude=$2" +
            "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day" +
            "&hourly=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min" +
            "&timezone=auto&forecast_days=2$3\"",
            "sh", String(root.locLat), String(root.locLon), root.wImperial ? "&temperature_unit=fahrenheit" : ""]
        stdout: StdioCollector { onStreamFinished: root.parseWeather(this.text) }
    }
    function fetchWeather() { if (hasLocation && Config.s.weather) weatherProc.running = true; }
    function parseWeather(t) {
        try {
            const j = JSON.parse(t);
            const c = j.current;
            wTemp = Math.round(c.temperature_2m) + "°";
            wFeels = Math.round(c.apparent_temperature) + "°";
            wHumidity = Math.round(c.relative_humidity_2m);
            wDesc = wmo[c.weather_code] || "—";
            wIsDay = c.is_day === 1;
            wHigh = Math.round(j.daily.temperature_2m_max[0]) + "°";
            wLow = Math.round(j.daily.temperature_2m_min[0]) + "°";
            // hourly: start at the location's current hour (times are local to the location)
            const cur = String(c.time).slice(0, 13);
            const ts = j.hourly.time;
            let i0 = 0;
            for (let i = 0; i < ts.length; i++) if (String(ts[i]).slice(0, 13) >= cur) { i0 = i; break; }
            const hours = [];
            for (let i = i0; i < Math.min(ts.length, i0 + 6); i++) {
                const hh = parseInt(String(ts[i]).slice(11, 13));
                hours.push({
                    label: i === i0 ? "Now" : hourLabel(hh),
                    temp: Math.round(j.hourly.temperature_2m[i]) + "°",
                    desc: wmo[j.hourly.weather_code[i]] || "",
                    night: j.hourly.is_day[i] === 0
                });
            }
            wHourly = hours;
        } catch (e) {}
    }
    Timer {   // weather every 20 min
        interval: 1200000; repeat: true
        running: Config.s.weather && root.hasLocation
        onTriggered: root.fetchWeather()
    }
    Timer {   // re-locate every 2 h (you may have moved), and once at start
        interval: 7200000; repeat: true; triggeredOnStart: true
        running: Config.s.weather
        onTriggered: root.resolveLocation()
    }
    function refreshWeather() { resolveLocation(); }
    Connections {
        target: Config.s
        function onLocationModeChanged() { weatherDebounce.restart(); }
        function onUnitsChanged() { weatherDebounce.restart(); }
        function onWeatherChanged() { weatherDebounce.restart(); }
    }
    Timer { id: weatherDebounce; interval: 600; onTriggered: root.resolveLocation() }

    function weatherSymbol(d, night) {
        d = (d || "").toLowerCase();
        const n = night ?? !wIsDay;
        if (d.includes("thunder")) return "thunderstorm";
        if (d.includes("snow") || d.includes("sleet") || d.includes("ice") || d.includes("blizzard")) return "weather_snowy";
        if (d.includes("rain") || d.includes("drizzle") || d.includes("shower")) return "rainy";
        if (d.includes("fog") || d.includes("mist") || d.includes("haze")) return "foggy";
        if (d.includes("partly")) return n ? "partly_cloudy_night" : "partly_cloudy_day";
        if (d.includes("cloud") || d.includes("overcast")) return "cloud";
        return n ? "clear_night" : "sunny";
    }
    function weatherColor(d, night) {
        const s = weatherSymbol(d, night);
        if (s === "sunny") return Theme.yellow;
        if (s === "clear_night" || s === "partly_cloudy_night") return "#c7c9ff";
        if (s === "rainy" || s === "thunderstorm") return Theme.teal;
        return Theme.fg;
    }

    // ═══════════════════════ SYSTEM STATS ════════════════════════
    property real cpu: 0
    property real mem: 0
    property real disk: 0
    property real memUsedGb: 0
    property real memTotalGb: 0
    property string uptime: ""
    property var lastCpu: null
    Process {
        id: statProc
        command: ["sh", "-c",
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; " +
            "echo \"DISK $(df -P / | awk 'NR==2{print $5}')\"; echo \"UP $(cut -d' ' -f1 /proc/uptime)\""]
        stdout: StdioCollector { onStreamFinished: root.parseStats(this.text) }
    }
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: root.expanded
        onTriggered: statProc.running = true
    }
    function parseStats(t) {
        const lines = t.trim().split("\n");
        if (lines.length < 3) return;
        const c = lines[0].trim().split(/\s+/).slice(1).map(Number);
        const idle = c[3] + (c[4] || 0);
        const total = c.reduce((a, b) => a + b, 0);
        if (lastCpu) {
            const dt = total - lastCpu.t, di = idle - lastCpu.i;
            if (dt > 0) cpu = Math.max(0, Math.min(1, 1 - di / dt));
        }
        lastCpu = { t: total, i: idle };
        let mt = 0, ma = 0;
        for (let i = 1; i < lines.length; i++) {
            const l = lines[i];
            if (l.startsWith("MemTotal")) mt = parseInt(l.split(/\s+/)[1]);
            else if (l.startsWith("MemAvailable")) ma = parseInt(l.split(/\s+/)[1]);
            else if (l.startsWith("DISK")) disk = (parseInt(l.split(" ")[1]) || 0) / 100;
            else if (l.startsWith("UP")) {
                const s = parseFloat(l.split(" ")[1]) || 0;
                const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
                uptime = d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m";
            }
        }
        if (mt > 0) { mem = 1 - ma / mt; memTotalGb = mt / 1048576; memUsedGb = (mt - ma) / 1048576; }
    }

    // ═══════════════════════ QUICK TOGGLES ═══════════════════════
    property bool wifiOn: false
    property string netName: ""
    property string netType: ""
    property bool caffeine: false
    property bool nightLight: false
    readonly property bool wiredUp: netType === "802-3-ethernet" || netType === "ethernet"
    readonly property string wifiSub: !wifiOn ? (wiredUp ? "Ethernet" : "Off")
                                     : (netType === "802-11-wireless" && netName !== "") ? netName
                                     : wiredUp ? "Ethernet" : "Not Connected"
    Process {
        id: netProc
        command: ["sh", "-c",
            "echo \"W:$(nmcli radio wifi 2>/dev/null)\"; " +
            "echo \"N:$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vE ':(loopback|bridge|tun|wireguard|vpn)$' | head -1)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const l = lines[i];
                    if (l.startsWith("W:")) root.wifiOn = l.slice(2).trim() === "enabled";
                    else if (l.startsWith("N:")) {
                        const f = root.nmSplit(l.slice(2).trim());
                        root.netName = f.length > 1 ? f.slice(0, -1).join(":") : (f[0] || "");
                        root.netType = f.length > 1 ? f[f.length - 1] : "";
                    }
                }
            }
        }
    }
    Timer {
        interval: 5000; repeat: true; triggeredOnStart: true
        running: root.expanded || root.settingsOpen
        onTriggered: { netProc.running = true; if (root.hasBacklight) root.refreshBrightness(); }
    }
    Timer { id: netRefresh; interval: 1500; onTriggered: { netProc.running = true; if (root.wifiMenuOpen) wifiList.running = true; } }
    function toggleWifi() { setWifi(!wifiOn); }
    function setWifi(on) {
        wifiOn = on;
        if (!on) wifiNetworks = [];
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        netRefresh.restart();
    }

    // ── Wi-Fi menu ──
    // nmcli -t escapes ':' inside fields as '\:'
    function nmSplit(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) { cur += line[++i]; continue; }
            if (ch === ":") { out.push(cur); cur = ""; continue; }
            cur += ch;
        }
        out.push(cur);
        return out;
    }
    // Control Center drill-down page: "" | "wifi" | "bt"
    property string ccPage: ""
    readonly property bool wifiMenuOpen: ccPage === "wifi" && expanded && tab === 2
    readonly property bool btMenuOpen: ccPage === "bt" && expanded && tab === 2
    onBtMenuOpenChanged: btScan(btMenuOpen)
    onExpandedChanged: { if (!expanded) ccPage = ""; else launcherOpen = false; }
    function openCC(page, screenName) { ccPage = page; openTab(screenName, 2); }
    property var wifiNetworks: []        // [{ssid, signal, secure, active, known}]
    property var wifiKnown: []
    property bool wifiScanning: false
    property string wifiBusy: ""          // SSID being joined
    property string wifiError: ""
    property string wifiNeedsPassword: "" // SSID that asked for a password
    Process {
        id: wifiList
        command: ["sh", "-c",
            "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no 2>/dev/null; echo '@@KNOWN'; " +
            "nmcli -t -f NAME,TYPE connection show 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                const known = [];
                const byName = {};
                let k = false;
                for (let i = 0; i < lines.length; i++) {
                    const l = lines[i];
                    if (l === "@@KNOWN") { k = true; continue; }
                    if (l.trim() === "") continue;
                    const f = root.nmSplit(l);
                    if (k) { if (f[f.length - 1] === "802-11-wireless") known.push(f.slice(0, -1).join(":")); continue; }
                    if (f.length < 4) continue;
                    const ssid = f.slice(3).join(":");
                    if (ssid === "") continue;   // hidden networks
                    const n = { ssid: ssid, signal: parseInt(f[1]) || 0, secure: f[2] !== "" && f[2] !== "--", active: f[0] === "*" };
                    const prev = byName[ssid];
                    if (!prev) byName[ssid] = n;
                    else { prev.active = prev.active || n.active; prev.signal = Math.max(prev.signal, n.signal); }
                }
                const list = [];
                for (const s in byName) { byName[s].known = known.indexOf(s) >= 0; list.push(byName[s]); }
                list.sort((a, b) => (b.active - a.active) || (b.known - a.known) || (b.signal - a.signal));
                root.wifiKnown = known;
                root.wifiNetworks = list;
                root.wifiScanning = false;
            }
        }
    }
    Process {
        id: wifiRescan
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: wifiListLater.restart()
    }
    Timer { id: wifiListLater; interval: 2200; onTriggered: wifiList.running = true }
    Timer {
        interval: 10000; repeat: true; triggeredOnStart: true
        running: root.wifiMenuOpen && root.wifiOn && root.expanded
        onTriggered: root.wifiScan()
    }
    function wifiScan() {
        if (!wifiOn) return;
        wifiScanning = true;
        wifiList.running = true;      // show cached results straight away
        wifiRescan.running = true;
    }
    Process {
        id: wifiJoin
        property string ssid: ""
        property bool wasKnown: false
        stdout: StdioCollector { id: joinOut }
        stderr: StdioCollector { id: joinErr }
        onExited: code => {
            root.wifiBusy = "";
            if (code === 0) {
                root.wifiError = "";
                root.wifiNeedsPassword = "";
                root.flash("osd", "wifi", ssid, -1, Theme.ccTint(Theme.blue), 1800, "Connected");
            } else {
                const msg = (joinErr.text + " " + joinOut.text).trim();
                const secrets = /secret|password|802-1x|psk|key-mgmt/i.test(msg);
                root.wifiNeedsPassword = secrets ? ssid : "";
                root.wifiError = secrets ? "Incorrect password for “" + ssid + "”" : (msg.replace(/^Error:\s*/, "") || "Couldn't join “" + ssid + "”");
                // don't leave a broken profile behind for a network we just tried
                if (!wasKnown) Quickshell.execDetached(["nmcli", "connection", "delete", "id", ssid]);
            }
            netRefresh.restart();
        }
    }
    function wifiConnect(net, password) {
        if (!net || wifiJoin.running) return;
        wifiError = "";
        if (net.active) return;
        if (net.secure && !net.known && !password) { wifiNeedsPassword = net.ssid; return; }
        wifiBusy = net.ssid;
        wifiJoin.ssid = net.ssid;
        wifiJoin.wasKnown = net.known;
        wifiJoin.command = net.known && !password
            ? ["nmcli", "-w", "25", "connection", "up", "id", net.ssid]
            : ["nmcli", "-w", "25", "device", "wifi", "connect", net.ssid].concat(password ? ["password", password] : []);
        wifiJoin.running = true;
    }
    function wifiDisconnect(net) {
        if (!net) return;
        Quickshell.execDetached(["nmcli", "connection", "down", "id", net.ssid]);
        netRefresh.restart();
    }
    function wifiForget(net) {
        if (!net) return;
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", net.ssid]);
        netRefresh.restart();
    }
    function signalIcon(s) {
        return s >= 75 ? "signal_wifi_4_bar" : s >= 50 ? "network_wifi_3_bar" : s >= 25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    // Caffeine is the shell's shared keep-awake flag, held by the host
    // inhibitor every Ryoku desktop ships, so the shell's own surfaces agree.
    readonly property bool caffeine: Shell.Flags.keepAwake
    function toggleCaffeine() { Shell.Flags.keepAwake = !Shell.Flags.keepAwake; }
    // Night Shift is the shell's Nightlight service (daemon-driven, works on
    // every compositor); the island just flips it with its own temperature.
    readonly property bool nightLight: Shell.Nightlight.on
    function toggleNightLight() {
        Shell.Nightlight.setEnabled(!Shell.Nightlight.on, Config.s.nightLightTemp);
        flash("osd", "nightlight", Shell.Nightlight.on ? "Night Shift" : "Night Shift Off", -1, null, 1800);
    }
    function applyNightLightTemp() {
        if (Shell.Nightlight.on) Shell.Nightlight.setTemperature(Config.s.nightLightTemp);
    }
    Connections {
        target: Config.s
        function onNightLightTempChanged() { root.applyNightLightTemp(); }
    }
    // ── Session actions: the shell's own SessionActions service ──
    // lock/suspend run the daemon's fail-closed `ryoku-shell lock|suspend`
    // (the same `ryoku-shell lock` the Super+L keybind runs on every compositor).
    // logout/reboot/shutdown are the daemon's session.* verbs.
    function session(action) {
        expanded = false;
        Shell.SessionActions.run(action);
    }

    function run(cmd, collapse) {
        if (collapse) expanded = false;
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
    function screenshot() {
        expanded = false;
        Shell.Capture.shoot("region");
    }
    function colorPick() { run("sleep 0.5; hyprpicker -a", true); }
    function openFirst(cmds) {
        run(cmds.map(c => "command -v " + c.split(" ")[0] + " >/dev/null && exec " + c).join("; ") + "; true", true);
    }

    // ═══════════════════ DEPENDENCY CHECK (Settings → About) ═════
    property var deps: ({})
    readonly property var depList: [
        { cmd: "nmcli", pkg: "networkmanager", what: "Wi-Fi toggle and network menu" },
        { cmd: "bluetoothctl", pkg: "bluez-utils", what: "Bluetooth (with the bluetooth service running)" },
        { cmd: "brightnessctl", pkg: "brightnessctl", what: "Display brightness" },
        { cmd: "cava", pkg: "cava (AUR)", what: "Real audio visualizer" },
        { cmd: "hyprpicker", pkg: "hyprpicker", what: "Colour picker" },
        { cmd: "paplay", pkg: "libpulse", what: "Notification sounds" },
        { cmd: "notify-send", pkg: "libnotify", what: "Test notification" },
        { cmd: "curl", pkg: "curl", what: "Weather and location" },
        { cmd: "pactl", pkg: "libpulse", what: "Microphone-in-use dot" },
        { cmd: "gsettings", pkg: "glib2", what: "GTK accent + dark mode sync" }
    ]
    Process {
        id: depProc
        command: ["sh", "-c", "for c in " + root.depList.map(d => d.cmd).join(" ") +
                  " where-am-i; do if [ \"$c\" = where-am-i ]; then ls /usr/lib/geoclue-2.0/demos/where-am-i /usr/libexec/geoclue-2.0/demos/where-am-i >/dev/null 2>&1 && echo \"$c 1\" || echo \"$c 0\"; " +
                  "else command -v \"$c\" >/dev/null && echo \"$c 1\" || echo \"$c 0\"; fi; done; " +
                  "true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = {};
                this.text.trim().split("\n").forEach(l => { const p = l.split(" "); d[p[0]] = p[1] === "1"; });
                root.deps = d;
            }
        }
    }
    function checkDeps() { depProc.running = true; }
    onSettingsOpenChanged: if (settingsOpen) checkDeps()

    // ═══════════════════ TIMER + STOPWATCH ═══════════════════════
    property int timerMode: 0
    property int timerSet: 300
    property int timerTotal: 300
    property int timerLeft: 0
    property bool timerRunning: false
    readonly property bool timerActive: timerRunning || timerLeft > 0
    Timer {
        interval: 1000; repeat: true
        running: root.timerRunning
        onTriggered: { root.timerLeft -= 1; if (root.timerLeft <= 0) root.timerDone(); }
    }
    function startTimer(s) { timerSet = s; timerTotal = s; timerLeft = s; timerRunning = true; }
    function timerToggle() {
        if (timerRunning) { timerRunning = false; return; }
        if (timerLeft <= 0) { timerTotal = timerSet; timerLeft = timerSet; }
        timerRunning = true;
    }
    function timerReset() { timerRunning = false; timerLeft = 0; }
    function timerDone() {
        timerRunning = false;
        timerLeft = 0;
        flash("osd", "alarm", "Timer Done", -1, Theme.orange, 7000);
        Quickshell.execDetached(["sh", "-c", "paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true"]);
    }

    property bool swRunning: false
    property real swAccum: 0
    property real swStart: 0
    property real swTick: 0
    readonly property real swElapsed: swRunning ? swAccum + (swTick - swStart) : swAccum
    readonly property bool swActive: swRunning || swAccum > 0
    Timer { interval: 33; repeat: true; running: root.swRunning; onTriggered: root.swTick = Date.now() }
    function swToggle() {
        if (swRunning) { swAccum += Date.now() - swStart; swRunning = false; }
        else { swStart = Date.now(); swTick = swStart; swRunning = true; }
    }
    function swReset() { swRunning = false; swAccum = 0; }
    function fmtSw(ms) {
        const cs = Math.floor(ms / 10) % 100;
        return fmtTime(ms / 1000) + "." + (cs < 10 ? "0" : "") + cs;
    }

    // ═══════════════════ LIVE ACTIVITIES (priority) ══════════════
    readonly property var activities: {
        const a = [];
        if (recording) a.push("recording");
        if (timerActive) a.push("timer");
        if (player && (playing || mediaLinger)) a.push("media");
        if (swActive) a.push("stopwatch");
        return a;
    }
    function openActivity(kind, screenName) {
        if (kind === "media") openTab(screenName, 1);
        else if (kind === "timer" || kind === "stopwatch") { timerMode = kind === "stopwatch" ? 1 : 0; openTab(screenName, 3); }
        else if (kind === "recording") stopRecording();
    }

    // ════════════════════ IPC + GLOBAL SHORTCUTS ═════════════════
    // qs -c island ipc call island <function> [args]
    IpcHandler {
        target: "island"
        function toggle(): void { root.toggle(""); }
        function open(tab: int): void { root.openTab("", tab); }
        function close(): void { root.expanded = false; Notifs.centerOpen = false; }
        function settings(): void { root.openSettings(); }
        function center(): void { Notifs.toggleCenter(); }
        function brightness(): void { root.showBrightness(); }
        function osd(icon: string, label: string, value: real): void { root.flash("osd", icon, label, value); }
        function dnd(): void { Notifs.toggleDnd(); }
        function timer(seconds: int): void { root.startTimer(seconds); }
        function launcher(): void { root.toggleLauncher(); }
        function playPause(): void { root.playPause(); }
        function pause(): void { root.pausePlayer(); }
        function next(): void { root.nextTrack(); }
        function previous(): void { root.prevTrack(); }
    }
    GlobalShortcut { name: "islandLauncher"; description: "App launcher in the island"; onPressed: root.toggleLauncher() }
    GlobalShortcut { name: "islandToggle"; description: "Toggle the dynamic island"; onPressed: root.toggle("") }
    GlobalShortcut { name: "islandCenter"; description: "Notification Center"; onPressed: Notifs.toggleCenter() }
    GlobalShortcut { name: "islandSettings"; description: "Island settings"; onPressed: root.openSettings() }
}
