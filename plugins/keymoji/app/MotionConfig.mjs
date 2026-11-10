const fallbackCurve=[0.25,0.1,0.25,1,1,1];
export function resolve(desktop,performance,live) {
    const perf=performance||{}, d=desktop||{};
    const enabled=d.desktop?.appearance?.animations!==false&&!perf.reduceMotion&&!perf.lowPowerMode;
    const tempo=typeof perf.motionSpeed==='number'&&perf.motionSpeed>0&&perf.motionSpeed<=8?perf.motionSpeed:1;
    // Read the published animation tree structurally, without compositor IPC.
    const registry=Object.values(live?.wm||{}).map(provider=>provider?.anim).find(anim=>Array.isArray(anim?.items)) || Object.values(d.wm||{}).map(provider=>provider?.anim).find(anim=>Array.isArray(anim?.items));
    function leaf(chain) {
        let item={enabled:true,speed:3,bezier:'',style:'fade'};
        for(const name of chain){const override=registry?.items.find(i=>i.leaf===name);if(override)item=Object.assign({},item,override);}
        const curve=registry?.curves?.find(c=>c.name===item.bezier);
        const valid=curve&&[curve.x0,curve.y0,curve.x1,curve.y1].every(Number.isFinite)&&curve.x0>=0&&curve.x0<=1&&curve.x1>=0&&curve.x1<=1;
        const ms=Number.isFinite(item.speed)&&item.speed>0?item.speed*100:300;
        return {ms:enabled&&item.enabled!==false?Math.round(Math.min(3000,Math.max(1,ms*tempo))):0,curve:valid?[curve.x0,curve.y0,curve.x1,curve.y1,1,1]:fallbackCurve,name:item.bezier,style:item.style||'fade'};
    }
    return {enabled,enter:leaf(['global','layers','layersIn']),exit:leaf(['global','layers','layersOut']),transition:leaf(['global','windows','windowsMove']),fadeIn:leaf(['global','fade','fadeIn','fadeLayers','fadeLayersIn']),fadeOut:leaf(['global','fade','fadeOut','fadeLayers','fadeLayersOut']),source:live?.wm?'effective':'persisted'};
}
