/**
 * Reads the current value of a top-level `name = <value>` Lua field. A
 * double-quoted value is returned unquoted; any other run is trimmed. Returns ""
 * when the field is absent.
 */
function getField(text, name) {
    var re = new RegExp("\\b" + name + "\\s*=\\s*(\"[^\"]*\"|[^,}\\n]*)");
    var m = re.exec(text);
    if (!m)
        return "";
    var v = m[1].trim();
    if (v.length >= 2 && v.charAt(0) === "\"" && v.charAt(v.length - 1) === "\"")
        return v.slice(1, -1);
    return v;
}

/**
 * Replaces the value of a single top-level `name = <value>` field in place,
 * preserving the field name, the `=` spacing and any trailing comma. A quoted
 * value run is taken whole so a comma inside the quotes is not mistaken for the
 * field end; otherwise the run goes up to the next comma, brace or newline.
 * `valueLiteral` is already formatted by the caller (a number/bool as-is, a
 * string already double-quoted). Returns `{ text, ok }`; ok is false (text
 * unchanged) when the field is absent.
 */
function setField(text, name, valueLiteral) {
    var re = new RegExp("(\\b" + name + "\\s*=\\s*)(\"[^\"]*\"|[^,}\\n]*)");
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "$1" + valueLiteral), ok: true };
}

/**
 * Locates a `blockName = { ... }` table and returns its substring, balanced to
 * the matching close brace so a nested table (decoration holds shadow and blur)
 * does not end the scan early. Returns `{ start, end, body }` where `start`/`end`
 * bracket the inner body between the braces, or null when the block is absent.
 */
function getBlock(text, blockName) {
    var head = new RegExp(blockName + "\\s*=\\s*\\{");
    var m = head.exec(text);
    if (!m)
        return null;
    var open = m.index + m[0].length - 1;
    var depth = 0;
    for (var i = open; i < text.length; i++) {
        var c = text.charAt(i);
        if (c === "{") {
            depth++;
        } else if (c === "}") {
            depth--;
            if (depth === 0)
                return { start: open + 1, end: i, body: text.slice(open + 1, i) };
        }
    }
    return null;
}

/**
 * Reads a `name = <value>` field scoped to `blockName`'s body. Returns "" when
 * the block or the field within it is absent.
 */
function getBlockField(text, blockName, name) {
    var blk = getBlock(text, blockName);
    if (!blk)
        return "";
    return getField(blk.body, name);
}

/**
 * Rewrites a `name = <value>` field scoped to `blockName`'s body and splices the
 * block back into the whole text. Scoping keeps a name shared by sibling blocks
 * (e.g. `enabled` in both shadow and blur) from matching the wrong block.
 * Returns `{ text, ok }`; ok is false (text unchanged) when the block or field
 * is absent.
 */
function setBlockField(text, blockName, name, valueLiteral) {
    var blk = getBlock(text, blockName);
    if (!blk)
        return { text: text, ok: false };
    var res = setField(blk.body, name, valueLiteral);
    if (!res.ok)
        return { text: text, ok: false };
    return { text: text.slice(0, blk.start) + res.text + text.slice(blk.end), ok: true };
}

function escapeRe(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Finds the bounds of the `hl.layer_rule({ ... })` call whose body carries
 * `name = "ruleName"`. Walks each `hl.layer_rule(` head, brace-balances to its
 * matching `})`, and returns `{ start, end }` (from the head to just past the
 * close) for the first call that names `ruleName`. Returns null when no such
 * call exists.
 */
function findNamedRule(text, ruleName) {
    var head = /hl\.layer_rule\s*\(\s*\{/g;
    var nameRe = new RegExp("name\\s*=\\s*\"" + escapeRe(ruleName) + "\"");
    var m;
    while ((m = head.exec(text)) !== null) {
        var open = text.indexOf("{", m.index);
        var depth = 0;
        for (var i = open; i < text.length; i++) {
            var c = text.charAt(i);
            if (c === "{") {
                depth++;
            } else if (c === "}") {
                depth--;
                if (depth === 0) {
                    var close = text.indexOf(")", i);
                    if (close === -1)
                        close = i;
                    var end = close + 1;
                    if (nameRe.test(text.slice(m.index, end)))
                        return { start: m.index, end: end };
                    break;
                }
            }
        }
    }
    return null;
}

/**
 * Reports whether an `hl.layer_rule` call named `ruleName` is present.
 */
function hasNamedRule(text, ruleName) {
    return findNamedRule(text, ruleName) !== null;
}

/**
 * Removes the whole `hl.layer_rule({ ... })` call named `ruleName`, together
 * with one trailing newline and the single blank line `addNamedRule` puts in
 * front of an appended rule, leaving the rest of the file byte-identical.
 * Returns `{ text, ok }`; ok is false (text unchanged) when no such rule exists.
 */
function removeNamedRule(text, ruleName) {
    var r = findNamedRule(text, ruleName);
    if (!r)
        return { text: text, ok: false };
    var start = r.start;
    if (text.charAt(start - 1) === "\n" && text.charAt(start - 2) === "\n")
        start--;
    var end = r.end;
    if (text.charAt(end) === "\n")
        end++;
    return { text: text.slice(0, start) + text.slice(end), ok: true };
}

/**
 * Appends `block` (a complete `hl.layer_rule({...})` string) at the end of the
 * file, separated by a blank line, unless that exact block is already present.
 * Returns `{ text, ok }`; ok is false (text unchanged) when the block already
 * exists.
 */
function addNamedRule(text, block) {
    if (text.indexOf(block) !== -1)
        return { text: text, ok: false };
    var sep = text.length === 0 || text.charAt(text.length - 1) === "\n" ? "\n" : "\n\n";
    return { text: text + sep + block, ok: true };
}
