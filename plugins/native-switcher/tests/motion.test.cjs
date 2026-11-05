const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync(require('node:path').join(__dirname,'../service/Main.qml'),'utf8');
const ctx={engaged:true,shown:true,rendered:true,pendingFocus:'',windows:[{address:'0xa'}],selected:0,focusAddress:a=>ctx.focused=a};
for(const id of ['reveal','dismiss','focusDelay'])ctx[id]={running:false,stop(){this.running=false},restart(){this.running=true}};
vm.createContext(ctx);
for(const name of ['cancel','commit','finishDismiss']){
 const fn=source.match(new RegExp('    function '+name+'\\([^]*?\\n    }'));
 if(fn)vm.runInContext(fn[0],ctx);
}
ctx.commit();
assert.equal(ctx.engaged,false);
assert.equal(ctx.shown,false);
assert.equal(ctx.rendered,true,'exit must keep the surface alive for its animation');
assert.equal(ctx.dismiss.running,true,'exit lifetime timer is required');
assert.equal(ctx.focusDelay.running,false,'never focus under a mapped keyboard layer');
assert.equal(ctx.pendingFocus,'0xa');
ctx.finishDismiss();
assert.equal(ctx.rendered,false);
assert.equal(ctx.focusDelay.running,true);
ctx.engaged=true;ctx.shown=false;ctx.rendered=false;ctx.pendingFocus='';ctx.focusDelay.running=false;
ctx.commit();assert.equal(ctx.focused,'0xa','quick taps still focus immediately');
console.log('PASS: animated dismissal lifetime, unmap-before-focus, immediate quick taps');
