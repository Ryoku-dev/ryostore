.pragma library

// The phone's navigation, as plain functions so it can be tested with node
// (tests/route-test/route_unit.js) and the QML only has to hold the state.
//
// The model (Concept D, "Phone + Stage"):
//   - one phone, one stack of screens. Quick is the usual first screen.
//   - `floor` is the screen the phone was opened on. Back pops the stack and
//     never goes to a screen you have not been on; at the floor it closes.
//   - Home always means Quick: the stack is cleared down to Quick.
//   - a heads-up alert is not a screen, so it never goes through here.
//
// A state is { stack: ["quick", "apps"] }, top of the stack last. Nothing here
// changes a state in place: every function returns a new one.

var QUICK = "quick"
var APPS = "apps"
var AI = "ai"
var SETTINGS = "settings"
var WALLPAPERS = "wallpapers"

var ALL = [QUICK, APPS, WALLPAPERS, SETTINGS, AI]

function isScreen(name) {
    return ALL.indexOf(name) >= 0
}

function open(entry) {
    return { stack: [isScreen(entry) ? entry : QUICK] }
}

function top(state) {
    return state.stack.length > 0 ? state.stack[state.stack.length - 1] : QUICK
}

function floor(state) {
    return state.stack.length > 0 ? state.stack[0] : QUICK
}

// Go to a screen. Asking for the one already showing changes nothing; asking
// for one that is already lower in the stack goes back to it (so the stack
// never holds the same screen twice and Back stays predictable).
function go(state, name) {
    if (!isScreen(name))
        return state
    var at = state.stack.indexOf(name)
    if (at === state.stack.length - 1)
        return state
    if (at >= 0)
        return { stack: state.stack.slice(0, at + 1) }
    return { stack: state.stack.concat([name]) }
}

function back(state) {
    if (state.stack.length <= 1)
        return { state: state, closed: true }
    return { state: { stack: state.stack.slice(0, state.stack.length - 1) }, closed: false }
}

function home(state) {
    return { stack: [QUICK] }
}

function byNumber(n) {
    return n >= 1 && n <= ALL.length ? ALL[n - 1] : ""
}

function startsSearch(text, ctrl, alt, meta) {
    if (ctrl || alt || meta)
        return false
    if (!text || text.length !== 1)
        return false
    var c = text.charCodeAt(0)
    return c > 32 && c !== 127
}
