pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import shell.services as RyokuServices

Singleton {
    id: root

    readonly property var ryokuWeather: RyokuServices.Weather

    readonly property var data: ({
        temp: ryokuWeather?.temp || "--°",
        wCode: ryokuWeather?.current?.code ?? 1,
        condition: ryokuWeather?.condition || "Clear",
        city: ryokuWeather?.city || "",
        feelsLike: ryokuWeather?.feels ? (ryokuWeather.feels + "°") : "",
        humidity: ryokuWeather?.humidity ? (ryokuWeather.humidity + "%") : "",
        wind: ryokuWeather?.wind ? (ryokuWeather.wind + " mph") : "",
        daily: ryokuWeather?.daily || [],
        hourly: ryokuWeather?.hourly || []
    })

    function fetch() {
        if (ryokuWeather) ryokuWeather.retry();
    }
}
