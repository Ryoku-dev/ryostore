const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(__dirname, '../service/Model.js'), 'utf8'), context);
const fixture = [
 {address:'0xa',mapped:true,workspace:{id:1,name:'1'},focusHistoryID:1,title:'الف',class:'app-a'},
 {address:'0xb',mapped:true,workspace:{id:1,name:'1'},focusHistoryID:0,title:'B',class:'app-b'},
 {address:'0xc',mapped:true,workspace:{id:-99,name:'special:hidden'},focusHistoryID:2},
 {address:'0xd',mapped:false,workspace:{id:1,name:'1'},focusHistoryID:3},
 {address:'0xe',mapped:true,workspace:{id:2,name:'2'},focusHistoryID:-1,title:'E'}
];
const plain = x => JSON.parse(JSON.stringify(x));
const freshTerminal = {address:'abc123',title:'~',wayland:{appId:'kitty'},workspace:{id:3,name:'3'},lastIpcObject:{}};
const freshHidden = {...freshTerminal,address:'abc124',workspace:{id:-98,name:'special:scratch'}};
const normalized = [freshTerminal,freshHidden].map(t=>context.clientFromToplevel(t));
assert.deepEqual(plain(context.snapshot(normalized,[],'' )).map(c=>c.address),['0xabc123']);
assert.equal(normalized[0].class,'kitty');
assert.equal(normalized[0].title,'~');
const moved = context.clientFromToplevel({...freshTerminal,lastIpcObject:{address:'0xabc123',workspace:{id:-98,name:'special:scratch'},class:'kitty'}});
assert.equal(context.snapshot([moved],[],'').length,1);
assert.equal(freshTerminal.lastIpcObject.address,undefined);
// Quickshell may retain empty placeholder objects long after their windows close.
const ghosts = [
 context.clientFromToplevel({address:'dead01',workspace:null,lastIpcObject:{}}),
 context.clientFromToplevel({address:'dead02',workspace:{id:0,name:''},lastIpcObject:{}}),
 {address:'0xdead03',mapped:true,title:'Helper'},
 {address:'0xdead04',workspace:{name:''}},
 {address:'0xdead05',workspace:{id:0,name:''}}
];
assert.equal(context.snapshot(ghosts,[],'').length,0);
assert.deepEqual(plain(context.snapshot(normalized.concat(ghosts),[],'')).map(c=>c.address),['0xabc123']);
assert.deepEqual(plain(context.snapshot(fixture,[], '0xb')).map(x=>x.address),['0xb','0xa','0xe']);
assert.deepEqual(plain(context.snapshot(fixture,['0xe','0xa'], '0xb')).map(x=>x.address),['0xb','0xe','0xa']);
assert.deepEqual(plain(context.snapshot(fixture,[], '0xb',1)).map(x=>x.address),['0xb','0xa']);
assert.deepEqual(plain(context.snapshot(fixture,[], '0xb',2)).map(x=>x.address),['0xe']);
assert.equal(context.snapshot(fixture,[], '0xb',99).length,0);
assert.equal(context.wrap(0,-1,3),2);
assert.equal(context.wrap(2,1,3),0);
assert.equal(context.wrap(0,1,0),0);
assert.deepEqual(plain(context.touch(['0xa','0xb'],'0xb')),['0xb','0xa']);
assert.equal(context.validAddress('0xa'),true);
assert.equal(context.validAddress('x";evil'),false);
console.log('PASS: window filtering, MRU order, unfocused ordering, wrapping, address validation');
