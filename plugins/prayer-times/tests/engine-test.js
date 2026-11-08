#!/usr/bin/env node
// tests/engine-test.js — ground-truth gate for lib/praytimes.js and lib/hijri.js.
// Fixtures are real AlAdhan responses (tests/fixtures.json), fetched once.
//
// Tolerance: +/-1 minute by default. AlAdhan rounds some fields up where we round
// to nearest, so a sub-minute disagreement is expected. Dubai and Diyanet carry
// additional regional tuning that AlAdhan does not publish (their own docs say
// "1 to 5 minutes"), so those two get +/-4.
//
// Polar cases cannot be compared numerically: AlAdhan substitutes a placeholder
// when the sun never reaches the required angle, we return null. Those are
// asserted structurally instead.
"use strict";

var PT = require("../lib/praytimes.js");
var H  = require("../lib/hijri.js");
var FX = require("./fixtures.json");

var KEYS = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"];
var TOL = {};   // regional tuning is baked into METHODS.tune, so everyone agrees to the minute
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

// ---------------------------------------------------------------- prayer times
FX.forEach(function (f) {
    var got = PT.times({
        year: f.date[0], month: f.date[1], day: f.date[2],
        lat: f.lat, lon: f.lon, tzHours: f.tzHours,
        method: f.method, asr: f.asr, highLat: "none"
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

    var tol = TOL[f.method] || 1;
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
        ok(diff <= tol, f.name + " " + k + " got " + fmt(have) + " want " + f.expect[k]);
    });
});

// ---------------------------------------------------------------- hijri calendar
[
    [[1924, 8, 1], 1343, 1, 1],
    [[2026, 9, 29], 1448, 4, 18],
    [[2026, 11, 7], 1448, 5, 27],
    [[2027, 2, 18], 1448, 9, 11],
    [[2027, 3, 20], 1448, 10, 12]
].forEach(function (c) {
    var h = H.toHijri(c[0][0], c[0][1], c[0][2]);
    ok(h && h.y === c[1] && h.m === c[2] && h.d === c[3],
       "hijri " + c[0].join("-") + " -> " + (h ? h.y + "-" + h.m + "-" + h.d : "null") +
       " want " + c[1] + "-" + c[2] + "-" + c[3]);
});

var back = H.toGregorian(1448, 5, 27);
ok(back && back.y === 2026 && back.m === 11 && back.d === 7, "hijri roundtrip 1448-05-27");
ok(H.holidayFor({ y: 1448, m: 10, d: 1 }) === "Eid al-Fitr", "holiday 10-1 = Eid al-Fitr");
ok(H.holidayFor({ y: 1448, m: 5, d: 27 }) === null, "no holiday on 5-27");
var nh = H.nextHoliday(2026, 11, 7);
ok(nh && nh.name === "Isra & Mi'raj" && nh.inDays === 59, "next holiday from 2026-11-07 is Isra & Mi'raj in 59d");

// ---------------------------------------------------------------- derived values
var t = PT.times({ year: 2026, month: 11, day: 7, lat: 39.2909, lon: -76.6108,
                   tzHours: -5, method: "isna", asr: 1 });
var ni = PT.nightInfo(t, 326);
ok(ni && ni.midnight > t.maghrib && ni.midnight < 1440, "nightInfo midnight between maghrib and midnight");
ok(ni && ni.lastThird > ni.midnight, "nightInfo lastThird after midnight");

var q = PT.qibla(51.5074, -0.1278);
ok(q > 117 && q < 121, "qibla from London ~119deg, got " + q.toFixed(1));
ok(PT.compassPoint(45) === "NE" && PT.compassPoint(0) === "N" && PT.compassPoint(292.5) === "WNW", "compassPoint");

ok(PT.fmt(325, true) === "05:25" && PT.fmt(325, false) === "5:25 AM", "fmt 12h/24h");
ok(PT.fmt(null, true) === "--:--", "fmt null");

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
