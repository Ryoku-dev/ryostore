import {test,expect} from 'bun:test';
import {resolve} from '../app/MotionConfig.mjs';
const data={desktop:{appearance:{animations:true}},wm:{provider:{anim:{curves:[{name:'ryokuWobble',x0:.34,y0:1.56,x1:.64,y1:1}],items:[{leaf:'layers',enabled:true,speed:6.4,bezier:'ryokuWobble'},{leaf:'layersOut',speed:2}]}}}};
test('curva real mantém overshoot e velocidade das layers',()=>{const result=resolve(data,{});expect(result.enter.ms).toBe(640);expect(result.enter.curve).toEqual([.34,1.56,.64,1,1,1]);expect(result.exit.ms).toBe(200);expect(result.exit.curve).toEqual(result.enter.curve);});
test('reduzir movimento, economia e master desligam animações',()=>{for(const p of [{reduceMotion:true},{lowPowerMode:true}])expect(resolve(data,p).enter.ms).toBe(0);expect(resolve({desktop:{appearance:{animations:false}}},{}).transition.ms).toBe(0);});
test('tempo e curvas inválidas têm fallback seguro',()=>{expect(resolve(data,{motionSpeed:2}).enter.ms).toBe(1280);expect(resolve({},{}).enter.curve).toEqual([.25,.1,.25,1,1,1]);});
