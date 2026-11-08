#!/usr/bin/env node
// tests/engine-test.js — ground-truth gate for lib/praytimes.js and lib/hijri.js.
//
// Three kinds of check:
//   1. Fixtures (tests/fixtures.json) are real AlAdhan responses, fetched once.
//      They pin the whole pipeline against an independent implementation.
//      Tolerance is one minute, except for Asr: the engine solves each event with
//      the sun where it actually is at that moment, while AlAdhan samples once at
//      local midnight, which moves Asr by up to two minutes (the shadow-length
//      formula is steep). The sky check below is the authoritative one.
//   2. Sky checks compute the sun's altitude at our own reported times with an
//      independent ephemeris: at sunrise/sunset the sun must sit on 0.833 degrees,
//      at Fajr/Isha on the method's depression angle. Two degrees of tolerance
//      here would hide a two-minute error, so this is what really guards the maths.
//   3. Structure: the Umm al-Qura table is walked end to end, holidays and polar
//      cases are asserted for shape.
"use strict";

var PT = require("../lib/praytimes.js");
var H  = require("../lib/hijri.js");
var C  = require("../lib/cities.js");
var FX = require("./fixtures.json");

var KEYS = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"];
var DEG = Math.PI / 180;
var pass = 0, fail = 0, messages = [];

function ok(cond, label) {
    if (cond) { pass++; } else { fail++; messages.push("FAIL " + label); }
}
function toMin(hhmm) {
    var p = String(hhmm).split(":");
    return parseInt(p[0], 10) * 60 + parseInt(p[1], 10);
}
function fmt(m) {
    if (m === null || m === undefined) return "--:--";
    var x = ((Math.round(m) % 1440) + 1440) % 1440;
    return (x < 600 ? "0" : "") + Math.floor(x / 60) + ":" + (x % 60 < 10 ? "0" : "") + (x % 60);
}

// ---------------------------------------------------------------- 1. fixtures
FX.forEach(function (f) {
    var got = PT.times({
        year: f.date[0], month: f.date[1], day: f.date[2],
        lat: f.lat, lon: f.lon, tzHours: f.tzHours,
        method: f.method, asr: f.asr, highLat: f.highLat || "none"
    });
    ok(got !== null, f.name + " produced a result");
    if (!got) return;

    if (f.name === "tromso-midsummer-mwl") {
        // sun never drops 18 degrees below the horizon: no twilight, no sunrise
        ["fajr", "sunrise", "maghrib", "isha"].forEach(function (k) {
            ok(got[k] === null, f.name + " " + k + " is null");
        });
        ok(got.dhuhr !== null && got.asr !== null, f.name + " dhuhr/asr solvable");
        return;
    }
    if (f.name === "tromso-midwinter-mwl") {
        // sun never rises, but 18-degree twilight does occur
        ok(got.sunrise === null && got.maghrib === null, f.name + " sunrise/maghrib null");
        ok(got.fajr !== null && got.isha !== null, f.name + " fajr/isha solvable");
    }

    KEYS.forEach(function (k) {
        var want = toMin(f.expect[k]);
        var have = got[k];
        if (have === null) {
            if (f.name.indexOf("tromso") === 0) return;         // asserted above
            ok(false, f.name + " " + k + " null, expected " + f.expect[k]);
            return;
        }
        var diff = Math.abs(have - want);
        if (diff > 720) diff = 1440 - diff;                      // midnight wrap
        var tol = k === "asr" ? 2 : 1;
        ok(diff <= tol, f.name + " " + k + " got " + fmt(have) + " want " + f.expect[k]);
    });
});

