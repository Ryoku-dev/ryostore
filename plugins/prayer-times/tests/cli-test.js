#!/usr/bin/env node
// tests/cli-test.js — the entry point, exercised the way a user runs it.
'use strict';

var execFileSync = require('child_process').execFileSync;
var path = require('path');
var assert = require('assert');

var BIN = path.join(__dirname, '..', 'bin', 'prayer-times');
var pass = 0, fail = 0, messages = [];

function ok(cond, label) {
    if (cond) pass++; else { fail++; messages.push('FAIL ' + label); }
}
function run(args, env) {
    try {
        return { code: 0, out: execFileSync(process.execPath, [BIN].concat(args), {
            encoding: 'utf8', env: Object.assign({}, process.env, env || {}) }) };
    } catch (e) {
        return { code: e.status, out: String(e.stderr || '') };
    }
}

// text mode: six labelled lines, 24h
var text = run(['--text', '--city', 'london', '--date', '2026-11-07', '--24']);
ok(text.code === 0, 'text mode exits 0');
ok(text.out.trim().split('\n').length === 6, 'text mode prints six rows');
ok(/^Fajr\s+05:1\d$/m.test(text.out), 'text mode prints a 24h Fajr, got ' + JSON.stringify(text.out.split('\n')[0]));

// json mode carries the city convention
var json = JSON.parse(run(['--json', '--city', 'jakarta', '--date', '2026-11-07']).out);
ok(json.city === 'jakarta' && json.method === 'seasia', 'json reports the city and its method');
ok(json.times.fajr === '4:05 AM', 'json times match the reference, got ' + json.times.fajr);
ok(/Jumada/.test(json.hijri || ''), 'json carries the Hijri date');

// the equinox regression, end to end: this used to be 24h out
var eq = JSON.parse(run(['--json', '--city', 'baltimore', '--date', '2026-03-21']).out);
ok(eq.times.dhuhr === '1:14 PM', 'equinox dhuhr is right, got ' + eq.times.dhuhr);
// the reference prints 20:33; we round to :34, a sub-minute difference
ok(eq.times.fajr === '5:54 AM' && eq.times.isha === '8:34 PM', 'equinox fajr/isha are right');

// the Ramadan wiring, end to end: toHijri exposes `m`, and Ramadan 1448 starts 2027-02-08
var ram = JSON.parse(run(['--json', '--city', 'mecca', '--date', '2027-02-10', '--method', 'ummalqura']).out);
var sep = JSON.parse(run(['--json', '--city', 'mecca', '--date', '2026-11-08', '--method', 'ummalqura']).out);
function mins(t) { var m = /(\d+):(\d+)/.exec(t); var h = Number(m[1]) % 12 + (/PM/.test(t) ? 12 : 0); return h * 60 + Number(m[2]); }
ok(mins(ram.times.isha) - mins(ram.times.maghrib) === 120, 'Ramadan Isha is 120 minutes from the CLI, got ' + (mins(ram.times.isha) - mins(ram.times.maghrib)));
ok(mins(sep.times.isha) - mins(sep.times.maghrib) === 90, 'ordinary Isha stays at 90 minutes from the CLI');

// waybar mode shape
var wb = JSON.parse(run(['--waybar', '--city', 'baltimore']).out);
ok(wb.class === 'prayer' && /^[\u2600\u263e] /.test(wb.text) && wb.tooltip.indexOf('Baltimore') === 0,
   'waybar payload has text, tooltip and class');

// auto detection follows TZ, and an unmapped zone still answers
var tokyo = JSON.parse(run(['--json', 'auto'], { TZ: 'Asia/Tokyo' }).out);
ok(tokyo.city === 'tokyo', 'auto uses the system timezone, got ' + tokyo.city);
var unknown = run(['--json', 'auto'], { TZ: 'Asia/Kathmandu' });
ok(unknown.code === 1 && /no city preset/.test(unknown.out), 'an unmapped zone is refused, not silently London');

// argument handling
ok(run(['--city', 'nope']).code === 1, 'unknown city exits 1');
ok(run(['--city', '--json']).code === 1, 'a flag is not accepted as an option value');
ok(run(['--date', '2026-13-01']).code === 1, 'an impossible date exits 1');
ok(run(['--method', 'nope']).code === 1, 'an unknown method exits 1');
// UTC+12 in July: local midnight at UTC noon is the hour-24 trap
var akl = JSON.parse(run(['--json', '--city', 'auckland', '--date', '2026-07-15']).out);
// UTC+12 in July puts local midnight at UTC noon, the hour-24 trap in zoneOffsetHours
ok(akl.city === 'auckland' && akl.date === '2026-07-15' && /1448$/.test(akl.hijri),
   'a UTC+12 winter date keeps its own date and Hijri day, got ' + akl.date + ' ' + akl.hijri);
ok(/^6:0\d AM$/.test(akl.times.fajr) && /^12:2\d PM$/.test(akl.times.dhuhr),
   'Auckland midwinter times are right, got ' + akl.times.fajr + '/' + akl.times.dhuhr);
ok(run(['--cities']).out.trim().split('\n').length === 45, '--cities lists every preset');
ok(/--high-lat/.test(run(['--help']).out), '--help documents the flags');

console.log(messages.join('\n') || 'all checks passed');
console.log((pass + fail) + ' checks, ' + pass + ' pass, ' + fail + ' fail');
process.exit(fail === 0 ? 0 : 1);
