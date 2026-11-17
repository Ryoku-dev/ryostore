export function fold(s) { return String(s).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/œ/g,'oe').replace(/æ/g,'ae').replace(/ß/g,'ss').replace(/[:_\-]+/g, ' ').trim(); }
export const groupIds=['all','recent','favorites','faces','people','nature','food','travel','activities','objects','symbols','flags'];
const aliases={'Todos':'all','Recentes':'recent','Favoritos':'favorites','Rostos e emoções':'faces','Pessoas e corpo':'people','Animais e natureza':'nature','Comidas e bebidas':'food','Viagens e lugares':'travel','Atividades':'activities','Objetos':'objects','Símbolos':'symbols','Bandeiras':'flags'};
export function indexCatalog(data,annotations,english={},groupLabels={},language='pt') {
    const rows=[];
    data.groups.forEach(g=>g.subs.forEach(sub=>sub.l.forEach(it=>{
        const id=aliases[g.g]||g.g,local=annotations&&annotations[it.e]||{},en=english[it.e]||{};
        const suffix=String(it.k||'').match(/E\d+(?:\.\d+)*\s+(.+)$/);
        const fallback=en.n||(suffix?suffix[1]:it.n);
        const name=annotations?(local.n||fallback):it.n;
        const keywords=annotations?((local.k||'')+' '+(en.n||fallback)+' '+(en.k||'')+' '+(language==='pt'?(it.k||''):'')):(it.k||'');
        const searchable=fold(name+' '+keywords+' '+(groupLabels[id]||g.g)+' '+sub.s);
        const words=Array.from(new Set(searchable.split(/\s+/)));
        const wordsByLength={};
        words.forEach(word=>(wordsByLength[word.length]||(wordsByLength[word.length]=[])).push(word));
        rows.push({words,wordsByLength,e:it.e,n:name,g:id,sub:sub.s,k:keywords,name:fold(name),search:searchable,code:Array.from(it.e).map(c=>'U+'+c.codePointAt(0).toString(16).toUpperCase()).join(' ')});
    })));
    return rows;
}
function near(a,b) {
    if (a.length < 4 || Math.abs(a.length-b.length)>1) return false;
    if(a.length===b.length) { const diff=[]; for(let k=0;k<a.length;k++)if(a[k]!==b[k])diff.push(k); if(diff.length===2 && diff[1]===diff[0]+1 && a[diff[0]]===b[diff[1]] && a[diff[1]]===b[diff[0]])return true; }
    let i=0,j=0,errors=0;
    while(i<a.length && j<b.length) {
        if(a[i]===b[j]) {i++;j++;continue;}
        if(++errors>1) return false;
        if(a.length>=b.length)i++;
        if(b.length>=a.length)j++;
    }
    return errors+(a.length-i)+(b.length-j)<=1;
}
export function search(rows, query, group, favorites, recent) {
    group=aliases[group]||group||'all';
    const q=fold(query), tokens=q.split(/\s+/).filter(Boolean);
    const fav=favorites||[], rec=recent||[];
    return rows.map((r,i)=>{
        if(group==='favorites' && fav.indexOf(r.e)<0) return null;
        if(group==='recent' && rec.indexOf(r.e)<0) return null;
        if(group && ['all','favorites','recent'].indexOf(group)<0 && r.g!==group) return null;
        if(!q) return {r,score:group==='recent'?1000-rec.indexOf(r.e):0,i};
        if(r.e===query.trim() || fold(r.code)===q) return {r,score:2000,i};
        if(r.e.includes(query.trim())) return {r,score:1500,i};
        let score=r.name===q?1000:r.name.indexOf(q)===0?500:0;
        const words=r.words;
        for(const t of tokens) {
            if(words.indexOf(t)>=0) score+=80;
            else if(words.some(w=>w.indexOf(t)===0))score+=40;
            else if(r.search.indexOf(t)>=0)score+=15;
            else if(t.length>=4 && [t.length-1,t.length,t.length+1].some(length=>(r.wordsByLength[length]||[]).some(w=>near(t,w))))score+=5;
            else return null;
        }
        return {r,score,i};
    }).filter(Boolean).sort((a,b)=>b.score-a.score||a.i-b.i).map(x=>x.r);
}
