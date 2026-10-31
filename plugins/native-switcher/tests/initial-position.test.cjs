const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const qml=fs.readFileSync(require('node:path').join(__dirname,'../content/Widget.qml'),'utf8');
const fn=qml.match(/                        function ensureSelectionVisible\(\) \{[^]*?\n                        }/)[0];
const ctx={currentItem:{x:156,width:146},currentIndex:1,width:0,contentWidth:1550,win:{scrollTarget:0,implicitWidth:1000},Math};
vm.createContext(ctx);vm.runInContext(fn,ctx);ctx.ensureSelectionVisible();
assert.equal(ctx.win.scrollTarget,0,'initial layout must not scroll before width resolves');
ctx.width=956;ctx.currentIndex=2; // currentItem can still refer to previous delegate in indexChanged
ctx.ensureSelectionVisible();assert.equal(ctx.win.scrollTarget,0);
ctx.currentIndex=7;ctx.ensureSelectionVisible();assert.equal(ctx.win.scrollTarget,282,'use current index, not stale currentItem');
console.log('PASS: stable startup viewport and no stale-delegate correction');
