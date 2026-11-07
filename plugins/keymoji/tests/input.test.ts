import {test,expect} from 'bun:test';
import {command} from '../app/Input.mjs';
test('sequência completa sem clipboard nem shell',()=>{const target={};expect(command('👩🏽‍💻',target,target,false)).toEqual(['wtype','--','👩🏽‍💻']);});
test('mudança de foco cancela inserção',()=>{expect(()=>command('😀',{},{},false)).toThrow('input.focusChanged');});
test('não digita na própria busca nem sem destino',()=>{const t={};expect(()=>command('😀',t,t,true)).toThrow();expect(()=>command('😀',null,null,false)).toThrow();});
test('rejeita controles e texto excessivo',()=>{const t={};expect(()=>command('\n',t,t,false)).toThrow('input.invalidSequence');expect(()=>command('a'.repeat(129),t,t,false)).toThrow();});
