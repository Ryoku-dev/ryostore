import {test,expect} from 'bun:test';
import {indexCatalog,search,fold} from '../app/Search.mjs';
const rows=indexCatalog(await Bun.file('data/emojis.json').json());
test('catálogo completo, sequências e tons preservados',()=>{expect(rows.length).toBeGreaterThan(3500);expect(new Set(rows.map(r=>r.e)).size).toBe(rows.length);expect(rows.some(r=>r.e.includes('\u200d'))).toBe(true);expect(rows.some(r=>r.e.includes('🏽'))).toBe(true);});
test('acentos, português, inglês e múltiplas palavras',()=>{expect(fold('Coração')).toBe('coracao');expect(search(rows,'coracao','Todos',[],[]).some(r=>r.e==='❤️')).toBe(true);expect(search(rows,'rolling laughing','Todos',[],[])[0].e).toBe('🤣');expect(search(rows,'chorando rir','Todos',[],[]).some(r=>r.e==='😂')).toBe(true);});
test('emoji exato, unicode, typo e nenhum resultado',()=>{expect(search(rows,'👩🏽‍💻','Todos',[],[])[0].e).toBe('👩🏽‍💻');expect(search(rows,'U+1F600','Todos',[],[])[0].e).toBe('😀');expect(search(rows,'coracoa','Todos',[],[]).length).toBeGreaterThan(0);expect(search(rows,'zzzzzzzzzz','Todos',[],[])).toEqual([]);});
test('favoritos e recentes',()=>{expect(search(rows,'','Favoritos',['😀'],[]).map(r=>r.e)).toEqual(['😀']);expect(search(rows,'','Recentes',[],['😂','😀']).map(r=>r.e)).toEqual(['😂','😀']);});
test('nomes exatos superam palavras-chave',()=>{const row=rows.find(r=>r.e==='😀');expect(search(rows,row.n,'Todos',[],[])[0].e).toBe('😀');});
