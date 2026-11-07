export function fold(s) { return String(s).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[:_\-]+/g, ' ').trim(); }
export function indexCatalog(data) {
    const rows = [];
    data.groups.forEach(g => g.subs.forEach(sub => sub.l.forEach(it => {
        rows.push({e:it.e, n:it.n, g:g.g, sub:sub.s, k:it.k || '', name:fold(it.n), search:fold(it.n+' '+it.k+' '+g.g+' '+sub.s), code:Array.from(it.e).map(c=>'U+'+c.codePointAt(0).toString(16).toUpperCase()).join(' ')});
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
    const q=fold(query), tokens=q.split(/\s+/).filter(Boolean);
    const fav=favorites||[], rec=recent||[];
    return rows.map((r,i)=>{
        if(group==='Favoritos' && fav.indexOf(r.e)<0) return null;
        if(group==='Recentes' && rec.indexOf(r.e)<0) return null;
        if(group && ['Todos','Favoritos','Recentes'].indexOf(group)<0 && r.g!==group) return null;
        if(!q) return {r,score:group==='Recentes'?1000-rec.indexOf(r.e):0,i};
        if(r.e===query.trim() || fold(r.code)===q) return {r,score:2000,i};
        let score=r.name===q?1000:r.name.indexOf(q)===0?500:0;
        const words=r.search.split(/\s+/);
        for(const t of tokens) {
            if(words.indexOf(t)>=0) score+=80;
            else if(words.some(w=>w.indexOf(t)===0))score+=40;
            else if(r.search.indexOf(t)>=0)score+=15;
            else if(words.some(w=>near(t,w)))score+=5;
            else return null;
        }
        return {r,score,i};
    }).filter(Boolean).sort((a,b)=>b.score-a.score||a.i-b.i).map(x=>x.r);
}
