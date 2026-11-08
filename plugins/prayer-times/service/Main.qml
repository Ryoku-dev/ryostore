pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "../lib/praytimes.js" as PT
import "../lib/hijri.js" as H
import "../lib/cities.js" as C

Item {
    id: svc

    property var pluginApi
    property string cityName: ""
    property bool cityEstimated: true
    property var today: ({})
    property var tomorrow: ({})
    property int now: 0
    property string gregorianText: ""
    property string hijriText: ""
    property string nextKey: ""
    property string nextLabel: ""
    property int nextAt: 0
    property int nextIn: 0
    property bool isNow: false
    property string countdownText: ""
    property string nextTimeText: "—"
    property real progress: 0
    property var rows: []
    property string nightText: ""
    property string qiblaText: ""
    property string holidayToday: ""
    property string nextHolidayText: ""
    property var weekRows: []
    property var monthRows: []
    property string monthLabel: ""

    readonly property var st: (pluginApi && pluginApi.pluginSettings) ? pluginApi.pluginSettings : ({})
    property string detectedCityId: ""
    property bool timezoneExact: false
    property bool timezoneReady: false
    property string currentDayKey: ""

    // a value outside the allowed range is rejected, never saturated: a hostile or
    // corrupt setting must leave the widget on its defaults, not on the farthest limit
    function bounded(v, lo, hi, dflt) {
        var n = Number(v);
        return (isFinite(n) && n >= lo && n <= hi) ? n : dflt;
    }

    function s(key, dflt) {
        var v = st[key];
        return (v === undefined || v === "") ? dflt : v;
    }

    function applyTimezone(tz) {
        if (timezoneReady)
            return;
        timezoneReady = true;
        var clean = (tz || "").trim();
        var parts = clean.split("/");
        var zone = clean;
        if (parts.length >= 2)
            zone = parts[parts.length - 2] + "/" + parts[parts.length - 1];
        var guessed = C.guess(zone);
        detectedCityId = guessed.city.id;
        timezoneExact = guessed.exact;
        recompute();
    }

    function timesFor(date, lat, lon, method, asr, highLat, offsets) {
        return PT.times({
            year: date.getFullYear(),
            month: date.getMonth() + 1,
            day: date.getDate(),
            lat: lat,
            lon: lon,
            tzHours: -new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12).getTimezoneOffset() / 60,
            method: method,
            asr: asr,
            highLat: highLat,
            offsets: offsets
        });
    }

    function dayRow(date, todayKey, lat, lon, method, asr, highLat, offsets, clock24, adjust, weekdays) {
        var values = timesFor(date, lat, lon, method, asr, highLat, offsets);
        var key = date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate();
        var hijri = H.toHijri(date.getFullYear(), date.getMonth() + 1, date.getDate(), adjust);
        return {
            day: weekdays[date.getDay()] + " " + date.getDate(),
            fajr: PT.fmt(values ? values.fajr : null, clock24, true),
            sunrise: PT.fmt(values ? values.sunrise : null, clock24, true),
            dhuhr: PT.fmt(values ? values.dhuhr : null, clock24, true),
            asr: PT.fmt(values ? values.asr : null, clock24, true),
            maghrib: PT.fmt(values ? values.maghrib : null, clock24, true),
            isha: PT.fmt(values ? values.isha : null, clock24, true),
            today: key === todayKey,
            holiday: H.holidayFor(hijri) || ""
        };
    }

    function countdown(minutes) {
        if (minutes < 60)
            return minutes + "m";
        var hours = Math.floor(minutes / 60);
        var mins = minutes % 60;
        return hours + "h " + mins + "m";
    }

    function recompute() {
        var date = new Date();
        var y = date.getFullYear();
        var m = date.getMonth() + 1;
        var d = date.getDate();
        var dayKey = y + "-" + m + "-" + d;
        var rolledOver = currentDayKey !== dayKey;
        currentDayKey = dayKey;
        svc.now = date.getHours() * 60 + date.getMinutes();

        var configuredCity = s("city", "auto");
        var autoCity = configuredCity === undefined || configuredCity === "" || configuredCity === "auto";
        var cityId = autoCity ? detectedCityId : configuredCity;
        var city = C.byId(cityId) || C.guess("").city;
        svc.cityName = city.name + ", " + city.country;
        svc.cityEstimated = !timezoneExact;

        // settings are a trust boundary: anything outside the valid range falls back
        // to the preset instead of feeding nonsense into the solar math
        var lat = s("latitude", "") === "" ? city.lat : Number(s("latitude", ""));
        var lon = s("longitude", "") === "" ? city.lon : Number(s("longitude", ""));
        if (!isFinite(lat) || lat < -90 || lat > 90)
            lat = city.lat;
        if (!isFinite(lon) || lon < -180 || lon > 180)
            lon = city.lon;
        var configuredMethod = s("method", "auto");
        var method = configuredMethod === "auto" ? city.method : configuredMethod;
        var asr = s("asr", "standard") === "hanafi" ? 2 : 1;
        var highLat = s("highLat", "none");
        var clock24 = !!s("clock24", true);
        var adjust = bounded(s("hijriAdjust", 0), -2, 2, 0) | 0;
        var offsets = {
            fajr: bounded(s("offsetFajr", 0), -30, 30, 0) | 0,
            sunrise: bounded(s("offsetSunrise", 0), -30, 30, 0) | 0,
            dhuhr: bounded(s("offsetDhuhr", 0), -30, 30, 0) | 0,
            asr: bounded(s("offsetAsr", 0), -30, 30, 0) | 0,
            maghrib: bounded(s("offsetMaghrib", 0), -30, 30, 0) | 0,
            isha: bounded(s("offsetIsha", 0), -30, 30, 0) | 0
        };
        var keys = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"];
        var labels = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];
        var todayDate = new Date(y, m - 1, d, 12);
        var tomorrowDate = new Date(y, m - 1, d + 1, 12);
        var todayTimes = timesFor(todayDate, lat, lon, method, asr, highLat, offsets);
        var tomorrowTimes = timesFor(tomorrowDate, lat, lon, method, asr, highLat, offsets);
        svc.today = todayTimes || ({});
        svc.tomorrow = tomorrowTimes || ({});

        var next = null;
        var recent = null;
        var previous = null;
        if (todayTimes) {
            for (var i = 0; i < keys.length; ++i) {
                var value = todayTimes[keys[i]];
                if (value === null || value === undefined)
                    continue;
                var item = { key: keys[i], label: labels[i], at: value, previous: previous };
                if (value <= svc.now) {
                    if (svc.now - value < 10)
                        recent = item;
                    previous = item;
                } else if (!next) {
                    next = item;
                }
            }
        }
        if (recent) {
            next = recent;
        } else if (!next && tomorrowTimes) {
            for (var j = 0; j < keys.length; ++j) {
                var tomorrowValue = tomorrowTimes[keys[j]];
                if (tomorrowValue !== null && tomorrowValue !== undefined) {
                    next = { key: keys[j], label: labels[j], at: tomorrowValue + 1440, previous: previous };
                    break;
                }
            }
        }

        svc.isNow = recent !== null;
        svc.nextKey = next ? next.key : "";
        svc.nextLabel = next ? next.label : "";
        svc.nextAt = next ? next.at : 0;
        svc.nextIn = next ? Math.max(0, next.at - svc.now) : 0;
        svc.countdownText = !next ? "" : (recent ? "now" : countdown(svc.nextIn));
        svc.nextTimeText = next ? PT.fmt(next.at, clock24) : "—";
        if (next) {
            var start = recent ? (recent.previous ? recent.previous.at : 0) : (previous ? previous.at : 0);
            var span = next.at - start;
            svc.progress = span > 0 ? Math.max(0, Math.min(1, (svc.now - start) / span)) : 0;
        } else {
            svc.progress = 0;
        }

        var dayRows = [];
        for (var k = 0; k < keys.length; ++k) {
            var prayerAt = todayTimes ? todayTimes[keys[k]] : null;
            var rowNow = recent !== null && recent.key === keys[k];
            dayRows.push({
                key: keys[k],
                label: labels[k],
                time: PT.fmt(prayerAt, clock24),
                isPast: prayerAt !== null && prayerAt !== undefined && prayerAt < svc.now && !rowNow,
                isNext: next !== null && next.at < 1440 && next.key === keys[k],
                isNow: rowNow
            });
        }
        svc.rows = dayRows;

        var weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        svc.gregorianText = weekdays[date.getDay()] + " " + d + " " + months[m - 1].substring(0, 3);
        svc.monthLabel = months[m - 1] + " " + y;
        var hijri = H.toHijri(y, m, d, adjust);
        svc.hijriText = hijri ? hijri.d + " " + H.monthName(hijri.m) + " " + hijri.y : "";
        svc.holidayToday = H.holidayFor(hijri) || "";
        var followingHoliday = H.nextHoliday(y, m, d, 400, adjust);
        svc.nextHolidayText = followingHoliday ? followingHoliday.name + " in " + followingHoliday.inDays + " day" + (followingHoliday.inDays === 1 ? "" : "s") : "";

        var night = PT.nightInfo(todayTimes, tomorrowTimes ? tomorrowTimes.fajr : null);
        svc.nightText = night ? "Midnight " + PT.fmt(night.midnight, clock24) + " · Last third " + PT.fmt(night.lastThird, clock24) : "";
        var qibla = PT.qibla(lat, lon);
        svc.qiblaText = "Qibla " + Math.round(qibla) + "° " + PT.compassPoint(qibla);

        var week = [];
        for (var w = 0; w < 7; ++w)
            week.push(dayRow(new Date(y, m - 1, d + w, 12), dayKey, lat, lon, method, asr, highLat, offsets, clock24, adjust, weekdays));
        svc.weekRows = week;
        var month = [];
        var daysInMonth = new Date(y, m, 0).getDate();
        for (var md = 1; md <= daysInMonth; ++md)
            month.push(dayRow(new Date(y, m - 1, md, 12), dayKey, lat, lon, method, asr, highLat, offsets, clock24, adjust, weekdays));
        svc.monthRows = month;
    }

    onStChanged: recompute()
    Component.onCompleted: recompute()

    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: svc.recompute()
    }

    Process {
        id: timezoneProcess
        command: ["readlink", "-f", "/etc" + "/localtime"]
        running: true
        stdout: StdioCollector {
            id: timezoneOutput
        }
        onExited: function(exitCode) {
            svc.applyTimezone(exitCode === 0 ? timezoneOutput.text : "");
        }
    }
}
