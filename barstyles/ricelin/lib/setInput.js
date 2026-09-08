/**
 * Reads the current value of a `name = <value>` Lua field. A double-quoted value
 * is returned unquoted; any other run is trimmed. Returns "" when the field is
 * absent.
 */
function getField(text, name) {
    var re = new RegExp(name + "\\s*=\\s*(\"[^\"]*\"|[^,}\\n]*)");
    var m = re.exec(text);
    if (!m)
        return "";
    var v = m[1].trim();
    if (v.length >= 2 && v.charAt(0) === "\"" && v.charAt(v.length - 1) === "\"")
        return v.slice(1, -1);
    return v;
}

/**
 * Replaces the value of a single `name = <value>` field in place, preserving the
 * field name, the `=` spacing and any trailing comma. A quoted value run is taken
 * whole so a comma inside the quotes is not mistaken for the field end; otherwise
 * the run goes up to the next comma, brace or newline. `valueLiteral` is already
 * formatted by the caller (a number/bool as-is, a string already double-quoted).
 * Returns `{ text, ok }`; ok is false (text unchanged) when the field is absent.
 */
function setField(text, name, valueLiteral) {
    var re = new RegExp("(" + name + "\\s*=\\s*)(\"[^\"]*\"|[^,}\\n]*)");
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "$1" + valueLiteral), ok: true };
}

/**
 * Replaces the second argument of a `hl.env("KEY", "<old>")` call with the raw
 * value, re-quoted. Returns `{ text, ok }`; ok is false when the key's env call is
 * absent.
 */
function setEnv(text, key, valueRaw) {
    var re = new RegExp("(hl\\.env\\(\\s*\"" + escapeRe(key) + "\"\\s*,\\s*)\"[^\"]*\"");
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "$1\"" + valueRaw + "\""), ok: true };
}

/**
 * Replaces the theme name and size in a `hyprctl setcursor <theme> <size>` call.
 * Returns `{ text, ok }`; ok is false when the call is absent.
 */
function setCursorLine(text, theme, size) {
    var re = /setcursor\s+\S+\s+\d+/;
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "setcursor " + theme + " " + size), ok: true };
}

function escapeRe(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
