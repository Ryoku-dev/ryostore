const assert=require('node:assert/strict');
const m=require('../manifest.json');
assert.deepEqual(m.hosts,['framePopout'],'keyboard utility must not reserve a bar slot');
assert.equal(m.defaults.host,'framePopout');
assert.equal(m.defaults.framePopout.edge,'center','no edge hover activation');
console.log('PASS: non-bar host, centered without hover trigger');
