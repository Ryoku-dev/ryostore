// Pure logic for the Coffee plugin: kept QML-free so it can be unit-tested in
// plain Node.js. Loaded from QML with `import "Logic.js" as Logic` and from
// Node with the loader shim in tests/logic.test.cjs (QML .js files carry no
// CommonJS exports).

// Single source of truth for the inhibitor the host Ryoku desktop ships:
// the shell's own Keep-Awake runs `~/.config/hypr/scripts/ryoku-cmd-caffeine`
// (see the shell's syncCaffeine). Coffee drives that same bridge so its state
// always agrees with the deck toggle and survives a shell restart.
// "%HOME%" is a placeholder the service rewrites to pluginApi.home at runtime,
// and the helperPath setting overrides the whole path when non-blank.
var defaultCaffeineScript = "%HOME%/.config/hypr/scripts/ryoku-cmd-caffeine";

function resolveScript(setting, home) {
  var s = String(setting || "").trim();
  if (s) return s;
  return defaultCaffeineScript.replace("%HOME%", String(home || ""));
}

function argvFor(script, action) {
  return ["timeout", "--kill-after=2s", "12s", script, action];
}

// After a start/stop/hold action the process exits before systemd-run finishes
// spawning the inhibitor, so the first status poll can briefly report the old
// state. expectedState lets a view mask that window instead of flickering.
function expectedState(action) {
  if (action === "start" || action === "hold") return true;
  if (action === "stop" || action === "release") return false;
  return null;
}

// A poll that just completed must not clobber the optimistic state of an action
// still in flight, but it must retire an expectation that has outlived the
// settle window (expiry is a monotonic ms timestamp; Infinity = until settled).
function settleExpected(expected, expectedUntil, now) {
  if (expected === null || expected === undefined) return null;
  if (expectedUntil !== Infinity && now >= expectedUntil) return null;
  return expected;
}

function commandError(code, status, stderr) {
  var detail = String(stderr || "").trim();
  if (code === 0 && status === 0) return "";
  return "Command failed (exit " + code + ", status " + status + ")" + (detail ? ": " + detail : ".");
}

// elapsed ms -> compact "Awake 2h 5m" style duration. "" before the clock has
// a real start time.
function formatElapsed(ms) {
  if (typeof ms !== "number" || isNaN(ms) || ms < 0) return "";
  var totalMin = Math.floor(ms / 60000);
  if (totalMin < 1) return "just now";
  var h = Math.floor(totalMin / 60);
  var m = totalMin % 60;
  if (h < 1) return m + "m";
  if (m === 0) return h + "h";
  return h + "h " + m + "m";
}
