pragma Singleton

import QtQml
import Quickshell
import shell.services as ShellServices
import "../../config"
Singleton {
    id: root

    property string _locOverride: ""
    property string _cityOverride: ""

    // ryoku-shell formats numeric fields in its active display unit; normalize back to Celsius and km/h.
    readonly property bool _imperial: (ShellServices.Weather.temp || "").endsWith("°F")

    readonly property bool hasWeather: ShellServices.Weather.available
    readonly property bool loading: ShellServices.Weather.status === "loading"
    readonly property bool isDay: ShellServices.Weather.isDay

    readonly property string city: ShellServices.Weather.city || _cityOverride || ShellServices.Weather.location
    readonly property string loc: _locOverride || GlobalConfig.services.weatherLocation || ShellServices.Weather.location
    readonly property int weatherCode: ShellServices.Weather.current?.code ?? 0

    readonly property real tempC: hasWeather ? _toC(ShellServices.Weather.tempNow) : 0
    readonly property string temp: hasWeather ? formatTemp(tempC) : formatTemp(NaN)
    readonly property real feelsLikeC: hasWeather ? _toC(ShellServices.Weather.feels) : 0
    readonly property string feelsLike: hasWeather ? formatTemp(feelsLikeC) : formatTemp(NaN)
    readonly property string description: hasWeather ? getWeatherCondition(weatherCode) : qsTr("No weather")
    readonly property string icon: hasWeather ? getWeatherIcon(weatherCode, isDay) : "cloud"
    readonly property int humidity: ShellServices.Weather.humidity
    readonly property real windSpeed: hasWeather ? (_imperial ? Math.round(ShellServices.Weather.wind / 0.621371) : ShellServices.Weather.wind) : 0

    readonly property string sunrise: _formatClock(ShellServices.Weather.current?.sunrise ?? "")
    readonly property string sunset: _formatClock(ShellServices.Weather.current?.sunset ?? "")

    readonly property real maxTempC: hasWeather ? _toC(ShellServices.Weather.current?.hi ?? 0) : 0
    readonly property real minTempC: hasWeather ? _toC(ShellServices.Weather.current?.lo ?? 0) : 0
    readonly property string maxTemp: hasWeather ? formatTemp(maxTempC) : formatTemp(NaN)
    readonly property string minTemp: hasWeather ? formatTemp(minTempC) : formatTemp(NaN)

    readonly property var forecast: {
        const days = ShellServices.Weather.daily || [];
        if (!hasWeather || days.length === 0)
            return [];

        const list = [];
        for (let i = 0; i < days.length; i++) {
            const day = days[i];
            const d = new Date();
            d.setHours(12, 0, 0, 0);
            d.setDate(d.getDate() + i);
            const dateStr = `${d.getFullYear()}/${String(d.getMonth() + 1).padStart(2, "0")}/${String(d.getDate()).padStart(2, "0")}`;
            const maxC = _toC(day.hi ?? 0);
            const minC = _toC(day.lo ?? 0);
            const code = day.code ?? 0;

            list.push({
                date: dateStr,
                maxTempC: maxC,
                minTempC: minC,
                maxTempF: Math.round(maxC * 9 / 5 + 32),
                minTempF: Math.round(minC * 9 / 5 + 32),
                weatherCode: code,
                icon: getWeatherIcon(code, true)
            });
        }
        return list;
    }

    readonly property var hourlyForecast: {
        const hours = ShellServices.Weather.hourly || [];
        if (!hasWeather || hours.length === 0)
            return [];

        const list = [];
        const dayCursor = new Date();
        dayCursor.setHours(12, 0, 0, 0);
        let prevHour = -1;

        for (let i = 0; i < hours.length; i++) {
            const h = hours[i];
            const parsed = parseInt(h.hour ?? "0", 10);
            const hr = isNaN(parsed) ? 0 : parsed;
            if (i > 0 && hr < prevHour)
                dayCursor.setDate(dayCursor.getDate() + 1);
            prevHour = hr;

            const yyyy = dayCursor.getFullYear();
            const mm = String(dayCursor.getMonth() + 1).padStart(2, "0");
            const dd = String(dayCursor.getDate()).padStart(2, "0");
            const hh = String(hr).padStart(2, "0");
            const code = h.code ?? 0;

            list.push({
                timestamp: `${yyyy}-${mm}-${dd}T${hh}:00`,
                hour: hr,
                tempC: Math.round(_toC(h.temp ?? 0)),
                precipChance: h.precip ?? 0,
                weatherCode: code,
                icon: getWeatherIcon(code, h.isDay ?? true)
            });
        }
        return list;
    }

    function _toC(value: real): real {
        return _imperial ? (value - 32) * 5 / 9 : value;
    }

    function _effectiveUnit(): int {
        const u = GlobalConfig.services.weatherUnits;
        return u !== TemperatureUnit.Auto ? u : Number(GlobalConfig.services.weatherUnit);
    }

    function _daemonUnit(): string {
        const u = _effectiveUnit();
        if (u === TemperatureUnit.Fahrenheit)
            return "fahrenheit";
        if (u === TemperatureUnit.Celsius || u === TemperatureUnit.Kelvin)
            return "celsius";
        return "auto";
    }

    function _formatClock(hhmm: string): string {
        if (!hhmm)
            return "--:--";
        if (!GlobalConfig.services.twelveHourClock || hhmm.includes("AM") || hhmm.includes("PM"))
            return hhmm;
        const parts = hhmm.split(":");
        if (parts.length < 2)
            return hhmm;
        const h24 = parseInt(parts[0], 10);
        if (isNaN(h24))
            return hhmm;
        const suffix = h24 >= 12 ? "PM" : "AM";
        const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
        return `${h12}:${parts[1]} ${suffix}`;
    }

    function formatTemp(tempVal: var): string {
        const unit = _effectiveUnit();
        const invalid = tempVal === undefined || tempVal === null || tempVal === "" || isNaN(Number(tempVal));
        if (invalid) {
            if (unit === TemperatureUnit.Fahrenheit)
                return "--°F";
            if (unit === TemperatureUnit.Kelvin)
                return "-- K";
            return "--°C";
        }

        const val = Number(tempVal);
        if (unit === TemperatureUnit.Fahrenheit)
            return `${Math.round(val * 9 / 5 + 32)}°F`;
        if (unit === TemperatureUnit.Kelvin)
            return `${Math.round(val + 273.15)} K`;
        return `${Math.round(val)}°C`;
    }

    function getWeatherIcon(code: int, day = true): string {
        switch (code) {
        case 0:
        case 1:
            return day ? "clear_day" : "clear_night";
        case 2:
            return day ? "partly_cloudy_day" : "partly_cloudy_night";
        case 3:
            return "cloud";
        case 45:
        case 48:
            return "foggy";
        case 51:
        case 53:
        case 55:
        case 56:
        case 57:
        case 61:
        case 63:
        case 65:
        case 66:
        case 67:
        case 80:
        case 81:
        case 82:
            return "rainy";
        case 71:
        case 73:
        case 77:
        case 85:
            return "cloudy_snowing";
        case 75:
        case 86:
            return "snowing_heavy";
        case 95:
        case 96:
        case 99:
            return "thunderstorm";
        default:
            return "air";
        }
    }

    function getWeatherCondition(code: int): string {
        switch (code) {
        case 0:
        case 1:
            return qsTr("Clear");
        case 2:
            return qsTr("Partly cloudy");
        case 3:
            return qsTr("Overcast");
        case 45:
        case 48:
            return qsTr("Fog");
        case 51:
        case 53:
        case 55:
            return qsTr("Drizzle");
        case 56:
        case 57:
            return qsTr("Freezing drizzle");
        case 61:
        case 66:
        case 80:
            return qsTr("Light rain");
        case 63:
        case 81:
            return qsTr("Rain");
        case 65:
        case 67:
        case 82:
            return qsTr("Heavy rain");
        case 71:
            return qsTr("Light snow");
        case 73:
        case 77:
            return qsTr("Snow");
        case 75:
            return qsTr("Heavy snow");
        case 85:
            return qsTr("Light snow showers");
        case 86:
            return qsTr("Heavy snow showers");
        case 95:
            return qsTr("Thunderstorm");
        case 96:
        case 99:
            return qsTr("Thunderstorm with hail");
        default:
            return qsTr("Unknown");
        }
    }

    function _applyConfiguredLocation(location: string): void {
        if (location) {
            ShellServices.Weather.send("weather.configure", {
                location: location,
                unit: _daemonUnit(),
                clock24: true
            });
        } else {
            ShellServices.Weather.sendConfigure();
        }
    }

    function setLocation(coords: string, cityName = ""): void {
        _locOverride = coords || "";
        _cityOverride = cityName || "";
        _applyConfiguredLocation(_locOverride || GlobalConfig.services.weatherLocation);
    }

    function setCity(cityName: string): void {
        _cityOverride = cityName || "";
    }

    function reload(): void {
        const customLoc = _locOverride || GlobalConfig.services.weatherLocation;
        if (customLoc)
            _applyConfiguredLocation(customLoc);
        else if (!ShellServices.Weather.hasData)
            ShellServices.Weather.retry();
    }

    function refresh(): void {
        const customLoc = _locOverride || GlobalConfig.services.weatherLocation;
        if (customLoc)
            _applyConfiguredLocation(customLoc);
        ShellServices.Weather.retry();
    }

    Component.onCompleted: {
        if (GlobalConfig.services.weatherLocation)
            _applyConfiguredLocation(GlobalConfig.services.weatherLocation);
    }

    Connections {
        function onWeatherLocationChanged(): void {
            if (!root._locOverride)
                root._applyConfiguredLocation(GlobalConfig.services.weatherLocation);
        }

        target: GlobalConfig.services
    }
}
