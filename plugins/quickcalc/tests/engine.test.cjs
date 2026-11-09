// Development-only: unit tests for service/Engine.js. The plugin itself never
// runs this. Usage: node tests/engine.test.cjs   (needs node; exits non-zero on failure)
//
// Engine.js is a QML ".pragma library" module, so its first line is dropped
// and the remainder evaluated as plain JS -- the engine has no QML deps.

"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "..", "service", "Engine.js"), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const E = {};
vm.runInNewContext(src + "\n;__out.evaluate=evaluate;__out.evaluateStatement=evaluateStatement;" +
    "__out.format=format;__out.toInput=toInput;__out.groupDigits=groupDigits;", { __out: E });

let failed = 0, passed = 0;
function check(label, got, want) {
    const ok = Object.is(got, want) || (typeof want === "number" && typeof got === "number" && Math.abs(got - want) < 1e-9);
    if (ok) { passed++; return; }
    failed++;
    console.log("FAIL " + label + "\n     got:  " + JSON.stringify(got) + "\n     want: " + JSON.stringify(want));
}
function ev(expr, ctx) {
    try { return E.evaluate(expr, ctx || {}); } catch (e) { return "ERR"; }
}
function errOf(expr, ctx) {
    try { E.evaluate(expr, ctx || {}); return "(no error)"; } catch (e) { return e.message; }
}
const disp = (v, o) => E.format(v, Object.assign({ precision: 10, thousands: true }, o || {}));

// --- arithmetic and precedence
check("add", ev("1+2"), 3);
check("precedence", ev("2+3*4"), 14);
check("parens", ev("(2+3)*4"), 20);
check("unary minus binds looser than ^", ev("-2^2"), -4);
check("power right-assoc", ev("2^3^2"), 512);
check("negative exponent", ev("2^-2"), 0.25);
check("percent postfix", ev("50%"), 0.5);
check("percent in sum", ev("100+10%"), 100.1);
check("factorial", ev("5!"), 120);
check("factorial non-integer", errOf("2.5!"), "Domain error");
check("float noise rounds away", disp(ev("0.1+0.2")), "0.3");
check("scientific literal", ev("1.5e3"), 1500);
check("e constant vs exponent", ev("2e"), 2 * Math.E);
check("trailing = ignored", ev("2+2="), 4);
check("unicode operators", ev("6×7−2÷2"), 41);
check("infinity literal", ev("∞+1"), Infinity);
check("division by zero", ev("1/0"), Infinity);
check("NaN is a domain error", errOf("sqrt(-1)"), "Domain error");
check("unknown name", errOf("foo"), "Unknown name: foo");
check("function needs parens", errOf("sin"), "sin needs parentheses: sin(…)");
check("trailing junk", errOf("1 2 )"), "Unexpected ')'");

// --- implicit multiplication
check("2pi", ev("2pi"), 2 * Math.PI);
check("3(4+5)", ev("3(4+5)"), 27);
check("(1+2)(3+4)", ev("(1+2)(3+4)"), 21);
check("2sin(30)", ev("2sin(30)"), 1);
check("pi(2) is pi*2", ev("pi(2)"), 2 * Math.PI);

// --- functions and trig
check("sin(30) deg", ev("sin(30)"), 0.5);
check("sin(180) exact", ev("sin(180)"), 0);
check("cos(90) exact", ev("cos(90)"), 0);
check("cos(-270) exact", ev("cos(-270)"), 0);
check("tan(90) undefined", errOf("tan(90)"), "Domain error");
check("tan(45)", ev("tan(45)"), 1);
check("rad mode", ev("sin(pi/2)", { angleMode: "rad" }), 1);
check("asin deg", ev("asin(1)"), 90);
check("log base 10", ev("log(1000)"), 3);
check("log base b", ev("log(8,2)"), 3);
check("mod", ev("mod(7,3)"), 1);
check("arity error", errOf("mod(7)"), "mod() needs 2 arguments");

// --- ans, variables, carry
check("ans", ev("ans*10", { ans: 4 }), 40);
const st = E.evaluateStatement("x = 5*2", {});
check("assignment value", st.value, 10);
check("assignment name", st.name, "x");
check("variable use", ev("x^2", { vars: { x: 10 } }), 100);
check("2x implicit with variable", ev("2x", { vars: { x: 10 } }), 20);
check("reserved name", errOf("pi = 3"), "'pi' is a built-in name");
check("carry keeps full precision", ev("0.3333333333*3", { carry: { text: "0.3333333333", value: 1 / 3 } }), 1);
check("negative carry keeps unary precedence", ev("-2^2", { carry: { text: "-2", value: -2 } }), -4);
check("negative carry plain", ev("-2*3", { carry: { text: "-2", value: -2 } }), -6);
check("negative carry full precision", ev("-0.3333333333*3", { carry: { text: "-0.3333333333", value: -1 / 3 } }), -1);
check("carry ignored when edited", ev("0.33333333331", { carry: { text: "0.3333333333", value: 1 / 3 } }), 0.33333333331);

