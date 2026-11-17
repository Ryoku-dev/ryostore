export function command(text, target, current, searching) {
    if(searching || !target || current!==target)throw new Error('input.focusChanged');
    if(!text || text.length>128 || /[\x00-\x1f\x7f]/.test(text))throw new Error('input.invalidSequence');
    return ['wtype','--',text];
}

export function lastEmoji(history) {
    const emoji=history && Array.isArray(history.recent) ? history.recent[0] : null;
    if(typeof emoji!=='string' || !emoji || emoji.length>128 || /[\x00-\x1f\x7f]/.test(emoji))throw new Error('input.noRecentEmoji');
    return emoji;
}
