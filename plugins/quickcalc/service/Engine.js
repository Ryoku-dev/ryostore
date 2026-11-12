.pragma library

// Pure, dependency-free arithmetic engine for QuickCalc. No eval() or
// Function(): a hand-written tokenizer plus a small recursive-descent parser.
// Values are JS doubles. Tested by tests/engine.test.cjs (node), which loads this
// file with its first line stripped, so keep it free of QML-only syntax.
//
// Grammar, loosest to tightest:
//   statement  := [name "="] expr ["="]
//   expr       := shift
//   shift      := additive (("<<" | ">>") additive)*
//   additive   := mult (("+" | "-") mult)*
//   mult       := unary (("*" | "/") unary | <implicit> power)*
//   unary      := ("-" | "+") unary | power
//   power      := postfix ["^" unary]          (right-associative)
//   postfix    := primary ("!" | "%")*
//   primary    := number | name | name "(" args ")" | "(" expr ")"
//
// Implicit multiplication: a number, name or "(" directly after a value
// multiplies it (2pi, 3(4+5), (1+2)(3+4), 2sin(30)), at the same precedence
// as "*".
//
// Percent (%) is always postfix "divide by 100" (50% -> 0.5), never the
// "percent-of-the-left-operand" retail convention; use mod(a, b) for the
// remainder operator.
//
// Programmer mode (ctx.programmer): bare digits are read in ctx.base (2, 8,
// 10 or 16; in base 16 a bare word made only of hex digits, not followed by
// "(", is a number), explicit 0x/0o/0b prefixes always win, and the final
// result is truncated and wrapped to a signed 32-bit integer -- the same
// width the bitwise helpers and shift operators use. (So in HEX, 0B1 is the
// binary literal 1; write B1 or 0x0B1 for the hex value.)

var CONSTANTS = { "pi": Math.PI, "e": Math.E };
var PREFIX = { 16: "0x", 8: "0o", 2: "0b" };

function factorial(n) {
    if (n < 0 || n !== Math.floor(n)) throw new Error("Domain error");
    if (n > 170) return Infinity;
    var r = 1;
    for (var i = 2; i <= n; i++) r *= i;
    return r;
}
function bAnd(a, b) { return (a | 0) & (b | 0); }
function bOr(a, b)  { return (a | 0) | (b | 0); }
function bXor(a, b) { return (a | 0) ^ (b | 0); }
function bNot(a)    { return ~(a | 0); }
function bShl(a, b) { return (a | 0) << (b | 0); }
function bShr(a, b) { return (a | 0) >> (b | 0); }
function logBase(x, b) {
    if (!(b > 0) || b === 1) throw new Error("Domain error"); // no such base
    return Math.log(x) / Math.log(b);
}

// Degree-mode trig with exact zeros at the multiples where the double
// approximation of pi would otherwise leave residue (sin(180) = 1.2e-16,
// tan(90) = 1.6e16 instead of undefined).
function mod360(x) { var r = x % 360; return r < 0 ? r + 360 : r; }
function degSin(x) { var r = mod360(x); return r % 180 === 0 ? 0 : Math.sin(x * Math.PI / 180); }
function degCos(x) { var r = mod360(x); return r % 180 === 90 ? 0 : Math.cos(x * Math.PI / 180); }
function degTan(x) {
    var r = mod360(x) % 180;
    if (r === 90) throw new Error("Domain error");
    return r === 0 ? 0 : Math.tan(x * Math.PI / 180);
}
function makeInvTrig(fn, angleMode) {
    return function (x) {
        var r = fn(x);
        return angleMode === "deg" ? r * 180 / Math.PI : r;
    };
}

