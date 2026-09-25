pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Live weather for the MJW kit. Instead of end4's OpenWeather API key, this
// subscribes to the ryoku-shell daemon's `weather` topic (keyless Open-Meteo,
// IP geolocation, unit from the desktop's weather settings) and re-shapes the
// frame into the fields the ported illogical-impulse weather widget binds:
// data.{temp, tempFeelsLike, city, description, humidity, cr, wind, visib,
// sunrise, sunset, wCode}. WMO codes are mapped back onto the OpenWeather
// codes the upstream icon table expects, so the widget and Icons stay verbatim.
// The daemon is the sole fetcher: the tile shows exactly what the bar and
// quick settings show, for the same location and unit.
Singleton {
    id: root

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    property var data: ({
        temp: "--",
        tempFeelsLike: "",
        city: "Locating...",
        description: "",
        humidity: "",
        cr: "",
        wind: "",
        visib: "",
        sunrise: "",
        sunset: "",
        wCode: 800,
        lastRefresh: ""
    })

    readonly property bool ready: String(data.city).length > 0 && data.description.length > 0
    property var frame: ({ status: "loading" })
    property var hourly: []
    property var daily: []

    // WMO (Open-Meteo) -> OpenWeather condition codes used by the upstream
    // icon map. Night variants (clear night 804->804, 800->800) keep the
    // Icons.isNight() rule intact.
    function wmoToOW(code) {
        if (code === 0) return 800;
        if (code === 1) return 801;
        if (code === 2) return 802;
        if (code === 3) return 804;
        if (code === 45 || code === 48) return 741;
        if (code >= 51 && code <= 55) return 300;
        if (code === 56 || code === 57) return 511;
        if (code === 61) return 500;
        if (code === 63) return 501;
        if (code === 64) return 502;
        if (code === 65) return 520;
        if (code === 66 || code === 67) return 511;
        if (code === 71) return 600;
        if (code === 73) return 601;
        if (code === 74) return 602;
        if (code >= 75 && code <= 77) return 622;
        if (code >= 80 && code <= 82) return 521;
        if (code === 85 || code === 86) return 622;
        if (code === 95) return 200;
        if (code === 96 || code === 99) return 212;
        return 804;
    }

    function apply(line) {
        try {
            const f = JSON.parse(line);
            root.frame = f;
            root.hourly = Array.isArray(f.hourly) ? f.hourly : [];
            root.daily = Array.isArray(f.daily) ? f.daily : [];
            const cur = f.current || null;
            if (!cur)
                return;
            data = {
                temp: cur.temperature || "--",
                tempFeelsLike: cur.feelsLike || "",
                city: f.city || f.location || "",
                description: (cur.condition || "").toLowerCase(),
                humidity: (cur.humidity !== undefined ? cur.humidity : 0) + "%",
                cr: (cur.precipProb !== undefined ? cur.precipProb : 0) + "%",
                wind: (cur.wind || "0") + (cur.windUnits || ""),
                visib: cur.visibility || "",
                sunrise: cur.sunrise || "",
                sunset: cur.sunset || "",
                wCode: wmoToOW(cur.code !== undefined ? cur.code : 3),
                hi: cur.high || "",
                lo: cur.low || "",
                lastRefresh: f.updatedAt || ""
            };
        } catch (e) {
            // A malformed frame keeps the last good readout.
        }
    }

    // Ask the daemon to re-fetch (its retry verb re-kicks the poll ladder).
    function poke() {
        ctl.queued += "call weather.retry {}\n";
        if (ctl.connected)
            ctl.flushQueued();
        else
            ctl.connected = true;
    }

    Socket {
        id: sub
        path: root.sockPath
        parser: SplitParser { splitMarker: "\n"; onRead: line => root.apply(line) }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected)
                write("subscribe weather\n");
            else
                retry.restart();
        }
    }

    Socket {
        id: ctl
        path: root.sockPath
        property string queued: ""
        function flushQueued() {
            if (queued.length === 0)
                return;
            write(queued);
            flush();
            queued = "";
        }
        onConnectionStateChanged: if (connected) flushQueued()
    }

    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!sub.connected) sub.connected = true
    }
}
