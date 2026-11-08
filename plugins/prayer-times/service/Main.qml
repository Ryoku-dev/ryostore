pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "../lib/praytimes.js" as PT
import "../lib/hijri.js" as H
import "../lib/cities.js" as C

Item {
    id: svc

    property var pluginApi
    // set by the host while the panel is open: the clock then ticks once a second
    // so the ring countdown runs; collapsed it only needs the minute
    property bool panelOpen: false

    property string cityName: ""
    property bool cityEstimated: true
    property bool timezoneMismatch: false
    property string cityHint: ""
    property var today: ({})
    property var tomorrow: ({})
    property int now: 0                     // minutes from local midnight
    property int nowSec: 0
    property string gregorianText: ""
    property string hijriText: ""
    property string monthLabel: ""
    property string monthShort: ""
    property int todayIndex: 0
    property string nextKey: ""
    property string nextLabel: ""
    property int nextAt: 0                  // >1440 when the next prayer is tomorrow's
    property int nextIn: 0                  // minutes
    property int nextInSec: 0               // seconds, drives the ring
    property bool nextIsNight: false
    property bool isNow: false              // inside the 10 minute adhan window
    property string countdownText: ""       // bar: "2h 14m" / "now"
    property string countdownPrecise: ""    // panel: "2:14:05" / "now"
    property string nextTimeText: "—"
    property real progress: 0
    property bool hasTimes: false
    property bool twilightMissing: false
    readonly property var prayerKeys: ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]
    readonly property var prayerLabels: ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
    readonly property var prayerShortLabels: ["FAJR", "SUNRISE", "DHUHR", "ASR", "MAGHRIB", "ISHA"]
    property var rows: []
    property string nightText: ""
    property string qiblaText: ""
    property real qiblaDeg: 0
    property string holidayToday: ""
    property string nextHolidayText: ""
    property int nextHolidayDays: 0
    property bool holidaySoon: false
    property var weekRows: []
    property var monthRows: []
    property var holidayRows: []
    property bool clock24: false
    property int hijriAdjust: 0

    readonly property var st: (pluginApi && pluginApi.pluginSettings) ? pluginApi.pluginSettings : ({})
    property string detectedCityId: ""
    property string detectedZone: ""
    property bool timezoneExact: false
    property bool timezoneMatched: false
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
        // Some hosts hand us /usr/share/zoneinfo/America/New_York; keep the whole
        // zone name after the prefix (America/Indiana/Indianapolis is three parts).
        var clean = (tz || "").trim();
        var at = clean.indexOf("zoneinfo/");
        if (at !== -1)
            clean = clean.substring(at + "zoneinfo/".length);
        detectedZone = clean;
        var guessed = C.guess(clean);
        detectedCityId = guessed.city.id;
        timezoneExact = guessed.exact;
        timezoneMatched = !!guessed.matched;
        rebuild();
    }

    function timesFor(date, lat, lon, method, asr, highLat, offsets) {
        var hijri = H.toHijri(date.getFullYear(), date.getMonth() + 1, date.getDate(), hijriAdjust);
        return PT.times({
            // Umm al-Qura holds Isha 120 minutes in Ramadan instead of 90
            ramadan: !!hijri && hijri.m === 9,
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

    function dayRow(date, todayKey, lat, lon, method, asr, highLat, offsets, weekdays) {
        var values = timesFor(date, lat, lon, method, asr, highLat, offsets);
        var key = date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate();
        var hijri = H.toHijri(date.getFullYear(), date.getMonth() + 1, date.getDate(), hijriAdjust);
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
        return Math.floor(minutes / 60) + "h " + (minutes % 60) + "m";
    }

    // h:mm:ss, or m:ss inside the last hour; "now" while the adhan window is open
    function precise(seconds) {
        var s = Math.max(0, seconds);
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        var sec = s % 60;
        var pad = function (n) { return (n < 10 ? "0" : "") + n; };
        return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : m + ":" + pad(sec);
    }

    // ---- cheap pass: clock derived values only, safe to run every second
    function nextEvent() {
        var keys = svc.prayerKeys;
        var labels = svc.prayerLabels;
        var times = svc.today;
        var next = null;
        var recent = null;
        var previous = null;

        if (times) {
            for (var i = 0; i < keys.length; ++i) {
                var value = times[keys[i]];
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
        } else if (!next && svc.tomorrow) {
            for (var j = 0; j < keys.length; ++j) {
                var tomorrowValue = svc.tomorrow[keys[j]];
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
        svc.nextIsNight = svc.nextKey === "fajr" || svc.nextKey === "isha";
        svc.nextIn = next ? Math.max(0, next.at - svc.now) : 0;
        svc.countdownText = !next ? "" : (recent ? "now" : countdown(svc.nextIn));
        svc.nextTimeText = next ? PT.fmt(next.at, svc.clock24) : "—";

        var elapsed = svc.now * 60 + svc.nowSec;
        svc.nextInSec = next ? Math.max(0, next.at * 60 - elapsed) : 0;
        svc.countdownPrecise = !next ? "" : (recent ? "now" : precise(svc.nextInSec));

        if (next) {
            var start = recent ? (recent.previous ? recent.previous.at : 0) : (previous ? previous.at : 0);
            var span = (next.at - start) * 60;
            svc.progress = span > 0 ? Math.max(0, Math.min(1, (elapsed - start * 60) / span)) : 0;
        } else {
            svc.progress = 0;
        }
    }

    function updateClock(date) {
        svc.now = date.getHours() * 60 + date.getMinutes();
        svc.nowSec = date.getSeconds();
        nextEvent();
    }

    function tick() {
        var date = new Date();
        var key = date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate();
        if (key !== currentDayKey) {
            rebuild();          // midnight: everything below the clock is stale
            return;
        }
        updateClock(date);
    }

    // ---- heavy pass: settings, place, day tables. Runs on boot, settings change,
    // timezone resolution and midnight, never on a tick.
    function rebuild() {
        var date = new Date();
        var y = date.getFullYear();
        var m = date.getMonth() + 1;
        var d = date.getDate();
        var dayKey = y + "-" + m + "-" + d;
        currentDayKey = dayKey;

        var configuredCity = s("city", "auto");
        var autoCity = configuredCity === undefined || configuredCity === "" || configuredCity === "auto";
        var cityId = autoCity ? detectedCityId : configuredCity;
        var city = C.byId(cityId) || C.guess("").city;
        svc.cityName = city.name + ", " + city.country;
        // a timezone is not a city: America/New_York spans a thousand miles, so an
        // auto-detected city is always a starting point, never an exact answer
        svc.cityEstimated = autoCity && timezoneReady;
        svc.timezoneMismatch = timezoneReady && !autoCity && detectedZone !== "" && city.tz !== detectedZone;
        svc.cityHint = !timezoneReady ? ""
                     : (autoCity ? (timezoneMatched ? "Auto-detected · set your city in Settings"
                                                    : "No preset for this timezone · set your city")
                                 : (svc.timezoneMismatch ? "Shown on your clock" : ""));

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
        svc.clock24 = !!s("clock24", false);
        svc.hijriAdjust = bounded(s("hijriAdjust", 0), -1, 1, 0) | 0;
        var offsets = {
            fajr: bounded(s("offsetFajr", 0), -30, 30, 0) | 0,
            sunrise: bounded(s("offsetSunrise", 0), -30, 30, 0) | 0,
            dhuhr: bounded(s("offsetDhuhr", 0), -30, 30, 0) | 0,
            asr: bounded(s("offsetAsr", 0), -30, 30, 0) | 0,
            maghrib: bounded(s("offsetMaghrib", 0), -30, 30, 0) | 0,
            isha: bounded(s("offsetIsha", 0), -30, 30, 0) | 0
        };

        var keys = svc.prayerKeys;
        var labels = svc.prayerLabels;
        var todayDate = new Date(y, m - 1, d, 12);
        var tomorrowDate = new Date(y, m - 1, d + 1, 12);
        var todayTimes = timesFor(todayDate, lat, lon, method, asr, highLat, offsets);
        var tomorrowTimes = timesFor(tomorrowDate, lat, lon, method, asr, highLat, offsets);
        svc.today = todayTimes || ({});
        svc.tomorrow = tomorrowTimes || ({});

        var dayRows = [];
        var anyTime = false;
        for (var k = 0; k < keys.length; ++k) {
            var prayerAt = todayTimes ? todayTimes[keys[k]] : null;
            if (prayerAt !== null && prayerAt !== undefined)
                anyTime = true;
            dayRows.push({
                key: keys[k],
                label: labels[k],
                at: (prayerAt === undefined ? null : prayerAt),
                time: PT.fmt(prayerAt, svc.clock24)
            });
        }
        svc.rows = dayRows;
        svc.hasTimes = anyTime;
        // the sun never reaches the angle: honest about it instead of six "--:--"
        svc.twilightMissing = todayTimes !== null
            && (todayTimes.fajr === null || todayTimes.maghrib === null || todayTimes.isha === null)
            && todayTimes.dhuhr !== null;

        var weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        var months = ["January", "February", "March", "April", "May", "June", "July",
                      "August", "September", "October", "November", "December"];
        svc.gregorianText = weekdays[date.getDay()] + " " + d + " " + months[m - 1].substring(0, 3);
        svc.monthLabel = months[m - 1] + " " + y;
        svc.monthShort = months[m - 1].substring(0, 3) + " " + y;
        var hijri = H.toHijri(y, m, d, svc.hijriAdjust);
        svc.hijriText = hijri ? hijri.d + " " + H.monthName(hijri.m) + " " + hijri.y : "";

        var ahead = H.upcoming(y, m, d, 6, svc.hijriAdjust) || [];
        var hrows = [];
        for (var hi = 0; hi < ahead.length; hi++) {
            var hd = ahead[hi];
            var when = new Date(hd.date.y, hd.date.m - 1, hd.date.d);
            hrows.push({
                name: hd.name,
                date: weekdays[when.getDay()] + " " + hd.date.d + " " + months[hd.date.m - 1].substring(0, 3) + " " + hd.date.y,
                hijri: hd.hijri.d + " " + H.monthName(hd.hijri.m) + " " + hd.hijri.y,
                when: hd.inDays === 0 ? "today" : (hd.inDays === 1 ? "tomorrow" : "in " + hd.inDays + " days"),
                soon: hd.inDays <= 30
            });
        }
        svc.holidayRows = hrows;
        svc.holidayToday = H.holidayFor(hijri) || "";
        var followingHoliday = H.nextHoliday(y, m, d, 400, svc.hijriAdjust);
        svc.nextHolidayDays = followingHoliday ? followingHoliday.inDays : 0;
        svc.holidaySoon = svc.holidayToday !== "" || (followingHoliday !== null && followingHoliday.inDays <= 7);
        svc.nextHolidayText = followingHoliday
            ? followingHoliday.name + " in " + followingHoliday.inDays + " day" + (followingHoliday.inDays === 1 ? "" : "s")
            : "";

        var night = PT.nightInfo(todayTimes, tomorrowTimes ? tomorrowTimes.fajr : null);
        svc.nightText = night ? "Midnight " + PT.fmt(night.midnight, svc.clock24)
                              + " · Last third " + PT.fmt(night.lastThird, svc.clock24) : "";
        svc.qiblaDeg = PT.qibla(lat, lon);
        svc.qiblaText = "Qibla " + Math.round(svc.qiblaDeg) + "° " + PT.compassPoint(svc.qiblaDeg);

        var week = [];
        for (var w = 0; w < 7; ++w)
            week.push(dayRow(new Date(y, m - 1, d + w, 12), dayKey, lat, lon, method, asr, highLat, offsets, weekdays));
        svc.weekRows = week;

        var month = [];
        var daysInMonth = new Date(y, m, 0).getDate();
        var index = 0;
        for (var md = 1; md <= daysInMonth; ++md) {
            var row = dayRow(new Date(y, m - 1, md, 12), dayKey, lat, lon, method, asr, highLat, offsets, weekdays);
            if (row.today)
                index = md - 1;
            month.push(row);
        }
        svc.monthRows = month;
        svc.todayIndex = index;

        updateClock(date);
    }

    onStChanged: rebuild()
    Component.onCompleted: rebuild()

    Timer {
        interval: svc.panelOpen ? 1000 : 30000
        running: true
        repeat: true
        onTriggered: svc.tick()
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