// ---------------------------------------------------------------- 2. sky checks
// Independent ephemeris (Meeus, higher-order series than the engine's low-precision
// sun position), so this measures the answer, not the implementation.
function sunAltitude(y, m, d, lat, lon, minutes, tzHours) {
    var utcHours = (minutes - tzHours * 60) / 60;
    var jd = PT.julianDay(y, m, d) + utcHours / 24;
    var T = (jd - 2451545.0) / 36525;
    var L0 = (280.46646 + T * (36000.76983 + 0.0003032 * T)) % 360;
    var M = 357.52911 + T * (35999.05029 - 0.0001537 * T);
    var e = 0.016708634 - T * (0.000042037 + 0.0000001267 * T);
    var C = Math.sin(M * DEG) * (1.914602 - T * (0.004817 + 0.000014 * T))
          + Math.sin(2 * M * DEG) * (0.019993 - 0.000101 * T)
          + Math.sin(3 * M * DEG) * 0.000289;
    var omega = 125.04 - 1934.136 * T;
    var lambda = L0 + C - 0.00569 - 0.00478 * Math.sin(omega * DEG);
    var seconds = 23 + (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60;
    var obliq = seconds + 0.00256 * Math.cos(omega * DEG);
    var decl = Math.asin(Math.sin(obliq * DEG) * Math.sin(lambda * DEG)) / DEG;
    var yy = Math.pow(Math.tan(obliq * DEG / 2), 2);
    var eot = 4 * (yy * Math.sin(2 * L0 * DEG) - 2 * e * Math.sin(M * DEG)
              + 4 * e * yy * Math.sin(M * DEG) * Math.cos(2 * L0 * DEG)
              - 0.5 * yy * yy * Math.sin(4 * L0 * DEG)
              - 1.25 * e * e * Math.sin(2 * M * DEG)) / DEG;
    var trueSolar = (utcHours * 60 + eot + 4 * lon) % 1440;
    var hourAngle = trueSolar / 4 - 180;
    return Math.asin(Math.sin(lat * DEG) * Math.sin(decl * DEG)
           + Math.cos(lat * DEG) * Math.cos(decl * DEG)
           * Math.cos(hourAngle * DEG)) / DEG;
}

// minutes at which the sun truly crosses `target`, found by bisection around our
// own answer (so a wildly wrong answer fails instead of finding another crossing)
function trueCrossing(y, m, d, lat, lon, tz, around, target) {
    var lo = around - 20, hi = around + 20;
    var flo = sunAltitude(y, m, d, lat, lon, lo, tz) - target;
    var fhi = sunAltitude(y, m, d, lat, lon, hi, tz) - target;
    if (flo * fhi > 0) return null;
    for (var i = 0; i < 50; i++) {
        var mid = (lo + hi) / 2;
        var fm = sunAltitude(y, m, d, lat, lon, mid, tz) - target;
        if (flo * fm <= 0) { hi = mid; fhi = fm; } else { lo = mid; flo = fm; }
    }
    return (lo + hi) / 2;
}

// 45 seconds: the engine rounds to whole minutes (+-30s), so anything above this
// is the solar maths drifting, not round-off. Before the per-event sun sampling
// the horizon events sat ~2 minutes late (well outside this).
[
    ["london", 51.5074, -0.1278, 0, "mwl", 18, 17],
    ["moscow", 55.6256, 37.6064, 3, "russia", 16, 15],
    ["baltimore", 39.2909, -76.6108, -5, "isna", 15, 15],
    ["sydney", -33.8698, 151.2083, 11, "mwl", 18, 17],
    ["nairobi", -1.3024, 36.8289, 3, "mwl", 18, 17]
].forEach(function (c) {
    var name = c[0], lat = c[1], lon = c[2], tz = c[3], method = c[4];
    [["2026-11-07", 2026, 11, 7], ["2026-06-21", 2026, 6, 21], ["2027-03-10", 2027, 3, 10],
     ["2026-03-21", 2026, 3, 21]]
        .forEach(function (day) {
            var t = PT.times({ year: day[1], month: day[2], day: day[3], lat: lat, lon: lon,
                               tzHours: tz, method: method, asr: 1, highLat: "none" });
            [["sunrise", -0.833], ["maghrib", -0.833], ["fajr", -c[5]], ["isha", -c[6]]]
                .forEach(function (ev) {
                    var key = ev[0], target = ev[1];
                    if (t[key] === null) return;                       // polar, not this check
                    var cross = trueCrossing(day[1], day[2], day[3], lat, lon, tz, t[key], target);
                    if (cross === null) {
                        ok(false, name + " " + day[0] + " " + key + ": no crossing near " + fmt(t[key]));
                        return;
                    }
                    var offSeconds = Math.abs(cross - t[key]) * 60;
                    ok(offSeconds <= 45, name + " " + day[0] + " " + key + " is " +
                       offSeconds.toFixed(0) + "s from the true " + target + "deg crossing");
                });
        });
});

// A time that is out by a full day still looks plausible once it is wrapped into a
// clock, so check the raw minutes: never negative, and always in order. The March
// equinox used to shift every event by 24h here (equation of time wrapping).
[
    ["baltimore", 39.2909, -76.6108, -4, "isna"],
    ["london", 51.5074, -0.1278, 0, "mwl"],
    ["sydney", -33.8698, 151.2083, 11, "mwl"]
].forEach(function (c) {
    for (var day = 0; day <= 6; day++) {
        [[2026, 3, 18], [2026, 9, 20]].forEach(function (start) {
            var date = new Date(start[0], start[1] - 1, start[2] + day);
            var t = PT.times({ year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate(),
                               lat: c[1], lon: c[2], tzHours: c[3], method: c[4], asr: 1 });
            var label = c[0] + " " + date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate();
            var negative = KEYS.filter(function (k) { return t[k] !== null && t[k] < 0; });
            ok(negative.length === 0, label + " has no negative minutes (" + negative.join(",") + ")");
            var ascending = true;
            for (var i = 1; i < KEYS.length; i++) {
                if (t[KEYS[i]] !== null && t[KEYS[i - 1]] !== null && t[KEYS[i]] <= t[KEYS[i - 1]]) ascending = false;
            }
            ok(ascending, label + " runs fajr -> isha in order: " + KEYS.map(function (k) { return fmt(t[k]); }).join(" "));
        });
    }
});

// ---------------------------------------------------------------- 3. structure
// Walk every month of the embedded Umm al-Qura table through the public API. One
// wrong cell shifts every later date, so this covers all 1,896 months.
var months = 0, badRoundtrip = 0, badLength = 0;
for (var hy = 1343; hy <= 1500; hy++) {
    for (var hm = 1; hm <= 12; hm++) {
        var start = H.toGregorian(hy, hm, 1);
        var nextMonth = hm === 12 ? H.toGregorian(hy + 1, 1, 1) : H.toGregorian(hy, hm + 1, 1);
        var back = H.toHijri(start.y, start.m, start.d, 0);
        if (!back || back.y !== hy || back.m !== hm || back.d !== 1) badRoundtrip++;
        if (nextMonth) {                       // the table ends at 1500-12
            var len = Math.round((Date.UTC(nextMonth.y, nextMonth.m - 1, nextMonth.d)
                                - Date.UTC(start.y, start.m - 1, start.d)) / 86400000);
            var modern = hy >= 1420;           // 1999 onwards: what users actually see
            if (modern && len !== 29 && len !== 30) badLength++;
            if (!modern && (len < 28 || len > 31)) badLength++;
        }
        months++;
    }
}
ok(months === 1896, "table covers 158 years of months, got " + months);
ok(badRoundtrip === 0, "every month start round-trips to its own Hijri date (" + badRoundtrip + " bad)");
ok(badLength === 0, "months are 29/30 days from 1420 AH on, and never absurd before it (" + badLength + " bad)");

[
    [[1924, 8, 1], 1343, 1, 1],
    [[2026, 9, 29], 1448, 4, 18],
    [[2026, 11, 7], 1448, 5, 27],
    [[2027, 2, 18], 1448, 9, 11],
    [[2027, 3, 20], 1448, 10, 12],
    [[2028, 1, 28], 1449, 9, 1]
].forEach(function (c) {
    var h = H.toHijri(c[0][0], c[0][1], c[0][2]);
    ok(h && h.y === c[1] && h.m === c[2] && h.d === c[3],
       "hijri " + c[0].join("-") + " -> " + (h ? h.y + "-" + h.m + "-" + h.d : "null") +
       " want " + c[1] + "-" + c[2] + "-" + c[3]);
});

// Umm al-Qura anchors, cross-checked against AlAdhan's hToG (UAQ).
[["Ramadan 1448", 1448, 9, 1, 2027, 2, 8],
 ["Eid al-Fitr 1448", 1448, 10, 1, 2027, 3, 9],
 ["Eid al-Adha 1448", 1448, 12, 10, 2027, 5, 16],
 ["Ramadan 1449", 1449, 9, 1, 2028, 1, 28]].forEach(function (a) {
    var g = H.toGregorian(a[1], a[2], a[3]);
    ok(g && g.y === a[4] && g.m === a[5] && g.d === a[6],
       a[0] + " starts " + (g ? g.y + "-" + g.m + "-" + g.d : "null") +
       " want " + a[4] + "-" + a[5] + "-" + a[6]);
});

ok(H.toGregorian(1500, 12, 30) !== null, "last month has a day 30");
ok(H.toGregorian(1500, 12, 31) === null, "day past the last month is rejected, not rolled over");
ok(H.toGregorian(1500, 11, 40) === null, "day past a month end is rejected");
ok(H.toGregorian(1500, 13, 1) === null, "month 13 is rejected");
ok(H.toGregorian(1500, 0, 1) === null, "month 0 is rejected");
ok(H.toHijri(2077, 11, 17, 0) === null, "day after the table ends is null, not 1501");

// Date.UTC normalises bad components; the API must not
ok(H.toHijri(2024, 13, 1, 0) === null, "month 13 is rejected");
ok(H.toHijri(2024, 1, 32, 0) === null, "day 32 is rejected");
ok(H.toHijri(2024, 1, 0, 0) === null, "day 0 is rejected");
ok(H.toHijri(50, 1, 1, 0) === null, "two-digit years are not mapped to 19xx");
ok(JSON.stringify(H.toHijri(2026, 11, 7, "1")) === JSON.stringify(H.toHijri(2026, 11, 7, 1)),
   "a numeric-string adjust is coerced, never concatenated");
ok(H.toHijri(2026, 11, 7, 1.5) === null, "a fractional adjust is rejected");

ok(Array.isArray(H.upcoming(2026, 11, 8, 0, 0)) && H.upcoming(2026, 11, 8, 0, 0).length === 0,
   "an explicit count of 0 returns nothing");

ok(PT.fmt(NaN, true) === "--:--" && PT.fmt(Infinity, true) === "--:--", "fmt rejects non-finite minutes");
ok(PT.nightInfo(null, 300) === null, "nightInfo(null) is null");
ok(PT.nightInfo({}, 300) === null, "nightInfo with no maghrib is null");
ok(PT.nightInfo({ maghrib: 1100 }, null) === null, "nightInfo with no fajr is null");

var polarNoAngle = PT.times({ year: 2026, month: 6, day: 21, lat: 69.6492, lon: 18.9553,
                              tzHours: 2, method: "mwl", asr: 1, highLat: "angle", ishaAngle: null });
ok(polarNoAngle.isha === null, "angle rule does not invent an isha when the method has no angle");

var back = H.toGregorian(1448, 5, 27);
ok(back && back.y === 2026 && back.m === 11 && back.d === 7, "hijri roundtrip 1448-05-27");
ok(H.holidayFor({ y: 1448, m: 10, d: 1 }) === "Eid al-Fitr", "holiday 10-1 = Eid al-Fitr");
ok(H.holidayFor({ y: 1448, m: 5, d: 27 }) === null, "no holiday on 5-27");
var nh = H.nextHoliday(2026, 11, 7);
ok(nh && nh.name === "Isra & Mi'raj" && nh.inDays === 59, "next holiday from 2026-11-07 is Isra & Mi'raj in 59d");

// ---------------------------------------------------------------- 4. derived
var t = PT.times({ year: 2026, month: 11, day: 7, lat: 39.2909, lon: -76.6108,
                   tzHours: -5, method: "isna", asr: 1 });
var ni = PT.nightInfo(t, 326);
ok(ni && ni.midnight > t.maghrib && ni.midnight < 1440, "nightInfo midnight between maghrib and midnight");
ok(ni && ni.lastThird > ni.midnight, "nightInfo lastThird after midnight");

var q = PT.qibla(51.5074, -0.1278);
ok(q > 117 && q < 121, "qibla from London ~119deg, got " + q.toFixed(1));
var guessed = C.guess("America/New_York");
ok(guessed.city !== null && guessed.city.id === "new-york", "zone resolves to a starter city");
ok(guessed.exact === false, "a timezone guess is never reported as an exact city");
ok(C.guess("America/New_York").matched === true, "a known zone reports a match");
var unknown = C.guess("Asia/Kathmandu");
ok(unknown.exact === false && unknown.matched === false, "an unknown zone reports no match");

ok(PT.compassPoint(45) === "NE" && PT.compassPoint(0) === "N" && PT.compassPoint(292.5) === "WNW", "compassPoint");

ok(PT.fmt(325, true) === "05:25" && PT.fmt(325, false) === "5:25 AM", "fmt 12h/24h");
ok(PT.fmt(null, true) === "--:--", "fmt null");

// methods are just angle pairs: check the pairs the national authorities use
[["seasia", 20, 18], ["russia", 16, 15], ["isna", 15, 15], ["egypt", 19.5, 17.5]].forEach(function (m) {
    var named = PT.times({ year: 2026, month: 11, day: 7, lat: 3.1517, lon: 101.6942,
                          tzHours: 8, method: m[0], asr: 1 });
    var explicit = PT.times({ year: 2026, month: 11, day: 7, lat: 3.1517, lon: 101.6942,
                              tzHours: 8, method: "mwl", fajrAngle: m[1], ishaAngle: m[2], asr: 1 });
    ok(named && explicit && named.fajr === explicit.fajr && named.isha === explicit.isha,
       m[0] + " is " + m[1] + "/" + m[2]);
});

// high-latitude rules only fill what the angle could not reach
var highLatBase = { year: 2026, month: 6, day: 21, lat: 59.3251, lon: 18.0711,
                    tzHours: 2, method: "mwl", asr: 1 };
var noRule = PT.times(highLatBase);
var withRule = PT.times({ year: 2026, month: 6, day: 21, lat: 59.3251, lon: 18.0711,
                          tzHours: 2, method: "mwl", asr: 1, highLat: "angle" });
ok(noRule.fajr === null && noRule.isha === null, "Stockholm midsummer has no 18deg twilight");
ok(withRule.fajr !== null && withRule.isha !== null, "angle rule fills it");
ok(Math.abs(withRule.fajr - 114) <= 1 && Math.abs(withRule.isha - 1420) <= 1,
   "angle rule matches the reference (01:54 / 23:40), got " + fmt(withRule.fajr) + " / " + fmt(withRule.isha));
var polar = PT.times({ year: 2026, month: 6, day: 21, lat: 69.6492, lon: 18.9553,
                      tzHours: 2, method: "mwl", asr: 1, highLat: "angle" });
ok(polar.maghrib === null && polar.fajr === null, "no sunset means no invented fajr at 69N");

// upcoming holidays: ordered, includes today, and names come from the table
var up = H.upcoming(2026, 11, 8, 6, 0);
ok(up.length === 6, "upcoming returns the requested count, got " + up.length);
var ordered = true;
for (var ui = 1; ui < up.length; ui++)
    if (up[ui].inDays <= up[ui - 1].inDays) ordered = false;
ok(ordered, "upcoming holidays are in date order");
ok(up[0].name === "Isra & Mi'raj" && up[0].inDays === 58, "first holiday after 8 Nov 2026, got " + up[0].name);
var d0 = up[0].date;
var same = H.upcoming(d0.y, d0.m, d0.d, 1, 0)[0];
ok(same.inDays === 0 && same.name === up[0].name, "a holiday that is today reports inDays 0");

// ---------------------------------------------------------------- report
console.log(messages.join("\n") || "all checks passed");
console.log((pass + fail) + " checks, " + pass + " pass, " + fail + " fail");
process.exit(fail === 0 ? 0 : 1);
