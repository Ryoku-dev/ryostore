export const languages=['auto','pt','en','es','fr'];
export const nativeNames={pt:'Português',en:'English',es:'Español',fr:'Français'};
export function normalize(value) {
    const name=String(value||'').trim().toLowerCase().replace(/_/g,'-').split(/[.@]/)[0];
    if(name==='c'||name==='posix')return 'en';
    const base=name.split('-')[0];return languages.indexOf(base)>0?base:null;
}
export function resolve(selection,ryoku,env) {
    const explicit=normalize(selection);
    if(explicit)return {language:explicit,source:'keymoji',requested:explicit};
    const desktop=normalize(ryoku);
    if(desktop)return {language:desktop,source:'ryoku',requested:'auto'};
    const e=env||{}, value=e.LC_ALL||e.LANGUAGE||e.LC_MESSAGES||e.LANG||e.qtLocale||'en';
    const candidates=String(value).split(':');
    return {language:candidates.map(normalize).find(Boolean)||'en',source:'environment',requested:'auto'};
}
export function format(template,params) {return String(template).replace(/\{(\w+)\}/g,(token,key)=>params&&params[key]!==undefined?String(params[key]):token);}

export function countKey(language,count) {return (language==='fr'?(count===0||count===1):count===1)?'count.one':'count';}
