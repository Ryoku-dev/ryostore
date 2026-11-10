export const defaults = {surface:'#151d18',surfaceContainer:'#202923',surfaceContainerHigh:'#303a34',outlineVariant:'#354139',primary:'#c7f285',onPrimary:'#172110',onSurface:'#edf4ee',onSurfaceVariant:'#91a496'};
export function usable(value) {return typeof value==='string' && /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(value);}
export function resolve(named,wall,follow,enabled) {
    const palette={};
    Object.keys(defaults).forEach(key=>{palette[key]=enabled&&named&&usable(named[key])?named[key]:enabled&&follow&&wall&&usable(wall[key])?wall[key]:defaults[key];});
    return palette;
}