// --- programmer mode
const hex = { programmer: true, base: 16 };
check("hex literal", ev("0xFF"), 255);
check("bad binary", errOf("0b2"), "Bad binary literal");
check("bad binary tail", errOf("0b12"), "'2' is not a base-2 digit");
check("bare hex digits in HEX", ev("FF+1", hex), 256);
check("digit-led hex in HEX", ev("1F", hex), 31);
check("hex word not followed by ( is a number", ev("add", hex), 0xADD);
check("function still callable in HEX", ev("abs(-A)", hex), 10);
check("binary base input", ev("101+1", { programmer: true, base: 2 }), 6);
check("invalid digit for base", errOf("12", { programmer: true, base: 2 }), "'2' is not a base-2 digit");
check("fractions need DEC", errOf("1.5", hex), "Fractions need the DEC base");
check("wraps to int32", ev("0xFFFFFFFF", hex), -1);
check("truncates", ev("7/2", { programmer: true, base: 10 }), 3);
check("overflow", errOf("1/0", hex), "Overflow");
check("shift operators", ev("1<<4"), 16);
check("shift precedence below +", ev("1<<2+1"), 8);
check("bitwise fns", ev("xor(0b1100,0b1010)"), 6);

// --- display format
check("thousands", disp(1234567.5), "1,234,567.5");
check("negative thousands", disp(-1234), "-1,234");
check("no thousands", E.format(1234, { precision: 10 }), "1234");
check("big number not Infinity", disp(1e299), "1e+299");
check("170! mantissa", disp(ev("170!")).indexOf("e+306") > 0, true);
check("2^64 keeps digits", disp(Math.pow(2, 64)), "1.8446744074e+19");
check("tiny", disp(1.5e-12, { precision: 15 }), "1.5e-12");
check("rounds to zero", disp(1e-12), "0");
check("negative zero", disp(-1e-12), "0");
check("precision 0", disp(2.6, { precision: 0 }), "3");
check("infinity", disp(Infinity), "∞");
check("NaN", disp(NaN), "Error");
check("hex display", E.format(255, { base: 16 }), "FF");
check("hex two's complement", E.format(-1, { base: 16 }), "FFFFFFFF");
check("group digits", E.groupDigits("11111111", 4), "1111 1111");
check("group digits uneven", E.groupDigits("101", 4), "101");

// --- HEX base: a-f are digits, so a bare e is 14, not Euler's number
check("hex e is a digit", ev("e", hex), 14);
function stmt(src, ctx) { try { const r = E.evaluateStatement(src, ctx || {}); return r.name + ":" + r.value; } catch (e) { return "ERR " + e.message; } }
check("hex word assignable", stmt("face=5", hex), "face:5");
check("hex single letter assignable", stmt("a = 3", hex), "a:3");
check("hex trailing = still evaluates", stmt("FF=", hex), ":255");
check("hex trailing == still evaluates", stmt("ff ==", hex), ":255");
check("hex word in expression still a number", stmt("face+1", hex), ":64207");
check("hex pi still a constant", ev("pi", hex), 3);
check("dec e is euler", ev("e"), Math.E);

// --- input text round-trips
function roundTrip(v, opts, ctx) { return E.evaluate(E.toInput(v, opts), ctx || {}); }
check("input has no separators", E.toInput(1234567, { precision: 10 }), "1234567");
check("round-trip 1234", roundTrip(1234, { precision: 10 }), 1234);
check("round-trip big", roundTrip(Math.pow(2, 64), { precision: 10 }), 18446744074000000000);
check("round-trip infinity", roundTrip(Infinity, {}), Infinity);
check("round-trip hex", E.toInput(255, { base: 16 }), "0xFF");
check("round-trip negative hex", roundTrip(-1, { base: 16 }, hex), -1);
check("round-trip bin in HEX mode", roundTrip(5, { base: 2 }, hex), 5);
check("round-trip tiny", roundTrip(1.5e-7, { precision: 10 }), 1.5e-7);

// --- hardening (found by fuzzing): clean errors, never a raw JS exception
check("__proto__ is not a function", errOf("__proto__(1)"), "Unknown name: __proto__");
check("constructor is not a name", errOf("constructor"), "Unknown name: constructor");
check("constructor assignable like any name", ev("constructor=3"), 3);
check("__proto__ reserved", errOf("__proto__=3"), "'__proto__' is a built-in name");
check("deep parens bounded", errOf("(".repeat(900) + "1" + ")".repeat(900)), "Expression is nested too deeply");
check("long unary chain bounded", errOf("-".repeat(1500) + "1"), "Expression is nested too deeply");
check("reasonable nesting ok", ev("(".repeat(100) + "1" + ")".repeat(100)), 1);
check("overlong input", errOf("1+".repeat(1500) + "1"), "Expression too long");
check("double dot", errOf("1..2"), "Unexpected '.'");
check("two decimal points", errOf("1.2.3"), "Unexpected '.'");
check("hex literal fraction", errOf("0x1.5"), "Unexpected '.'");
check("log base 1", errOf("log(8,1)"), "Domain error");
check("log base 0", errOf("log(8,0)"), "Domain error");
check("log base negative", errOf("log(8,-2)"), "Domain error");
check("non-breaking space", ev("1\u00a0+\u00a01"), 2);

console.log((failed ? "FAILED" : "ok") + ": " + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
