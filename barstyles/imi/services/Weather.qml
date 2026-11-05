pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services as HostServices
import "."
import "../modules/common"

// Adapter over the host's weather service.
Singleton {
    id: root

    readonly property int fetchInterval: Config.options.bar.weather.fetchInterval * 60 * 1000
    readonly property bool useUSCS: Config.options.bar.weather.useUSCS
    readonly property string city: Config.options.bar.weather.city

    // The daemon owns the fetch cadence; getData and refreshManually just
    // re-kick its poll, so both fold into the same intent.
    function getData(force = false) {
        HostServices.Weather.retry();
    }

    function refreshManually() {
        HostServices.Weather.retry();
    }

    // The frame's unit is whatever was last pushed, so the local useUSCS
    // switch drives the daemon unit and the shapes below convert from that.
    function pushUnit() {
        HostServices.Weather.setUnit(root.useUSCS ? "fahrenheit" : "celsius");
    }
    onUseUSCSChanged: root.pushUnit()
    Component.onCompleted: root.pushUnit()

    readonly property bool forecastLoading: !HostServices.Weather.hasData

    property var data: ({
        uv: 0,
        humidity: "0%",
        sunrise: "",
        sunset: "",
        windDir: "",
        wCode: 113,
        wDesc: "",
        city: "City",
        wind: "0 km/h",
        precip: "",
        visib: "",
        press: "",
        temp: "",
        tempFeelsLike: "",
        lastRefresh: "",
    })

    property var forecastData: []
    property var hourlyData: []

    // The frame carries WMO codes; the ported UI was built on wttr.in codes.
    function wmoToWwo(wmo) {
        if (wmo === 0 || wmo === 1) return 113; // Clear
        if (wmo === 2) return 116; // Partly Cloudy
        if (wmo === 3) return 122; // Overcast
        if (wmo === 45 || wmo === 48) return 248; // Fog
        if (wmo === 51 || wmo === 53 || wmo === 55) return 266; // Drizzle
        if (wmo === 56 || wmo === 57) return 284; // Freezing Drizzle
        if (wmo === 61 || wmo === 63 || wmo === 65) return 296; // Rain
        if (wmo === 66 || wmo === 67) return 311; // Freezing Rain
        if (wmo === 71 || wmo === 73 || wmo === 75 || wmo === 77) return 332; // Snow
        if (wmo === 80 || wmo === 81 || wmo === 82) return 353; // Rain Showers
        if (wmo === 85 || wmo === 86) return 368; // Snow Showers
        if (wmo === 95) return 386; // Thunderstorm
        if (wmo === 96 || wmo === 99) return 389; // Thunderstorm with hail
        return 113;
    }

    function getWeatherDescription(code) {
        const codeInt = parseInt(code);
        const descriptions = {
            "113": Translation.tr("Clear"),
            "116": Translation.tr("Partly Cloudy"),
            "119": Translation.tr("Cloudy"),
            "122": Translation.tr("Overcast"),
            "143": Translation.tr("Mist"),
            "176": Translation.tr("Patchy Rain"),
            "200": Translation.tr("Thundery Outbreaks"),
            "248": Translation.tr("Fog"),
            "266": Translation.tr("Light Drizzle"),
            "296": Translation.tr("Light Rain"),
            "302": Translation.tr("Moderate Rain"),
            "308": Translation.tr("Heavy Rain"),
            "326": Translation.tr("Light Snow"),
            "332": Translation.tr("Moderate Snow"),
            "338": Translation.tr("Heavy Snow"),
            "353": Translation.tr("Light Rain Shower"),
            "389": Translation.tr("Heavy Rain with Thunder")
        };

        if (descriptions[code]) {
            return descriptions[code];
        }

        let keys = Object.keys(descriptions).map(Number).sort((a, b) => a - b);
        let bestMatch = keys[0];

        for (let i = 0; i < keys.length; i++) {
            if (codeInt >= keys[i]) {
                bestMatch = keys[i];
            } else {
                break;
            }
        }

        return descriptions[bestMatch.toString()] || Translation.tr("Unknown");
    }

    // The daemon's unit is read back off the temperature string rather than
    // assumed from useUSCS: the pushed unit and the next frame can disagree
    // for a beat, and converting twice would be wrong either way.
    function _isImperial() {
        return String(HostServices.Weather.temp).indexOf("F") >= 0;
    }

    function _celsius(value) {
        return Math.round((value - 32) * 5 / 9);
    }

    function _fahrenheit(value) {
        return Math.round(value * 9 / 5 + 32);
    }

    function refine() {
        const frame = HostServices.Weather;
        if (!frame.available || !frame.current)
            return;
        const cur = frame.current;
        const imperial = root._isImperial();
        const wwo = root.wmoToWwo(Number(cur.code ?? 0));

        root.data = {
            uv: 0,
            humidity: (cur.humidity ?? 0) + "%",
            sunrise: "",
            sunset: "",
            windDir: String(cur.windDir ?? ""),
            wCode: wwo,
            wDesc: root.getWeatherDescription(wwo),
            city: frame.city || frame.location || root.city || "City",
            wind: Number(cur.windValue ?? cur.wind ?? 0) + (imperial ? " mph" : " km/h"),
            precip: "",
            visib: "",
            press: "",
            temp: String(cur.temperature ?? ""),
            tempFeelsLike: cur.feelsLike !== undefined && cur.feelsLike !== null
                ? String(cur.feelsLike)
                : Number(cur.feels ?? 0) + (imperial ? "°F" : "°C"),
            lastRefresh: DateTime.time + " • " + DateTime.date,
        };

        const daily = frame.daily ?? [];
        let forecastList = [];
        for (let i = 0; i < daily.length; i++) {
            const hi = Number(daily[i].hi ?? daily[i].high ?? 0);
            const lo = Number(daily[i].lo ?? daily[i].low ?? 0);
            forecastList.push({
                date: daily[i].date ?? "",
                maxC: imperial ? root._celsius(hi) : Math.round(hi),
                minC: imperial ? root._celsius(lo) : Math.round(lo),
                maxF: imperial ? Math.round(hi) : root._fahrenheit(hi),
                minF: imperial ? Math.round(lo) : root._fahrenheit(lo),
                code: root.wmoToWwo(Number(daily[i].code ?? 0))
            });
        }
        root.forecastData = forecastList;

        const hourly = frame.hourly ?? [];
        let hourlyList = [];
        for (let j = 0; j < Math.min(hourly.length, 24); j++) {
            const t = Number(hourly[j].temp ?? 0);
            const hourOfDay = parseInt(hourly[j].hour ?? hourly[j].time ?? 0, 10) || 0;
            hourlyList.push({
                time: String(hourOfDay * 100),
                tempC: imperial ? String(root._celsius(t)) : String(Math.round(t)),
                tempF: imperial ? String(Math.round(t)) : String(root._fahrenheit(t)),
                code: root.wmoToWwo(Number(hourly[j].code ?? 0)).toString()
            });
        }
        root.hourlyData = hourlyList;
    }

    Connections {
        target: HostServices.Weather
        function onFrameChanged() {
            root.refine();
        }
    }
}
