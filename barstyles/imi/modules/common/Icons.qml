pragma Singleton
import Quickshell
import QtQml
import shell.services as RyokuServices

Singleton {
    id: root

    function isNight(): bool {
        return isNightAt(new Date().getHours());
    }

    function isNightAt(hour: int): bool {
        return hour < 6 || hour >= 20;
    }

    readonly property var weatherIconMap: ({
        "0": { day: "clear_day", night: "clear_night" },
        "1": { day: "clear_day", night: "clear_night" },
        "2": { day: "partly_cloudy_day", night: "partly_cloudy_night" },
        "3": { day: "cloud", night: "cloud" },
        "45": { day: "foggy", night: "foggy" },
        "48": { day: "foggy", night: "foggy" },
        "51": { day: "rainy", night: "rainy" },
        "53": { day: "rainy", night: "rainy" },
        "55": { day: "rainy", night: "rainy" },
        "61": { day: "rainy", night: "rainy" },
        "63": { day: "rainy", night: "rainy" },
        "65": { day: "rainy", night: "rainy" },
        "71": { day: "cloudy_snowing", night: "cloudy_snowing" },
        "73": { day: "snowing", night: "snowing" },
        "75": { day: "snowing_heavy", night: "snowing_heavy" },
        "80": { day: "rainy", night: "rainy" },
        "81": { day: "rainy", night: "rainy" },
        "82": { day: "rainy", night: "rainy" },
        "95": { day: "thunderstorm", night: "thunderstorm" },
        "96": { day: "thunderstorm", night: "thunderstorm" },
        "99": { day: "thunderstorm", night: "thunderstorm" },
        "113": { day: "clear_day", night: "clear_night" },
        "116": { day: "partly_cloudy_day", night: "partly_cloudy_night" },
        "119": { day: "cloud", night: "cloud" },
        "122": { day: "cloud", night: "cloud" }
    })

    function getWeatherIcon(code): string {
        const key = String(code);
        if (weatherIconMap.hasOwnProperty(key)) {
            const icons = weatherIconMap[key];
            return isNight() ? icons.night : icons.day;
        }
        if (RyokuServices.Weather && RyokuServices.Weather.glyph) {
            return RyokuServices.Weather.glyph;
        }
        return isNight() ? "clear_night" : "clear_day";
    }

    function getDesktopActionMaterialSymbol(icon: string): string {
        switch (icon) {
            case "vscode": return "code";
            case "application-exit": return "exit_to_app";
        }
        return icon;
    }

    function getBluetoothDeviceMaterialSymbol(systemIconName: string): string {
        if (systemIconName.includes("headset") || systemIconName.includes("headphones")) return "headphones";
        if (systemIconName.includes("audio")) return "speaker";
        if (systemIconName.includes("phone")) return "smartphone";
        if (systemIconName.includes("mouse")) return "mouse";
        if (systemIconName.includes("keyboard")) return "keyboard";
        return "bluetooth";
    }
}
