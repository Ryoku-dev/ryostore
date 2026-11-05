const assert=require('node:assert/strict'),fs=require('node:fs');
const qml=fs.readFileSync(require('node:path').join(__dirname,'../content/Widget.qml'),'utf8');
assert.doesNotMatch(qml,/color: selected \?/,'keyboard selection must not flash card fill');
assert.doesNotMatch(qml,/scale: card.selected \?/,'keyboard selection must not pulse icons');
assert.match(qml,/border.width: 2; border.color: Theme.accent/,'keep selection visible');
console.log('PASS: keyboard selection has no fill flash or icon pulse');