// 1-argument functions. Trig depends on the active angle mode, so this is
// built per evaluation rather than kept as one static table.
function functionsFor(angleMode) {
    var deg = angleMode === "deg";
    return {
        sin: deg ? degSin : Math.sin, cos: deg ? degCos : Math.cos, tan: deg ? degTan : Math.tan,
        asin: makeInvTrig(Math.asin, angleMode), acos: makeInvTrig(Math.acos, angleMode), atan: makeInvTrig(Math.atan, angleMode),
        sinh: Math.sinh, cosh: Math.cosh, tanh: Math.tanh,
        sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs,
        floor: Math.floor, ceil: Math.ceil, round: Math.round, trunc: Math.trunc,
        sign: Math.sign, exp: Math.exp, ln: Math.log, log: Math.log10, log2: Math.log2,
        fact: factorial, not: bNot, bnot: bNot
    };
}
var FUNCTIONS1 = functionsFor("rad"); // name lookup only
// 2-argument functions (fixed set; none depend on angle mode).
var FUNCTIONS2 = {
    pow: Math.pow, mod: function (a, b) { return a % b; }, log: logBase, atan2: Math.atan2,
    and: bAnd, band: bAnd, or: bOr, bor: bOr, xor: bXor, bxor: bXor, shl: bShl, shr: bShr
};
// Own-property lookups only: a plain object also "has" constructor,
// __proto__ and friends, which made `__proto__(1)` throw a raw TypeError.
function has(obj, name) { return !!obj && Object.prototype.hasOwnProperty.call(obj, name); }
function isFunctionName(name) { return has(FUNCTIONS1, name) || has(FUNCTIONS2, name); }
// __proto__ can't be a variable: assigning it on a plain object changes the
// object's prototype instead of storing a value.
function isReservedName(name) { return name === "ans" || name === "__proto__" || has(CONSTANTS, name) || isFunctionName(name); }

// Guards against pathological input reaching the JS stack or stalling the
// live preview (it re-evaluates on every keystroke).
var MAX_LENGTH = 2000;
var MAX_DEPTH = 200;

// Unicode operator aliases, so pasted or keypad-styled text still parses.
var ALIASES = { "×": "*", "÷": "/", "−": "-", "–": "-" };

function digitValue(c) {
    var code = c.toLowerCase().charCodeAt(0);
    if (code >= 48 && code <= 57) return code - 48;   // 0-9
    if (code >= 97 && code <= 102) return code - 87;  // a-f
    return 99;
}
function parseInBase(digits, base) {
    var v = 0;
    for (var k = 0; k < digits.length; k++) {
        var d = digitValue(digits[k]);
        if (d >= base) throw new Error("'" + digits[k] + "' is not a base-" + base + " digit");
        v = v * base + d;
    }
    return v;
}

