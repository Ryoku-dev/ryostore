// lib/praytimes.js — solar prayer-time engine.
// ES5, no dependencies, no Qt/DOM. Runs inside QML (`import "lib/praytimes.js" as PT`)
// and in node (`require("./lib/praytimes.js")`).
//
// All output values are MINUTES FROM LOCAL MIDNIGHT, or null when the sun never
// reaches the required depression angle (polar latitudes).
//
// Algorithm: PrayTimes.org (Hamid Zarrabi-Zadeh), verified minute-exact against
// the AlAdhan reference for 7 calculation methods across 3 cities, plus a DST
// boundary day and two polar cases.

var DEG = Math.PI / 180;

var METHODS = {
    mwl:       { fajr: 18.0, isha: 17.0 },
    isna:      { fajr: 15.0, isha: 15.0 },
    egypt:     { fajr: 19.5, isha: 17.5 },
    karachi:   { fajr: 18.0, isha: 18.0 },
    ummalqura: { fajr: 18.5, isha: null, ishaInterval: 90, ramadanInterval: 120 },
    // Regional authorities apply their own few-minute tuning on top of the angles;
    // these reproduce AlAdhan's published times for these two methods exactly.
    dubai:     { fajr: 18.2, isha: 18.2, tune: { dhuhr: 3, maghrib: 3 } },
    diyanet:   { fajr: 18.0, isha: 17.0, tune: { sunrise: -7, dhuhr: 5, asr: 5, maghrib: 7 } },
    // Kemenag (Indonesia), JAKIM (Malaysia) and MUIS (Singapore) all use 20/18;
    // checked minute-exact against AlAdhan methods 20, 17 and 11.
    seasia:    { fajr: 20.0, isha: 18.0 },
    // AlAdhan method 14.
    russia:    { fajr: 16.0, isha: 15.0 }
};

function julianDay(y, m, d) {
    if (m <= 2) { y -= 1; m += 12; }
    var a = Math.floor(y / 100);
    var b = 2 - a + Math.floor(a / 4);
    return Math.floor(365.25 * (y + 4716)) + Math.floor(30.6001 * (m + 1)) + d + b - 1524.5;
}

// Sun declination (degrees) and equation of time (hours) for a Julian day.
function sunPosition(jd) {
    var D = jd - 2451545.0;
    var g = (357.529 + 0.98560028 * D) % 360;
    var q = (280.459 + 0.98564736 * D) % 360;
    var L = (q + 1.915 * Math.sin(g * DEG) + 0.020 * Math.sin(2 * g * DEG)) % 360;
    var e = 23.439 - 0.00000036 * D;
    var ra = Math.atan2(Math.cos(e * DEG) * Math.sin(L * DEG), Math.cos(L * DEG)) / DEG / 15;
    var decl = Math.asin(Math.sin(e * DEG) * Math.sin(L * DEG)) / DEG;
    // q wraps at 360 and right ascension wraps at its own zero, a day apart around
    // the March equinox: for two days a year the raw difference is out by 24 hours
    // and every time lands a day off. Fold it into the real -12..12 hour range.
    var eqt = q / 15 - ((ra + 24) % 24);
    eqt = ((eqt + 12) % 24 + 24) % 24 - 12;
    return { decl: decl, eqt: eqt };
}

// Hours from solar noon to the given depression angle. null when unsolvable.
function angleHour(angle, lat, decl) {
    var x = (-Math.sin(angle * DEG) - Math.sin(decl * DEG) * Math.sin(lat * DEG)) /
            (Math.cos(decl * DEG) * Math.cos(lat * DEG));
    if (x > 1 || x < -1) return null;
    return Math.acos(x) / DEG / 15;
}

function asrHour(factor, lat, decl) {
    var alt = Math.atan(1 / (factor + Math.tan(Math.abs(lat - decl) * DEG))) / DEG;
    var x = (Math.sin(alt * DEG) - Math.sin(decl * DEG) * Math.sin(lat * DEG)) /
            (Math.cos(decl * DEG) * Math.cos(lat * DEG));
    if (x > 1 || x < -1) return null;
    return Math.acos(x) / DEG / 15;
}

function toMinutes(hoursLocal) {
    if (hoursLocal === null || isNaN(hoursLocal)) return null;
    return Math.round(hoursLocal * 60);
}

