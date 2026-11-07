import {test,expect} from 'bun:test';
import {resolve,defaults} from '../app/Palette.mjs';
test('fora do Ryoku conserva a paleta própria',()=>{expect(resolve({primary:'#ffffff'},{surface:'#000000'},true,false)).toEqual(defaults);});
test('tema nomeado precede a paleta do wallpaper',()=>{const roles=resolve({primary:'#ff1234'},{primary:'#abcdef',surface:'#eeeeee',onSurface:'#111111'},true,true);expect(roles.primary).toBe('#ff1234');expect(roles.surface).toBe('#eeeeee');expect(roles.onSurface).toBe('#111111');});
test('desativar wallpaper e valores inválidos não apagam a interface',()=>{expect(resolve(null,{surface:'#ffffff'},false,true).surface).toBe(defaults.surface);expect(resolve({primary:null,surface:'invalid'},{primary:'#aabbcc'},true,true).primary).toBe('#aabbcc');});