// ctx: { base, programmer, vars } -- only base/programmer/vars matter here.
function tokenize(src, ctx) {
    ctx = ctx || {};
    var base = ctx.programmer && ctx.base ? ctx.base : 10;
    var vars = ctx.vars || {};
    var toks = [], i = 0, n = src.length;
    function isDigit(c) { return c >= "0" && c <= "9"; }
    function isHex(c) { return /[0-9a-fA-F]/.test(c); }
    function isAlnum(c) { return c !== undefined && /[a-zA-Z0-9_]/.test(c); }
    function isSpace(c) { return /\s/.test(c); }
    function nextNonSpace(j) { while (j < n && isSpace(src[j])) j++; return src[j]; }
    // "word = <something>" at the start of the line: an assignment target.
    // A bare trailing "=" ("FF=") is not one -- that just evaluates.
    function assignsAt(j) {
        while (j < n && isSpace(src[j])) j++;
        if (src[j] !== "=") return false;
        j++;
        while (j < n && isSpace(src[j])) j++;
        return j < n && src[j] !== "=";
    }
    function prefixed(re, b, label) {
        i += 2;
        var start = i;
        while (i < n && re.test(src[i])) i++;
        if (i === start) throw new Error("Bad " + label + " literal");
        if (isDigit(src[i] || "")) throw new Error("'" + src[i] + "' is not a base-" + b + " digit");
        if (src[i] === ".") throw new Error("Unexpected '.'");
        toks.push({ t: "num", v: parseInt(src.slice(start, i), b) });
    }
    while (i < n) {
        var c = ALIASES[src[i]] || src[i];
        if (isSpace(c)) { i++; continue; }
        if (c === "∞") { toks.push({ t: "num", v: Infinity }); i++; continue; }
        if (c === "π") { toks.push({ t: "id", v: "pi" }); i++; continue; }
        if (c === "0" && /[xX]/.test(src[i + 1] || "")) { prefixed(/[0-9a-fA-F]/, 16, "hex"); continue; }
        if (c === "0" && /[oO]/.test(src[i + 1] || "")) { prefixed(/[0-7]/, 8, "octal"); continue; }
        if (c === "0" && /[bB]/.test(src[i + 1] || "")) { prefixed(/[01]/, 2, "binary"); continue; }
        if (base !== 10 && isDigit(c)) {
            var bs = i;
            while (i < n && (base === 16 ? isHex(src[i]) : isDigit(src[i]))) i++;
            toks.push({ t: "num", v: parseInBase(src.slice(bs, i), base) });
            continue;
        }
        if (isDigit(c) || c === ".") {
            if (base !== 10) throw new Error("Fractions need the DEC base");
            var start = i;
            while (i < n && isDigit(src[i])) i++;
            if (src[i] === ".") { i++; while (i < n && isDigit(src[i])) i++; }
            if (i - start === 1 && c === ".") throw new Error("Unexpected '.'");
            if (src[i] === "e" || src[i] === "E") {
                var save = i; i++;
                if (src[i] === "+" || src[i] === "-") i++;
                if (isDigit(src[i])) { while (i < n && isDigit(src[i])) i++; }
                else i = save;
            }
            if (src[i] === ".") throw new Error("Unexpected '.'"); // 1..2, 1.2.3
            toks.push({ t: "num", v: parseFloat(src.slice(start, i)) });
            continue;
        }
        if (/[a-zA-Z_]/.test(c)) {
            var s = i;
            while (i < n && isAlnum(src[i])) i++;
            var word = src.slice(s, i);
            var lower = word.toLowerCase();
            if (base === 16 && /^[0-9a-fA-F]+$/.test(word) && nextNonSpace(i) !== "("
                    && !has(vars, lower) && !(toks.length === 0 && assignsAt(i))) {
                toks.push({ t: "num", v: parseInt(word, 16) });
                continue;
            }
            toks.push({ t: "id", v: lower });
            continue;
        }
        if (c === "<" && src[i + 1] === "<") { toks.push({ t: "op", v: "<<" }); i += 2; continue; }
        if (c === ">" && src[i + 1] === ">") { toks.push({ t: "op", v: ">>" }); i += 2; continue; }
        if ("+-*/^%!(),=".indexOf(c) >= 0) {
            toks.push({ t: (c === "(" || c === ")") ? "paren" : "op", v: c });
            i++;
            continue;
        }
        throw new Error("Unexpected character '" + c + "'");
    }
    return toks;
}

function Parser(toks, ctx) {
    this.toks = toks;
    this.pos = 0;
    this.ctx = ctx; // { angleMode, ans, vars }
    this.depth = 0;
    this.fns1 = functionsFor(ctx.angleMode);
}
Parser.prototype.peek = function () { return this.toks[this.pos]; };
Parser.prototype.next = function () { return this.toks[this.pos++]; };
Parser.prototype.expect = function (v) {
    var t = this.next();
    if (!t || t.v !== v) throw new Error("Expected '" + v + "'");
    return t;
};
Parser.prototype.atEnd = function () { return this.pos >= this.toks.length; };
Parser.prototype.isOp = function (v) { return !this.atEnd() && this.peek().t === "op" && this.peek().v === v; };
// A token that can begin a value, for implicit multiplication.
Parser.prototype.startsValue = function () {
    var t = this.peek();
    return !!t && (t.t === "num" || t.t === "id" || (t.t === "paren" && t.v === "("));
};

Parser.prototype.parseExpression = function () { return this.parseShift(); };

