export function nextIndex(index, direction, count, columns, pageRows=1) {
    if(count<=0)return -1;
    const current=Math.max(0,Math.min(count-1,index));
    const cols=Math.max(1,Math.floor(columns));
    if(direction==='first')return 0;
    if(direction==='last')return count-1;
    if(direction==='left')return Math.max(0,current-1);
    if(direction==='right')return Math.min(count-1,current+1);
    if(direction==='up')return current<cols?current:current-cols;
    if(direction==='down')return Math.floor(current/cols)>=Math.floor((count-1)/cols)?current:Math.min(count-1,current+cols);
    const page=cols*Math.max(1,Math.floor(pageRows));
    if(direction==='pageUp')return Math.max(0,current-page);
    if(direction==='pageDown')return Math.min(count-1,current+page);
    return current;
}
