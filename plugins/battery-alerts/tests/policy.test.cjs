const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(__dirname + '/../service/AlertPolicy.js', 'utf8'), ctx);
const options = { enabled: true, low: 25, critical: 10 };
const sample = { present: true, ready: true, onAc: false, discharging: true, percent: 50 };
let state = ctx.initialState();
function step(overrides = {}, settings = options) {
    const result = ctx.evaluate(state, { ...sample, ...overrides }, settings);
    state = result.state;
    return result.level;
}
assert.equal(step(), '');
assert.equal(step({ percent: 25 }), 'low');
assert.equal(step({ percent: 24 }), '');
assert.equal(step({ percent: 26 }), '');
assert.equal(step({ percent: 25 }), '');
assert.equal(step({ percent: 10 }), 'critical');
assert.equal(step({ percent: 9 }), '');
assert.equal(step({ onAc: true, percent: 9 }), '');
assert.equal(step({ percent: 9 }), 'critical');
assert.equal(step({ percent: 23 }), '');
step({ onAc: true });
for (const invalid of [{ present: false }, { ready: false }, { discharging: false }, { percent: NaN }, { percent: -1 }, { percent: 101 }])
    assert.equal(step({ percent: 5, ...invalid }), '');
assert.equal(step({ percent: 5 }, { ...options, enabled: false }), '');
assert.equal(step({ percent: 5 }), 'critical');
step({ onAc: true });
assert.equal(step({ percent: 20 }, { ...options, low: 30 }), 'low');
assert.equal(step({ percent: 11.1 }), '');
assert.equal(step({ percent: 10.1 }), '');
assert.equal(step({ percent: 9.9 }), 'critical');
console.log('PASS: startup below threshold, exact thresholds, rapid drops, deduplication, AC reset, invalid samples, disabled alerts, fractional charge');