Parser.prototype.parseShift = function () {
    var left = this.parseAdditive();
    while (this.isOp("<<") || this.isOp(">>")) {
        var op = this.next().v;
        var right = this.parseAdditive();
        left = op === "<<" ? bShl(left, right) : bShr(left, right);
    }
    return left;
};
Parser.prototype.parseAdditive = function () {
    var left = this.parseMultiplicative();
    while (this.isOp("+") || this.isOp("-")) {
        var op = this.next().v;
        var right = this.parseMultiplicative();
        left = op === "+" ? left + right : left - right;
    }
    return left;
};
Parser.prototype.parseMultiplicative = function () {
    var left = this.parseUnary();
    for (;;) {
        if (this.isOp("*") || this.isOp("/")) {
            var op = this.next().v;
            var right = this.parseUnary();
            left = op === "*" ? left * right : left / right;
        } else if (this.startsValue()) {
            left = left * this.parsePower();
        } else {
            return left;
        }
    }
};
// Every recursive path (parentheses, function arguments, unary signs,
// power chains) passes through here, so this one counter bounds the depth.
Parser.prototype.parseUnary = function () {
    if (++this.depth > MAX_DEPTH) throw new Error("Expression is nested too deeply");
    var v;
    if (this.isOp("-") || this.isOp("+")) {
        var op = this.next().v;
        v = this.parseUnary();
        v = op === "-" ? -v : v;
    } else {
        v = this.parsePower();
    }
    this.depth--;
    return v;
};
Parser.prototype.parsePower = function () {
    var base = this.parsePostfix();
    if (this.isOp("^")) {
        this.next();
        var exp = this.parseUnary(); // right-associative, so 2^-2 works
        return Math.pow(base, exp);
    }
    return base;
};
Parser.prototype.parsePostfix = function () {
    var v = this.parsePrimary();
    while (this.isOp("!") || this.isOp("%")) {
        var op = this.next().v;
        v = op === "!" ? factorial(v) : v / 100;
    }
    return v;
};
Parser.prototype.parsePrimary = function () {
    var t = this.next();
    if (!t) throw new Error("Unexpected end of expression");
    if (t.t === "num") return t.v;
    if (t.t === "paren" && t.v === "(") {
        var v = this.parseExpression();
        this.expect(")");
        return v;
    }
    if (t.t === "id") {
        var name = t.v;
        var vars = this.ctx.vars || {};
        var callable = isFunctionName(name);
        if (callable && !this.atEnd() && this.peek().t === "paren" && this.peek().v === "(") {
            this.next();
            var args = [this.parseExpression()];
            while (this.isOp(",")) { this.next(); args.push(this.parseExpression()); }
            this.expect(")");
            if (args.length === 1) {
                if (has(this.fns1, name)) return this.fns1[name](args[0]);
                throw new Error(name + "() needs 2 arguments");
            }
            if (args.length === 2) {
                if (has(FUNCTIONS2, name)) return FUNCTIONS2[name](args[0], args[1]);
                throw new Error(name + "() takes 1 argument");
            }
            throw new Error("Too many arguments to " + name + "()");
        }
        if (name === "ans") return this.ctx.ans || 0;
        if (has(vars, name) && typeof vars[name] === "number") return vars[name];
        if (has(CONSTANTS, name)) return CONSTANTS[name];
        if (callable) throw new Error(name + " needs parentheses: " + name + "(…)");
        throw new Error("Unknown name: " + name);
    }
    if (t.t === "op") throw new Error("Unexpected '" + t.v + "'");
    throw new Error("Unexpected ')'");
};

function normalizeCtx(ctx) {
    ctx = ctx || {};
    return {
        angleMode: ctx.angleMode === "rad" ? "rad" : "deg",
        ans: ctx.ans || 0,
        vars: ctx.vars || {},
        programmer: !!ctx.programmer,
        base: ctx.programmer && PREFIX[ctx.base] ? ctx.base : 10,
        // { text, value }: the previous result as it was written back into
        // the input. When the expression still starts with that exact text it
        // stands for the full-precision value, so chaining 1/3 = then *3
        // gives 1, not 0.9999999999.
        carry: ctx.carry || null
    };
}

function tokenizeWithCarry(text, c) {
    var carry = c.carry;
    if (carry && carry.text && text.indexOf(carry.text) === 0) {
        var after = text[carry.text.length];
        if (after === undefined || !/[0-9a-zA-Z_.]/.test(after)) {
            // A negative result is written back as "-x". Keep that minus a
            // unary operator, so "-2" then "^2" is -(2^2) = -4 exactly as
            // typing "-2^2" would be, not (-2)^2.
            var head = carry.text[0] === "-" && carry.value < 0
                ? [{ t: "op", v: "-" }, { t: "num", v: -carry.value }]
                : [{ t: "num", v: carry.value }];
            return head.concat(tokenize(text.slice(carry.text.length), c));
        }
    }
    return tokenize(text, c);
}

