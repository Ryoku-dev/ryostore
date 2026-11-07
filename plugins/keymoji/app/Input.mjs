export function command(text, target, current, searching) {
    if(searching || !target || current!==target)throw new Error('O foco mudou. Clique no campo de destino e selecione novamente.');
    if(!text || text.length>128 || /[\x00-\x1f\x7f]/.test(text))throw new Error('Sequência inválida.');
    return ['wtype','--',text];
}
