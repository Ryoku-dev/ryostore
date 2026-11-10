import {test,expect} from 'bun:test';
import {command,lastEmoji} from '../app/Input.mjs';
test('sequência completa sem clipboard nem shell',()=>{const target={};expect(command('👩🏽‍💻',target,target,false)).toEqual(['wtype','--','👩🏽‍💻']);});
test('mudança de foco cancela inserção',()=>{expect(()=>command('😀',{},{},false)).toThrow('input.focusChanged');});
test('não digita na própria busca nem sem destino',()=>{const t={};expect(()=>command('😀',t,t,true)).toThrow();expect(()=>command('😀',null,null,false)).toThrow();});
test('rejeita controles e texto excessivo',()=>{const t={};expect(()=>command('\n',t,t,false)).toThrow('input.invalidSequence');expect(()=>command('a'.repeat(129),t,t,false)).toThrow();});

test('último emoji preserva sequência e usa primeiro recente',()=>{expect(lastEmoji({recent:['👩🏽‍💻','😀']})).toBe('👩🏽‍💻');});
 test('histórico ausente, vazio e inválido não insere',()=>{for(const value of [null,{}, {recent:[]},{recent:'😀'},{recent:[42]},{recent:['']},{recent:['\n']},{recent:['a'.repeat(129)]}])expect(()=>lastEmoji(value)).toThrow('input.noRecentEmoji');});