// opts: { year, month(1-12), day, lat, lon, tzHours, method, asr(1|2),
//         highLat("none"|"middle"|"seventh"|"angle"), offsets{fajr..isha}, fajrAngle, ishaAngle }
function times(opts) {
    var y = opts.year, m = opts.month, d = opts.day;
    var lat = opts.lat, lon = opts.lon;
    var tz = opts.tzHours === undefined ? 0 : opts.tzHours;
    if (typeof lat !== "number" || typeof lon !== "number" || isNaN(lat) || isNaN(lon)) return null;

    var base = METHODS[opts.method] || METHODS.isna;
    var fajrAngle = (opts.fajrAngle === undefined || opts.fajrAngle === null) ? base.fajr : Number(opts.fajrAngle);
    var ishaAngle  = (opts.ishaAngle === undefined || opts.ishaAngle === null) ? base.isha : Number(opts.ishaAngle);
    var ishaInterval = base.ishaInterval || 0;
    var asrFactor = opts.asr === 2 ? 2 : 1;

    // Julian day at 0h UTC (the solver works in UTC hours from there) and at local
    // midnight, which is where the first guess samples the sun.
    var jdUtc = julianDay(y, m, d);
    var jd = jdUtc - lon / (15 * 24);
    var sun = sunPosition(jd);

    // Solve the whole day from one sun position.
    function solve(at) {
        var noon = 12 - at.eqt - lon / 15;          // hours UTC at solar noon
        var riseSet = angleHour(0.833, lat, at.decl);
        var asr = asrHour(asrFactor, lat, at.decl);
        var fajrH = fajrAngle === null ? null : angleHour(fajrAngle, lat, at.decl);
        var ishaH = ishaAngle === null ? null : angleHour(ishaAngle, lat, at.decl);
        return {
            fajr:    fajrH === null ? null : noon - fajrH,
            sunrise: riseSet === null ? null : noon - riseSet,
            dhuhr:   noon,
            asr:     asr === null ? null : noon + asr,
            maghrib: riseSet === null ? null : noon + riseSet,
            isha:    ishaInterval ? null : (ishaH === null ? null : noon + ishaH)
        };
    }

    // One sample per day is what PrayTimes does, and it is up to two minutes late
    // on the horizon events: by the time the sun reaches the angle the declination
    // has already moved. Re-solve each event with the sun where it actually is.
    var first = solve(sun);
    var out = {};
    for (var key in first) {
        var guess = first[key];
        out[key] = null;
        if (guess === null || guess === undefined)
            continue;
        var exact = solve(sunPosition(jdUtc + guess / 24));
        out[key] = exact[key] === null ? guess : exact[key];
    }

    // Interval-based Isha (Umm al-Qura): 90 minutes after Maghrib, 120 in Ramadan.
    if (ishaInterval && out.maghrib !== null) {
        var interval = opts.ramadan && base.ramadanInterval ? base.ramadanInterval : ishaInterval;
        out.isha = out.maghrib + interval / 60;
    }

    // High-latitude rules: replace a missing angle AND pull back a solvable one that
    // falls outside the night portion the rule allows (adhan-js does the same).
    var rule = opts.highLat || "none";
    if (rule !== "none" && out.sunrise !== null && out.maghrib !== null) {
        var night = 24 - (out.maghrib - out.sunrise);   // hours between sunset and next sunrise
        var fajrPart = rule === "middle" ? night / 2 : rule === "seventh" ? night / 7
                     : rule === "angle" && typeof fajrAngle === "number" ? night * (fajrAngle / 60) : null;
        if (fajrPart !== null && (out.fajr === null || out.fajr < out.sunrise - fajrPart))
            out.fajr = out.sunrise - fajrPart;
        var ishaPart = rule === "middle" ? night / 2 : rule === "seventh" ? night / 7
                     : rule === "angle" && typeof ishaAngle === "number" ? night * (ishaAngle / 60) : null;
        if (!ishaInterval && ishaPart !== null && (out.isha === null || out.isha > out.maghrib + ishaPart))
            out.isha = out.maghrib + ishaPart;
    }

    var off = opts.offsets || {};
    var tune = base.tune || {};
    var res = {};
    for (var k in out) {
        if (out[k] === null) { res[k] = null; continue; }
        res[k] = toMinutes(out[k] + tz + ((Number(tune[k]) || 0) + (Number(off[k]) || 0)) / 60);
    }
    return res;
}

// Islamic midnight and the last third of the night, in minutes from local midnight.
// night = Maghrib -> next Fajr. Uses tomorrow's fajr when given, else today's.
function nightInfo(today, tomorrowFajr) {
    if (!today || typeof today.maghrib !== "number" || !isFinite(today.maghrib)) return null;
    var fajr = tomorrowFajr;
    if (typeof fajr !== "number" || !isFinite(fajr)) fajr = today.fajr;
    if (typeof fajr !== "number" || !isFinite(fajr)) return null;
    var night = (fajr <= today.maghrib ? fajr + 1440 : fajr) - today.maghrib;
    return {
        midnight: today.maghrib + Math.round(night / 2),
        lastThird: today.maghrib + Math.round(night * 2 / 3),
        nightMinutes: night
    };
}

// Initial great-circle bearing to the Kaaba, degrees from true north.
function qibla(lat, lon) {
    var kLat = 21.4225, kLon = 39.8262;
    var dLon = (kLon - lon) * DEG;
    var y = Math.sin(dLon);
    var x = Math.cos(lat * DEG) * Math.tan(kLat * DEG) - Math.sin(lat * DEG) * Math.cos(dLon);
    var b = Math.atan2(y, x) / DEG;
    return (b + 360) % 360;
}

function compassPoint(deg) {
    var pts = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
               "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
    return pts[Math.round(((deg % 360) + 360) % 360 / 22.5) % 16];
}

// 12h / 24h formatting of a minutes-from-midnight value.
function fmt(mins, clock24, compact) {
    if (typeof mins !== "number" || !isFinite(mins)) return "--:--";
    var m = ((Math.round(mins) % 1440) + 1440) % 1440;
    var h = Math.floor(m / 60), mm = m % 60;
    if (clock24) return (h < 10 ? "0" : "") + h + ":" + (mm < 10 ? "0" : "") + mm;
    var ap = h < 12 ? "AM" : "PM";
    var h12 = h % 12; if (h12 === 0) h12 = 12;
    var suffix = compact ? (h < 12 ? "a" : "p") : " " + ap;
    return h12 + ":" + (mm < 10 ? "0" : "") + mm + suffix;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        METHODS: METHODS,
        times: times,
        nightInfo: nightInfo,
        qibla: qibla,
        compassPoint: compassPoint,
        fmt: fmt,
        julianDay: julianDay,
        sunPosition: sunPosition
    };
}