// Evaluates one line. Returns { value, name } -- name is the variable the
// line assigned ("x = 5"), or "" for a plain expression. A trailing "=" is
// ignored, so "2+2=" works like "2+2".
function evaluateStatement(src, ctx) {
    var c = normalizeCtx(ctx);
    var text = (src || "").trim();
    if (text.length === 0) throw new Error("Empty expression");
    if (text.length > MAX_LENGTH) throw new Error("Expression too long");
    var toks = tokenizeWithCarry(text, c);
    while (toks.length > 0 && toks[toks.length - 1].t === "op" && toks[toks.length - 1].v === "=") toks.pop();
    if (toks.length === 0) throw new Error("Empty expression");
    var name = "";
    if (toks.length >= 2 && toks[1].t === "op" && toks[1].v === "=") {
        if (toks[0].t !== "id") throw new Error("Can only assign to a name");
        name = toks[0].v;
        if (isReservedName(name)) throw new Error("'" + name + "' is a built-in name");
        toks = toks.slice(2);
        if (toks.length === 0) throw new Error("Nothing to assign");
    }
    var p = new Parser(toks, c);
    var result = p.parseExpression();
    if (!p.atEnd()) {
        var t = p.peek();
        throw new Error("Unexpected '" + t.v + "'");
    }
    if (typeof result !== "number" || Number.isNaN(result)) throw new Error("Domain error");
    if (c.programmer) {
        if (!isFinite(result)) throw new Error("Overflow");
        result = Math.trunc(result) | 0;
    }
    return { value: result, name: name };
}

function evaluate(src, ctx) { return evaluateStatement(src, ctx).value; }

function toBase(value, base) {
    var n = Math.trunc(value);
    var u = n < 0 ? (n >>> 0) : n; // 32-bit two's-complement view for negatives
    return u.toString(base).toUpperCase();
}

// Splits a digit string into groups of `size` from the right ("11111111" ->
// "1111 1111"), for the programmer-mode base readout.
function groupDigits(str, size, sep) {
    var out = "";
    for (var k = str.length; k > 0; k -= size)
        out = str.slice(Math.max(0, k - size), k) + (out.length ? (sep || " ") + out : "");
    return out;
}

function roundTo(value, precision) {
    if (!isFinite(value) || Math.abs(value) >= 1e15) return value;
    return Number(value.toFixed(precision));
}

function clampPrecision(p) {
    p = p === undefined || p === null || isNaN(p) ? 10 : Math.round(p);
    return Math.max(0, Math.min(15, p));
}

// Display text: opts { precision, thousands, base }. Never parsed back --
// use toInput() for text that goes back into the expression field.
function format(value, opts) {
    opts = opts || {};
    if (value === undefined || value === null || Number.isNaN(value)) return "Error";
    if (value === Infinity) return "∞";
    if (value === -Infinity) return "-∞";
    if (opts.base && opts.base !== 10) return toBase(value, opts.base);
    var precision = clampPrecision(opts.precision);
    var rounded = roundTo(value, precision);
    if (rounded === 0) return "0";
    var abs = Math.abs(rounded);
    var str;
    if (abs >= 1e15 || abs < 1e-9) {
        str = rounded.toExponential(Math.min(precision, 14)).replace(/\.?0+e/, "e");
    } else {
        str = rounded.toString();
        if (opts.thousands && str.indexOf("e") < 0) {
            var neg = str[0] === "-";
            var body = neg ? str.slice(1) : str;
            var parts = body.split(".");
            parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
            str = (neg ? "-" : "") + parts.join(".");
        }
    }
    return str;
}

// Text that parses back to (the rounded) value: no thousands separators, an
// explicit 0x/0o/0b prefix in programmer bases, a real minus sign rather
// than two's complement. Empty for NaN.
function toInput(value, opts) {
    opts = opts || {};
    if (value === undefined || value === null || Number.isNaN(value)) return "";
    if (opts.base && PREFIX[opts.base]) {
        var n = Math.trunc(value);
        return (n < 0 ? "-" : "") + PREFIX[opts.base] + Math.abs(n).toString(opts.base).toUpperCase();
    }
    return format(value, { precision: opts.precision, thousands: false, base: 10 });
}
