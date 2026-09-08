#!/usr/bin/env python3
"""RyoStore security screen - bounded static screening of catalogue submissions.

This tool statically screens the distributable code and data of a candidate
contribution for the security-relevant patterns the Ryostore plugin policy
(``plugins/AUTHORING.md`` rules R1-R11) and the manifest contract forbid. It is
a *screen*, not a proof of safety:

  * It NEVER executes, imports, sources, builds, or installs any scanned file.
    Python is read with ``ast.parse`` (which does not run code); shell/JS/QML are
    read as text with bounded, comment-aware pattern matching. No candidate
    config, hook, filter, or suppression is trusted.
  * Detection is pattern/AST/structure based. It catches the plausible unsafe
    shapes it knows about; it cannot prove the absence of every unsafe behaviour
    and does not claim full language semantics. Findings marked ``warning`` are
    human-review prompts, not verdicts; ``blocking`` findings are the shapes with
    a clear, low-false-positive justification.
  * Input is bounded (file count, per-file size, total size, per-line length).
    A file too large to screen, or a source that will not parse, produces a
    visible finding rather than a silent pass.

CLI contract::

    security-screen.py --root <candidate> [--staged | --revision <ref>]
                       [--policy-root <trusted>] [--format text|json]

  --root         candidate tree to scan (default: working tree on disk).
  --staged       screen the FULL exact Git index tree instead of the disk tree.
  --revision     screen the FULL exact Git tree at <ref> instead of the disk.
  --policy-root  trusted policy root; the exception allowlist is read only from
                 ``<policy-root>/security/exceptions.json``. Defaults to the repo
                 that ships THIS tool, never to the candidate. A PR can never
                 supply its own allowlist.
  --format       ``text`` (default) or ``json``.

Exit codes: 0 clean, 1 blocking findings, 2 infrastructure/input failure.

JSON envelope::

    {"schema": 1,
     "findings": [{"rule","path","line","severity","message","fingerprint"}],
     "errors": []}

Secret material is redacted: a matched secret's bytes never appear in output or
in a fingerprint.
"""
from __future__ import annotations

import argparse
import ast
import datetime
import hashlib
import json
import math
import os
import re
import stat
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from typing import Iterator, Optional


# --------------------------------------------------------------------------- #
# Bounds. Exceeding a whole-scan bound is an infrastructure failure (exit 2);
# exceeding a per-file bound downgrades that one file to a visible warning.
# --------------------------------------------------------------------------- #
MAX_FILES = 20_000
MAX_TOTAL_BYTES = 2 * 1024 * 1024 * 1024
MAX_FILE_BYTES = 64 * 1024 * 1024          # above this a file is not read at all
MAX_SCAN_BYTES = 5 * 1024 * 1024           # above this only magic + size are used
MAX_LINE_BYTES = 65536                      # regex feed cap; longer lines fail closed
MAGIC_READ = 4096

SEV_BLOCK = "blocking"
SEV_WARN = "warning"

# Git subprocesses run with the config that could execute candidate-supplied
# programs disabled, and never apply smudge/clean filters (cat-file returns raw
# blobs). System config is ignored.
GIT_SAFE = [
    "-c", "core.fsmonitor=false",
    "-c", "core.hooksPath=/dev/null",
    "-c", "protocol.ext.allow=never",
    "-c", "core.symlinks=false",
]
GIT_ENV = {
    **os.environ,
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_TERMINAL_PROMPT": "0",
    "GIT_OPTIONAL_LOCKS": "0",
    "GIT_PAGER": "cat",
}


class ScreenError(Exception):
    """An infrastructure or input failure: the screen could not run reliably."""


# --------------------------------------------------------------------------- #
# Rule registry - the single source of truth for rule id -> (severity, title).
# --------------------------------------------------------------------------- #
RULES: dict[str, tuple[str, str]] = {
    # filesystem / payload integrity
    "payload.symlink": (SEV_BLOCK, "Symlink in payload (forbidden by policy)"),
    "payload.submodule": (SEV_BLOCK, "Git submodule / gitlink in payload"),
    "payload.special_file": (SEV_BLOCK, "Special file (device/fifo/socket) in payload"),
    "fs.path_escape": (SEV_BLOCK, "Path escapes the repository root"),
    "fs.control_char_name": (SEV_BLOCK, "Filename contains newline / control characters"),
    "file.too_large": (SEV_WARN, "File too large to fully screen"),
    # binary / opaque content
    "binary.executable": (SEV_BLOCK, "Compiled executable/object detected by magic bytes"),
    "binary.opaque": (SEV_WARN, "Opaque binary blob that cannot be statically screened"),
    # secrets / credentials (reports are redacted)
    "secret.private_key": (SEV_BLOCK, "Private key material"),
    "secret.aws_access_key": (SEV_BLOCK, "AWS access key id"),
    "secret.github_token": (SEV_BLOCK, "GitHub token"),
    "secret.slack_token": (SEV_BLOCK, "Slack token"),
    "secret.stripe_key": (SEV_BLOCK, "Stripe live secret key"),
    "secret.google_api_key": (SEV_BLOCK, "Google API key"),
    "secret.google_oauth_secret": (SEV_BLOCK, "Google OAuth client secret"),
    "secret.npm_token": (SEV_BLOCK, "npm access token"),
    "secret.pypi_token": (SEV_BLOCK, "PyPI API token"),
    "secret.jwt": (SEV_WARN, "JSON Web Token (may be a sample)"),
    "secret.discord_webhook": (SEV_WARN, "Discord/Slack webhook URL with token"),
    "secret.generic_credential": (SEV_WARN, "High-entropy credential-like assignment"),
    # manifest
    "manifest.source_escape": (SEV_BLOCK, "Manifest file source escapes the product root"),
    "manifest.destination_escape": (SEV_BLOCK, "Manifest destination escapes the install root"),
    "manifest.privileged_destination": (SEV_BLOCK, "Manifest installs into a privileged/host location"),
    "manifest.install_executable": (SEV_WARN, "Manifest installs a file with the executable bit"),
    "manifest.insecure_url": (SEV_WARN, "Manifest references an insecure http:// URL"),
    # plugin imports (R4)
    "plugin.forbidden_import": (SEV_BLOCK, "Plugin imports shell/UI internals"),
    "plugin.import_escape": (SEV_BLOCK, "Plugin relative import escapes the plugin folder"),
    "plugin.unknown_import": (SEV_WARN, "Plugin imports a module outside the allowlist"),
    # dynamic execution
    "exec.eval_exec": (SEV_BLOCK, "Python eval/exec/compile of code"),
    "exec.os_system": (SEV_BLOCK, "Python os.system/os.popen/exec* process spawn"),
    "exec.subprocess_shell": (SEV_BLOCK, "subprocess call with shell=True"),
    "exec.download_run": (SEV_BLOCK, "Download piped into a shell (download-and-execute)"),
    "exec.js_eval": (SEV_BLOCK, "JavaScript/QML eval or Function() constructor"),
    "exec.qml_dynamic": (SEV_WARN, "Dynamic QML object construction (Qt.createQmlObject)"),
    "exec.dynamic_import": (SEV_WARN, "Python dynamic import from a computed name"),
    "exec.deserialize": (SEV_WARN, "Unsafe deserialization (pickle/marshal/yaml.load)"),
    # shell
    "shell.privilege_escalation": (SEV_BLOCK, "sudo/doas/su privilege escalation"),
    "shell.pkexec": (SEV_WARN, "pkexec privileged action (must be declared)"),
    "shell.eval": (SEV_WARN, "Shell eval of a variable / command substitution"),
    "shell.interpolated_c": (SEV_WARN, "Shell -c string with interpolation (injection risk)"),
    # host / privileged configuration
    "config.sensitive_write": (SEV_BLOCK, "Write to a sensitive host configuration path"),
    "config.sensitive_reference": (SEV_WARN, "Reference to a sensitive host path"),
    # declarations
    "network.undeclared_host": (SEV_WARN, "Network host not declared in capabilities.network"),
    "command.undeclared": (SEV_WARN, "External command not shipped or declared"),
    # parsing limits (visible failure)
    "parse.python_error": (SEV_WARN, "Python source did not parse; AST checks skipped"),
    "parse.manifest_error": (SEV_WARN, "manifest.json did not parse; manifest checks skipped"),
    "parse.json_error": (SEV_WARN, "JSON document did not parse"),
    "scan.line_too_long": (SEV_BLOCK, "Line too long to fully screen (failed closed)"),
    # exception allowlist integrity (trusted policy)
    "exception.invalid": (SEV_BLOCK, "Malformed exception in the trusted allowlist"),
    "exception.expired": (SEV_BLOCK, "Expired exception in the trusted allowlist"),
    "exception.unused": (SEV_BLOCK, "Unused exception in the trusted allowlist"),
}


@dataclass(frozen=True)
class Finding:
    rule: str
    path: str
    line: int
    severity: str
    message: str
    fingerprint: str

    def as_dict(self) -> dict:
        return {
            "rule": self.rule,
            "path": self.path,
            "line": self.line,
            "severity": self.severity,
            "message": self.message,
            "fingerprint": self.fingerprint,
        }


@dataclass
class Blob:
    """A single tree entry with its content resolved for the chosen mode."""
    path: str                       # posix, relative to root
    kind: str                       # file | symlink | submodule | special
    mode: int                       # unix-style permission/type bits
    size: int
    data: Optional[bytes] = None    # None => not read (too large / non-file)
    sha256: Optional[str] = None


class Collector:
    """Accumulates findings and de-duplicates by fingerprint."""

    def __init__(self) -> None:
        self._by_fp: dict[str, Finding] = {}

    def add(self, rule: str, path: str, line: int, message: str, tag: str = "",
            severity: Optional[str] = None) -> None:
        if severity is None:
            severity = RULES.get(rule, (SEV_WARN, ""))[0]
        fp = hashlib.sha256(
            "\x00".join((rule, path, str(line), tag)).encode("utf-8", "surrogatepass")
        ).hexdigest()[:16]
        if fp not in self._by_fp:
            self._by_fp[fp] = Finding(rule, path, line, severity, message, fp)

    def findings(self) -> list[Finding]:
        return list(self._by_fp.values())


# --------------------------------------------------------------------------- #
# Small shared helpers
# --------------------------------------------------------------------------- #
def _reject_constant(value: str) -> None:
    raise ValueError(f"invalid numeric constant {value}")


def load_json_bytes(data: bytes) -> object:
    return json.loads(data.decode("utf-8"), parse_constant=_reject_constant)


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def safe_relative(value: object) -> bool:
    """Relative, forward-slash, no ``..``/``.``/empty parts, no NUL/backslash."""
    if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
        return False
    path = PurePosixPath(value)
    return (
        not path.is_absolute()
        and bool(path.parts)
        and path.as_posix() == value
        and all(part not in ("", ".", "..") for part in path.parts)
    )


def resolve_within(base_dir: str, rel: str) -> Optional[str]:
    """Resolve ``rel`` against posix ``base_dir``. Return the normalized posix
    path, or None if it is absolute or climbs above the tree root."""
    if rel.startswith("/"):
        return None
    parts = [p for p in base_dir.split("/") if p] if base_dir else []
    for part in rel.split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            if not parts:
                return None
            parts.pop()
        else:
            parts.append(part)
    return "/".join(parts)


def iter_lines(text: str) -> Iterator[tuple[int, str]]:
    for index, line in enumerate(text.split("\n"), start=1):
        if len(line) > MAX_LINE_BYTES:
            line = line[:MAX_LINE_BYTES]
        yield index, line


def find_line(text: str, needle: str) -> int:
    if not needle:
        return 0
    idx = text.find(needle)
    if idx < 0:
        return 0
    return text.count("\n", 0, idx) + 1


def shannon_entropy(value: str) -> float:
    if not value:
        return 0.0
    counts: dict[str, int] = {}
    for ch in value:
        counts[ch] = counts.get(ch, 0) + 1
    length = len(value)
    return -sum((c / length) * math.log2(c / length) for c in counts.values())


def strip_shell_comment(line: str) -> str:
    out: list[str] = []
    quote: Optional[str] = None
    i = 0
    while i < len(line):
        ch = line[i]
        if quote:
            out.append(ch)
            if ch == "\\" and quote == '"' and i + 1 < len(line):
                out.append(line[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in ("'", '"'):
            quote = ch
            out.append(ch)
        elif ch == "#" and (i == 0 or line[i - 1].isspace()):
            break
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def strip_js_comments(text: str) -> str:
    """Remove // and /* */ comments while preserving newlines/positions so that
    line numbers stay accurate. String and template literals are preserved."""
    out: list[str] = []
    i, n = 0, len(text)
    state: Optional[str] = None       # active string quote char
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if state is None:
            if ch in ("'", '"', "`"):
                state = ch
                out.append(ch)
            elif ch == "/" and nxt == "/":
                out.append("  ")
                i += 2
                while i < n and text[i] != "\n":
                    out.append(" ")
                    i += 1
                continue
            elif ch == "/" and nxt == "*":
                out.append("  ")
                i += 2
                while i < n and not (text[i] == "*" and i + 1 < n and text[i + 1] == "/"):
                    out.append("\n" if text[i] == "\n" else " ")
                    i += 1
                if i < n:
                    out.append("  ")
                    i += 2
                continue
            else:
                out.append(ch)
        else:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if ch == state:
                state = None
        i += 1
    return "".join(out)


# --------------------------------------------------------------------------- #
# Binary / magic detection (executables and objects only; media stays allowed)
# --------------------------------------------------------------------------- #
_MAGIC = [
    (b"\x7fELF", "ELF executable/object"),
    (b"\xca\xfe\xba\xbe", "Java class or Mach-O fat binary"),
    (b"\xbe\xba\xfe\xca", "Mach-O fat binary"),
    (b"\xfe\xed\xfa\xce", "Mach-O executable"),
    (b"\xce\xfa\xed\xfe", "Mach-O executable"),
    (b"\xfe\xed\xfa\xcf", "Mach-O executable"),
    (b"\xcf\xfa\xed\xfe", "Mach-O executable"),
    (b"\x00asm", "WebAssembly module"),
    (b"!<arch>\n", "ar static archive"),
]


def detect_executable(data: bytes) -> Optional[str]:
    for magic, label in _MAGIC:
        if data.startswith(magic):
            return label
    # CPython 3 bytecode carries a version magic followed by CRLF. Recognize
    # the version range, not only this interpreter's magic or the file suffix.
    if len(data) >= 8 and data[2:4] == b"\r\n" and 3000 <= int.from_bytes(data[:2], "little") < 4000:
        return "CPython bytecode"
    # DOS/PE: "MZ" then a PE header pointer that resolves to "PE\0\0".
    if data[:2] == b"MZ" and len(data) >= 0x40:
        offset = int.from_bytes(data[0x3C:0x40], "little")
        if 0 <= offset <= len(data) - 4 and data[offset:offset + 4] == b"PE\x00\x00":
            return "PE/COFF executable"
    return None


MEDIA_EXTS = {
    ".png", ".jpg", ".jpeg", ".webp", ".gif", ".avif", ".bmp", ".ico", ".tiff",
    ".mp4", ".webm", ".mkv", ".mov", ".mp3", ".ogg", ".wav", ".flac", ".opus",
    ".ttf", ".otf", ".woff", ".woff2", ".pdf",
}
DATA_EXTS = {
    ".gz", ".zst", ".xz", ".bz2", ".zip", ".tar", ".7z", ".br",
    ".db", ".sqlite", ".sqlite3", ".bin", ".dat",
}
DOC_EXTS = {".md", ".markdown", ".rst", ".txt", ".adoc"}
PY_EXTS = {".py", ".pyw"}
SHELL_EXTS = {".sh", ".bash", ".zsh", ".ksh"}
JS_QML_EXTS = {".qml", ".js", ".mjs", ".cjs", ".jsx", ".ts", ".tsx"}
GENERIC_SECRET_EXTS = {
    ".py", ".pyw", ".sh", ".bash", ".zsh", ".qml", ".js", ".mjs", ".cjs",
    ".jsx", ".ts", ".tsx", ".json", ".env", ".yaml", ".yml", ".toml", ".ini",
    ".cfg", ".conf", ".properties", ".xml", "",
}


def is_texty(data: bytes) -> bool:
    return b"\x00" not in data[:MAGIC_READ]


# --------------------------------------------------------------------------- #
# Secret patterns. High-confidence patterns run on every text file; the generic
# heuristic is gated by entropy and file type. Matched bytes are never emitted.
# --------------------------------------------------------------------------- #
_SECRET_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("secret.private_key",
     re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY-----")),
    ("secret.aws_access_key",
     re.compile(r"\b(?:AKIA|ASIA|AGPA|AIDA|AROA|ANPA|AIPA)[0-9A-Z]{16}\b")),
    ("secret.github_token",
     re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})\b")),
    ("secret.slack_token",
     re.compile(r"\bxox[baprs]-[0-9A-Za-z-]{10,}\b")),
    ("secret.stripe_key",
     re.compile(r"\b(?:sk|rk)_live_[0-9A-Za-z]{20,}\b")),
    ("secret.google_api_key",
     re.compile(r"\bAIza[0-9A-Za-z_\-]{35}\b")),
    ("secret.google_oauth_secret",
     re.compile(r"\bGOCSPX-[0-9A-Za-z_\-]{20,}\b")),
    ("secret.npm_token",
     re.compile(r"\bnpm_[0-9A-Za-z]{36}\b")),
    ("secret.pypi_token",
     re.compile(r"\bpypi-AgEIcHlwaS[0-9A-Za-z_\-]{40,}\b")),
    ("secret.jwt",
     re.compile(r"\beyJ[A-Za-z0-9_\-]{8,}\.eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\b")),
    ("secret.discord_webhook",
     re.compile(r"https://(?:discord(?:app)?|slack)\.com/api/webhooks/[\w/-]+")),
]

_GENERIC_SECRET = re.compile(
    r"""(?ix)
    \b(pass(?:word|wd)?|secret|token|api[_-]?key|access[_-]?key
       |client[_-]?secret|auth[_-]?token|private[_-]?key|bearer)\b
    \s*[:=]\s*
    ["']([^"'\n]{12,})["']
    """
)
_PLACEHOLDER_HINTS = (
    "example", "changeme", "your", "placeholder", "redacted", "dummy", "sample",
    "test", "fake", "xxxx", "todo", "none", "null", "<", ">", "{{", "${", "$(",
    "os.environ", "process.env", "getenv", "env[", "*****",
)
_HEX_COLOR = re.compile(r"^#?[0-9A-Fa-f]{3,8}$")


def scan_secrets(coll: Collector, path: str, ext: str, text: str) -> None:
    # Secret patterns are all linear (no nested quantifiers), so they scan the
    # FULL line regardless of length. This keeps overlong lines from hiding a
    # credential past the ReDoS cap that bounds the other, superlinear rules.
    for lineno, line in enumerate(text.split("\n"), start=1):
        for rule, pattern in _SECRET_PATTERNS:
            if pattern.search(line):
                label = RULES[rule][1]
                coll.add(rule, path, lineno, f"{label} (value redacted)", tag=rule)
        if ext in GENERIC_SECRET_EXTS and ext not in DOC_EXTS:
            for match in _GENERIC_SECRET.finditer(line):
                key, value = match.group(1), match.group(2)
                low = value.lower()
                if any(hint in low for hint in _PLACEHOLDER_HINTS):
                    continue
                if _HEX_COLOR.match(value) or len(set(value)) <= 3:
                    continue
                classes = sum(
                    bool(re.search(p, value))
                    for p in (r"[a-z]", r"[A-Z]", r"[0-9]", r"[^A-Za-z0-9]")
                )
                if len(value) >= 16 and classes >= 3 and shannon_entropy(value) >= 3.0:
                    coll.add(
                        "secret.generic_credential", path, lineno,
                        f"high-entropy value assigned to {key!r} (value redacted)",
                        tag="generic",
                    )


# --------------------------------------------------------------------------- #
# Download-and-execute and sensitive-path patterns (language-agnostic text).
# --------------------------------------------------------------------------- #
_DOWNLOAD_RUN = [
    re.compile(r"\b(?:curl|wget|fetch)\b[^\n|]*\|\s*(?:sudo\s+)?(?:ba|z|da|c)?sh\b"),
    re.compile(r"\b(?:ba|z|da)?sh\b[^\n]*-c[^\n]*\$\(\s*(?:curl|wget|fetch)\b"),
    re.compile(r"\beval\b[^\n]*\$\(\s*(?:curl|wget|fetch)\b"),
    re.compile(r"<\(\s*(?:curl|wget|fetch)\b"),
    re.compile(r"\bpython[0-9.]*\b[^\n]*-c[^\n]*urlopen\("),
]

_SENSITIVE = [
    (re.compile(r"(?<![\w.])~?/?\.ssh(?:/|\b)"), ".ssh directory"),
    (re.compile(r"/etc/(?:passwd|shadow|sudoers|hosts|crontab|environment|profile)"), "/etc system file"),
    (re.compile(r"(?<![\w.])\.(?:bashrc|bash_profile|profile|zshrc|zprofile|zshenv|zlogin)\b"), "shell rc file"),
    (re.compile(r"\.config/autostart"), "autostart entry"),
    (re.compile(r"(?:\.config|/etc)/systemd|/systemd/user"), "systemd unit"),
    (re.compile(r"(?<![\w.])crontab(?:\b|\s)"), "crontab"),
    (re.compile(r"\.config/quickshell"), "shipped shell config"),
    (re.compile(r"(?<![\w.])(?:shell\.json|plugins\.json)\b"), "shell/plugins config"),
    (re.compile(r"\.config/ryoku/plugins\.json"), "ryoku plugins config"),
    (re.compile(r"\.local/share/ryoku/plugins"), "install receipt root"),
    (re.compile(r"(?<![\w.])/etc/(?![\w])"), "/etc"),
]

_SENSITIVE_WRITE_SHELL = re.compile(
    r"""(?x)
    (?:
        >>?\s*|                         # redirection
        \btee\s+(?:-a\s+)?|             # tee
        \bln\s+-s\b[^\n]*|              # symlink into a target
        \bcp\s+[^\n]*|                  # copy into a target
        \bmv\s+[^\n]*                   # move into a target
    )
    ["']?(?P<target>[^\s"'>|;&]*(?:\.ssh|\.bashrc|\.zshrc|\.profile|/etc/|autostart|systemd|crontab|plugins\.json|shell\.json)[^\s"'>|;&]*)
    """
)
_CRON_ENABLE = re.compile(
    r"(?<![\w.])(?:crontab\s+-|systemctl(?:\s+--user)?\s+enable|update-rc\.d|"
    r"chkconfig\s+[^\n]*\bon\b|loginctl\s+enable-linger)"
)


def scan_universal_text(coll: Collector, path: str, ext: str, text: str, is_doc: bool) -> None:
    scan_secrets(coll, path, ext, text)
    for lineno, raw in iter_lines(text):
        if not is_doc:
            # download-and-execute and host-path rules are code concerns; a
            # README that only documents the forbidden install idiom is not a
            # payload, so these never fire on docs.
            for pattern in _DOWNLOAD_RUN:
                if pattern.search(raw):
                    coll.add("exec.download_run", path, lineno,
                             "downloaded content piped into an interpreter", tag="dlrun")
                    break
            for pattern, label in _SENSITIVE:
                if pattern.search(raw):
                    coll.add("config.sensitive_reference", path, lineno,
                             f"reference to a sensitive host path ({label})", tag=label)
                    break


# --------------------------------------------------------------------------- #
# Shell structural screening (bounded, comment-aware; no full bash grammar).
# --------------------------------------------------------------------------- #
_SUDO = re.compile(r"(?:^|[\s;&|(])(?:sudo|doas)\b|(?:^|[\s;&|(])su\s+(?:-|[A-Za-z]|$)")
_PKEXEC = re.compile(r"(?:^|[\s;&|(])pkexec\b")
_SHELL_EVAL = re.compile(r"(?:^|[\s;&|(])eval\b\s+[^\n]*(?:\$\w|\$\{|\$\(|`)")
_SHELL_C_INTERP = re.compile(
    r"(?:^|[\s;&|(])(?:ba|z|da)?sh\b\s+(?:-[a-z]*\s+)*-c\s+"
    r"(?:\"[^\"\n]*(?:\$|`)[^\"\n]*\"|\$[\w{])"
)
_SHELL_SEGMENT = re.compile(r"[|&;]{1,2}|\(|\)|\bthen\b|\bdo\b|\{")
_SHELL_BUILTINS = {
    "cd", "echo", "printf", "read", "test", "set", "unset", "export", "local",
    "return", "exit", "shift", "eval", "exec", "source", ".", ":", "true",
    "false", "[", "[[", "declare", "typeset", "let", "trap", "wait", "pushd",
    "popd", "dirs", "getopts", "break", "continue", "if", "then", "else",
    "elif", "fi", "for", "while", "do", "done", "case", "esac", "function",
    "select", "until", "time", "alias", "unalias", "hash", "type", "command",
    "builtin", "shopt", "umask", "jobs", "fg", "bg", "disown", "readonly", "in",
}
_COREUTILS = {
    "cat", "ls", "cp", "mv", "rm", "mkdir", "rmdir", "touch", "ln", "chmod",
    "chown", "head", "tail", "sort", "uniq", "wc", "cut", "paste", "tr", "sed",
    "awk", "gawk", "grep", "egrep", "fgrep", "rg", "find", "xargs", "tee",
    "dirname", "basename", "realpath", "readlink", "stat", "date", "sleep",
    "env", "printenv", "seq", "tac", "comm", "join", "split", "expr", "test",
    "sha256sum", "sha1sum", "md5sum", "b2sum", "base64", "od", "hexdump",
    "cmp", "diff", "tar", "gzip", "gunzip", "zcat", "bzip2", "xz", "zstd",
    "jq", "yq", "tput", "clear", "mktemp", "getopt", "nl", "fold", "column",
    "sponge", "which", "true", "false", "id", "whoami", "uname", "hostname",
}
# Interpreters that appear as the head of a pipeline segment because they run
# the script itself (or a piped-in payload caught by exec.download_run); they
# are not the "external program" R6 asks contributors to declare.
_INTERPRETERS = {"sh", "bash", "zsh", "dash", "ksh", "fish"}


_HEREDOC = re.compile(r"<<[-~]?\s*(['\"]?)([A-Za-z_]\w*)\1")


def _mask_heredocs(text: str) -> str:
    lines = text.split("\n")
    result = list(lines)
    i = 0
    while i < len(lines):
        match = _HEREDOC.search(lines[i])
        if match:
            delim = match.group(2)
            j = i + 1
            while j < len(lines) and lines[j].strip() != delim:
                result[j] = ""
                j += 1
            i = j
        i += 1
    return "\n".join(result)


def _mask_shell(text: str) -> str:
    """Return ``text`` with quoted spans, $( ) substitutions, `` backticks,
    here-doc bodies and comments blanked, newlines preserved so line numbers stay
    aligned. Quotes span newlines, so a multi-line jq/awk program is one masked
    span and its internal ``|`` separators never look like top-level pipeline
    boundaries. Nested command substitutions are blanked, not parsed - an
    explicit limit, not a claim of full shell parsing."""
    text = _mask_heredocs(text)
    out: list[str] = []
    i, n = 0, len(text)
    quote: Optional[str] = None
    depth = 0
    while i < n:
        ch = text[i]
        if ch == "\n":
            out.append("\n")
            i += 1
            continue
        if quote is not None:
            out.append(" ")
            if ch == "\\" and quote == '"' and i + 1 < n and text[i + 1] != "\n":
                out.append(" ")
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if depth > 0:
            out.append(" ")
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            i += 1
            continue
        if ch == "#" and (i == 0 or text[i - 1] in " \t\n;|&()"):
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if ch == "$" and i + 1 < n and text[i + 1] == "(":
            out.append("  ")
            depth = 1
            i += 2
            continue
        if ch in ("'", '"', "`"):
            quote = ch
            out.append(" ")
            i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


_SEG_SPLIT = re.compile(r"[|;&()<>{}]+|\s&&\s|\s\|\|\s")
_CMD_WRAPPERS = frozenset({
    "sudo", "doas", "command", "builtin", "nohup", "exec", "time", "env",
    "then", "do", "else", "elif", "!", "xargs", "nice", "ionice", "stdbuf",
})


def _shell_command_heads(masked_line: str, defined: frozenset[str]) -> list[str]:
    heads: list[str] = []
    for segment in _SEG_SPLIT.split(masked_line):
        tokens = segment.split()
        i = 0
        while i < len(tokens):
            tok = tokens[i]
            if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", tok):
                i += 1
                continue
            if tok in _CMD_WRAPPERS:
                i += 1
                continue
            break
        if i >= len(tokens):
            continue
        head = tokens[i]
        name = PurePosixPath(head).name
        if not re.fullmatch(r"[A-Za-z_./][\w.+-]*", head):
            continue
        if name in defined or head in defined:
            continue
        heads.append(head)
    return heads


_FUNC_DEF = re.compile(r"(?m)^\s*(?:function\s+)?([A-Za-z_][\w-]*)\s*\(\s*\)")
_FUNC_KW = re.compile(r"(?m)^\s*function\s+([A-Za-z_][\w-]*)")
_CASE_OPEN = re.compile(r"(?<![\w])case\b.*\bin\b")
_CASE_CLOSE = re.compile(r"(?<![\w])esac\b")
_CASE_LABEL = re.compile(r"^\s*\(?\s*[^\s()|&;]+(?:\s*\|\s*[^\s()|&;]+)*\s*\)")


def scan_shell(coll: Collector, path: str, text: str,
               declared_cmds: Optional[set[str]]) -> None:
    defined = frozenset(_FUNC_DEF.findall(text)) | frozenset(_FUNC_KW.findall(text))
    masked_lines = _mask_shell(text).split("\n")
    in_case = 0
    for lineno, raw in iter_lines(text):
        line = strip_shell_comment(raw)
        if not line.strip():
            continue
        if _SUDO.search(line):
            coll.add("shell.privilege_escalation", path, lineno,
                     "sudo/doas/su privilege escalation", tag="sudo")
        if _PKEXEC.search(line):
            coll.add("shell.pkexec", path, lineno,
                     "pkexec privileged action; must be declared and click-gated", tag="pkexec")
        if _SHELL_EVAL.search(line):
            coll.add("shell.eval", path, lineno,
                     "shell eval of a variable or command substitution", tag="eval")
        if _SHELL_C_INTERP.search(line):
            coll.add("shell.interpolated_c", path, lineno,
                     "sh -c string built with interpolation (use an argv array)", tag="c")
        wmatch = _SENSITIVE_WRITE_SHELL.search(line)
        if wmatch:
            coll.add("config.sensitive_write", path, lineno,
                     f"write into a sensitive host path ({wmatch.group('target')})", tag="write")
        elif _CRON_ENABLE.search(line):
            coll.add("config.sensitive_write", path, lineno,
                     "installs a persistent service / cron / autostart entry", tag="persist")
        if declared_cmds is not None:
            masked = masked_lines[lineno - 1] if lineno - 1 < len(masked_lines) else ""
            if _CASE_OPEN.search(masked):
                in_case += 1
            if _CASE_CLOSE.search(masked):
                in_case = max(0, in_case - 1)
            if in_case:
                # inside a case, strip a leading `pattern)` label so its words are
                # not read as commands; commands after the `)` still parse.
                label = _CASE_LABEL.match(masked)
                if label:
                    masked = " " * label.end() + masked[label.end():]
            for head in _shell_command_heads(masked[:MAX_LINE_BYTES], defined):
                name = PurePosixPath(head).name
                if not name or name in (".", ".."):
                    continue
                if name in _SHELL_BUILTINS or name in _COREUTILS or name in _INTERPRETERS:
                    continue
                if name in declared_cmds or head in declared_cmds:
                    continue
                coll.add("command.undeclared", path, lineno,
                         f"command {name!r} is not shipped in bin/ or declared in "
                         f"dependencies.commands", tag=name)


# --------------------------------------------------------------------------- #
# Python AST screening (ast.parse does not execute the module).
# --------------------------------------------------------------------------- #
_PY_WRITE_MODES = re.compile(r"[wax]")


def _attr_chain(node: ast.AST) -> str:
    parts: list[str] = []
    while isinstance(node, ast.Attribute):
        parts.append(node.attr)
        node = node.value
    if isinstance(node, ast.Name):
        parts.append(node.id)
    return ".".join(reversed(parts))


def _const_str(node: ast.AST) -> Optional[str]:
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    return None


def _sensitive_label(value: str) -> Optional[str]:
    for pattern, label in _SENSITIVE:
        if pattern.search(value):
            return label
    return None


def scan_python(coll: Collector, path: str, text: str,
                declared_cmds: Optional[set[str]]) -> bool:
    try:
        tree = ast.parse(text)
    except (SyntaxError, ValueError):
        coll.add("parse.python_error", path, 0,
                 "Python source did not parse; AST-based checks were skipped", tag="parse")
        return False

    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        line = getattr(node, "lineno", 0)
        func = node.func
        name = func.id if isinstance(func, ast.Name) else None
        dotted = _attr_chain(func) if isinstance(func, ast.Attribute) else (name or "")

        if name in ("eval", "exec", "compile"):
            coll.add("exec.eval_exec", path, line,
                     f"dynamic code execution via {name}()", tag=name)
        elif name == "__import__":
            if node.args and _const_str(node.args[0]) is None:
                coll.add("exec.dynamic_import", path, line,
                         "__import__ with a computed module name", tag="import")

        if dotted in ("os.system", "os.popen", "commands.getoutput",
                      "commands.getstatusoutput", "pty.spawn"):
            coll.add("exec.os_system", path, line,
                     f"process spawn via {dotted}()", tag=dotted)
        elif re.fullmatch(r"os\.(?:exec|spawn)[a-z]*", dotted):
            coll.add("exec.os_system", path, line,
                     f"process spawn via {dotted}()", tag=dotted)

        base = dotted.split(".")[-1]
        if base in ("run", "call", "check_call", "check_output", "Popen") and (
            dotted.startswith("subprocess.") or dotted == base
        ):
            for kw in node.keywords:
                if kw.arg == "shell" and isinstance(kw.value, ast.Constant) and kw.value.value is True:
                    coll.add("exec.subprocess_shell", path, line,
                             "subprocess call with shell=True (shell injection surface)",
                             tag="shell")
            if declared_cmds is not None and node.args:
                prog = _subprocess_program(node.args[0])
                if prog:
                    pname = PurePosixPath(prog).name
                    if (pname not in _COREUTILS and pname not in _INTERPRETERS
                            and pname not in declared_cmds
                            and prog not in declared_cmds
                            and re.fullmatch(r"[\w.+-]+", pname)):
                        coll.add("command.undeclared", path, line,
                                 f"command {pname!r} is not shipped in bin/ or declared",
                                 tag=pname)

        if dotted in ("pickle.load", "pickle.loads", "marshal.load", "marshal.loads",
                      "cPickle.load", "cPickle.loads"):
            coll.add("exec.deserialize", path, line,
                     f"unsafe deserialization via {dotted}()", tag=dotted)
        elif dotted in ("yaml.load",):
            safe = any(
                kw.arg in ("Loader",) and "Safe" in ast.dump(kw.value)
                for kw in node.keywords
            )
            if not safe:
                coll.add("exec.deserialize", path, line,
                         "yaml.load without SafeLoader", tag="yaml")

        # writes into sensitive host paths
        if name == "open" and len(node.args) >= 2:
            target = _const_str(node.args[0])
            mode = _const_str(node.args[1])
            if target and mode and _PY_WRITE_MODES.search(mode):
                label = _sensitive_label(target)
                if label:
                    coll.add("config.sensitive_write", path, line,
                             f"open() writes to a sensitive host path ({label})", tag=label)
        if base in ("write_text", "write_bytes") and node.args:
            # Path(...).write_text / .write_bytes on a literal sensitive target
            recv = func.value if isinstance(func, ast.Attribute) else None
            lit = _receiver_literal(recv)
            if lit:
                label = _sensitive_label(lit)
                if label:
                    coll.add("config.sensitive_write", path, line,
                             f"{base} to a sensitive host path ({label})", tag=label)
    return True


def _subprocess_program(node: ast.AST) -> Optional[str]:
    if isinstance(node, (ast.List, ast.Tuple)) and node.elts:
        return _const_str(node.elts[0])
    return _const_str(node)


def _receiver_literal(node: Optional[ast.AST]) -> Optional[str]:
    """Best-effort literal for Path("x")/os.path.join("a","b") receivers."""
    if node is None:
        return None
    lit = _const_str(node)
    if lit is not None:
        return lit
    if isinstance(node, ast.Call):
        if node.args:
            first = _const_str(node.args[0])
            if first:
                return first
    return None


# --------------------------------------------------------------------------- #
# QML / JavaScript screening (regex on comment-stripped text; imports honour
# the plugin folder for R4).
# --------------------------------------------------------------------------- #
_IMPORT = re.compile(r"""^\s*import\s+(?:"(?P<path>[^"]+)"|(?P<mod>[\w.]+))""")
_JS_EVAL = re.compile(r"(?<![\w.])eval\s*\(|(?<![\w.])(?:new\s+)?Function\s*\(")
_QML_DYNAMIC = re.compile(r"\bQt\.createQmlObject\s*\(")
_ALLOWED_IMPORT_PREFIXES = (
    "QtQuick", "QtQml", "QtCore", "QtGraphicalEffects", "QtMultimedia",
    "Qt.", "Qt5Compat", "Quickshell", "Ryoku.PluginKit",
)
# Skip any user:pass@ userinfo so a token embedded in a URL is never captured or
# echoed as the host; capture only the real host after an optional userinfo.
_URL_HOST = re.compile(
    r"(?:https?|wss?|ftp)://(?:[^/\s\"'@]*@)?(?P<host>[A-Za-z0-9._-]+)"
)
_BENIGN_HOSTS = {
    "localhost", "127.0.0.1", "0.0.0.0", "::1", "example.com", "example.org",
    "example.net", "www.example.com", "json-schema.org", "www.w3.org",
    "w3.org", "purl.org", "spdx.org", "creativecommons.org", "opensource.org",
    "schemas.microsoft.com", "ns.adobe.com", "www.gnu.org",
}


def scan_js_qml(coll: Collector, path: str, text: str, plugin_root: Optional[str]) -> None:
    stripped = strip_js_comments(text)
    file_dir = str(PurePosixPath(path).parent)
    for lineno, line in iter_lines(stripped):
        imp = _IMPORT.match(line)
        if imp:
            _screen_import(coll, path, lineno, imp, file_dir, plugin_root)
        if _JS_EVAL.search(line):
            coll.add("exec.js_eval", path, lineno,
                     "JavaScript eval / Function() constructor", tag="jseval")
        if _QML_DYNAMIC.search(line):
            coll.add("exec.qml_dynamic", path, lineno,
                     "dynamic QML construction via Qt.createQmlObject", tag="createqml")


def _screen_import(coll: Collector, path: str, lineno: int, imp: re.Match,
                   file_dir: str, plugin_root: Optional[str]) -> None:
    rel = imp.group("path")
    mod = imp.group("mod")
    if mod:
        if plugin_root is None:
            return
        first = mod.split(".")[0]
        if first == "shell":
            coll.add("plugin.forbidden_import", path, lineno,
                     f"forbidden import of shell internals ({mod})", tag=mod)
        elif mod.startswith("Ryoku.") and not mod.startswith("Ryoku.PluginKit"):
            coll.add("plugin.forbidden_import", path, lineno,
                     f"forbidden import of Ryoku UI internals ({mod})", tag=mod)
        elif not any(mod == p or mod.startswith(p) for p in _ALLOWED_IMPORT_PREFIXES):
            coll.add("plugin.unknown_import", path, lineno,
                     f"import outside the plugin allowlist ({mod})", tag=mod)
    elif rel is not None:
        if plugin_root is None:
            return
        target = resolve_within(file_dir, rel)
        if target is None:
            coll.add("plugin.import_escape", path, lineno,
                     f"relative import escapes the repository ({rel})", tag=rel)
            return
        root_prefix = plugin_root + "/" if plugin_root else ""
        if plugin_root and target != plugin_root and not target.startswith(root_prefix):
            coll.add("plugin.import_escape", path, lineno,
                     f"relative import escapes the plugin folder ({rel})", tag=rel)


def scan_network_hosts(coll: Collector, path: str, text: str,
                       declared_hosts: set[str]) -> None:
    seen: set[str] = set()
    for lineno, line in iter_lines(text):
        for match in _URL_HOST.finditer(line):
            host = match.group("host").lower().rstrip(".")
            if host in _BENIGN_HOSTS or host in seen:
                continue
            if host.replace(".", "").isdigit() and host in _BENIGN_HOSTS:
                continue
            if any(host == d or host.endswith("." + d) for d in declared_hosts):
                continue
            seen.add(host)
            coll.add("network.undeclared_host", path, lineno,
                     f"contacts {host}, not declared in capabilities.network", tag=host)


# --------------------------------------------------------------------------- #
# Manifest screening
# --------------------------------------------------------------------------- #
_PRIV_DEST = [
    (re.compile(r"(?<![\w.])\.ssh(?:/|$)"), ".ssh"),
    (re.compile(r"(?<![\w.])\.(?:bashrc|bash_profile|profile|zshrc|zprofile|zshenv)\b"), "shell rc"),
    (re.compile(r"\.config/autostart"), "autostart"),
    (re.compile(r"(?:\.config|/etc)/systemd|systemd/user"), "systemd"),
    (re.compile(r"\.config/quickshell"), "shipped shell"),
    (re.compile(r"(?:^|/)(?:shell\.json|plugins\.json)$"), "shell config"),
    (re.compile(r"\.local/share/ryoku/plugins"), "install receipt root"),
    (re.compile(r"(?:^|/)\.local/bin(?:/|$)"), "PATH bin dir"),
]
_INSECURE_URL = re.compile(r"http://[^\s\"']+")


def _dest_privileged(value: str) -> Optional[str]:
    for pattern, label in _PRIV_DEST:
        if pattern.search(value):
            return label
    return None


def scan_manifest(coll: Collector, path: str, raw: str) -> Optional[dict]:
    try:
        manifest = load_json_bytes(raw.encode("utf-8"))
    except ValueError:
        coll.add("parse.manifest_error", path, 0,
                 "manifest did not parse; manifest checks skipped", tag="parse")
        return None
    if not isinstance(manifest, dict):
        coll.add("parse.manifest_error", path, 0, "manifest is not an object", tag="parse")
        return None

    top_dest = manifest.get("destination")
    if isinstance(top_dest, str):
        if not safe_relative(top_dest) or ".." in PurePosixPath(top_dest).parts:
            coll.add("manifest.destination_escape", path, find_line(raw, top_dest),
                     f"install destination is not a safe relative path: {top_dest}", tag="topdest")
        else:
            label = _dest_privileged(top_dest)
            if label:
                coll.add("manifest.privileged_destination", path, find_line(raw, top_dest),
                         f"install destination targets a privileged location ({label})", tag=label)

    files = manifest.get("files")
    if isinstance(files, list):
        for row in files:
            if not isinstance(row, dict):
                continue
            source = row.get("source")
            dest = row.get("destination")
            mode = row.get("mode")
            if isinstance(source, str) and not safe_relative(source):
                coll.add("manifest.source_escape", path, find_line(raw, source),
                         f"file source escapes the product root: {source}", tag="src")
            if isinstance(dest, str):
                if not safe_relative(dest):
                    coll.add("manifest.destination_escape", path, find_line(raw, dest),
                             f"file destination is not a safe relative path: {dest}", tag="dst")
                else:
                    label = _dest_privileged(dest)
                    if label:
                        coll.add("manifest.privileged_destination", path, find_line(raw, dest),
                                 f"file installs into a privileged location ({label})", tag=label)
            if mode == "0755" and not (
                isinstance(source, str)
                and (source.startswith("bin/") or "/bin/" in source)
            ):
                # bin/ scripts are expected to be 0755 (R2); flag exec installs
                # that land anywhere else, where the executable bit is surprising.
                coll.add("manifest.install_executable", path, find_line(raw, str(source)),
                         f"file installs with the executable bit outside bin/: {source}",
                         tag="mode")

    for match in _INSECURE_URL.finditer(raw):
        coll.add("manifest.insecure_url", path, find_line(raw, match.group(0)),
                 "manifest references an insecure http:// URL", tag="http")

    return manifest


def manifest_declared(manifest: dict) -> tuple[set[str], set[str]]:
    """Return (declared network hosts, declared command names) from a manifest."""
    hosts: set[str] = set()
    caps = manifest.get("capabilities")
    if isinstance(caps, dict):
        for entry in caps.get("network", []) or []:
            if isinstance(entry, str) and entry:
                host = re.sub(r"^[a-z]+://", "", entry.strip(), flags=re.I)
                host = host.split("/")[0].split(":")[0].lower().rstrip(".")
                if host:
                    hosts.add(host)
    cmds: set[str] = set()
    for entry in manifest.get("commands", []) or []:
        if isinstance(entry, str):
            cmds.add(entry)
            cmds.add(PurePosixPath(entry).name)
    deps = manifest.get("dependencies")
    if isinstance(deps, dict):
        for entry in deps.get("commands", []) or []:
            if isinstance(entry, str):
                cmds.add(entry)
                cmds.add(PurePosixPath(entry).name)
    return hosts, cmds


# --------------------------------------------------------------------------- #
# Git plumbing
# --------------------------------------------------------------------------- #
def _git_bytes(root: Path, *args: str) -> bytes:
    try:
        proc = subprocess.run(
            ["git", *GIT_SAFE, "-C", str(root), *args],
            capture_output=True, env=GIT_ENV, check=False,
        )
    except FileNotFoundError as exc:
        raise ScreenError("git executable not found") from exc
    if proc.returncode != 0:
        detail = proc.stderr.decode("utf-8", "replace").strip().splitlines()
        head = detail[0] if detail else f"exit {proc.returncode}"
        raise ScreenError(f"git {args[0]} failed: {head}")
    return proc.stdout


def _is_git_worktree(root: Path) -> bool:
    try:
        out = _git_bytes(root, "rev-parse", "--is-inside-work-tree")
    except ScreenError:
        return False
    return out.strip() == b"true"


class GitBatch:
    """Reads raw blob content through a single ``git cat-file --batch`` pipe."""

    def __init__(self, root: Path) -> None:
        self._proc = subprocess.Popen(
            ["git", *GIT_SAFE, "-C", str(root), "cat-file", "--batch"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, env=GIT_ENV,
        )

    def read(self, oid: str) -> Optional[bytes]:
        assert self._proc.stdin and self._proc.stdout
        self._proc.stdin.write((oid + "\n").encode("ascii"))
        self._proc.stdin.flush()
        header = self._proc.stdout.readline()
        if not header:
            raise ScreenError("git cat-file stream closed unexpectedly")
        parts = header.split()
        if len(parts) == 2 and parts[1] in (b"missing", b"ambiguous"):
            raise ScreenError(f"git object {oid} is {parts[1].decode()}")
        if len(parts) != 3:
            raise ScreenError("git cat-file returned a malformed header")
        size = int(parts[2])
        if size > MAX_FILE_BYTES:
            self._discard(size + 1)
            return None
        data = self._read_exact(size)
        self._read_exact(1)  # trailing newline
        return data

    def _read_exact(self, count: int) -> bytes:
        assert self._proc.stdout
        chunks: list[bytes] = []
        remaining = count
        while remaining > 0:
            chunk = self._proc.stdout.read(remaining)
            if not chunk:
                raise ScreenError("git cat-file stream truncated")
            chunks.append(chunk)
            remaining -= len(chunk)
        return b"".join(chunks)

    def _discard(self, count: int) -> None:
        assert self._proc.stdout
        remaining = count
        while remaining > 0:
            chunk = self._proc.stdout.read(min(remaining, 1 << 20))
            if not chunk:
                raise ScreenError("git cat-file stream truncated")
            remaining -= len(chunk)

    def close(self) -> None:
        try:
            if self._proc.stdin:
                self._proc.stdin.close()
            self._proc.wait(timeout=10)
        except Exception:
            self._proc.kill()


# --------------------------------------------------------------------------- #
# Enumeration for each mode. Symlinks, submodules and special files are surfaced
# as blobs with a non-``file`` kind so the scanner can report them.
# --------------------------------------------------------------------------- #
def _check_name(coll: Collector, rel: str) -> bool:
    """Return True if the name is safe to use, else record a finding."""
    if "\x00" in rel or "\n" in rel or any(ord(c) < 32 for c in rel):
        coll.add("fs.control_char_name", _sanitize_name(rel), 0,
                 "filename contains newline / control characters", tag="ctl")
        return False
    parts = PurePosixPath(rel).parts
    if rel.startswith("/") or ".." in parts:
        coll.add("fs.path_escape", rel, 0, "path escapes the repository root", tag="esc")
        return False
    return True


def _sanitize_name(rel: str) -> str:
    return rel.encode("unicode_escape").decode("ascii")


class Budget:
    def __init__(self) -> None:
        self.files = 0
        self.total = 0

    def charge(self, size: int) -> None:
        self.files += 1
        self.total += max(size, 0)
        if self.files > MAX_FILES:
            raise ScreenError(f"too many files to screen (> {MAX_FILES})")
        if self.total > MAX_TOTAL_BYTES:
            raise ScreenError(f"total input exceeds {MAX_TOTAL_BYTES} bytes")


def enum_worktree(root: Path, coll: Collector, budget: Budget) -> Iterator[Blob]:
    if _is_git_worktree(root):
        out = _git_bytes(root, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
        names = [chunk for chunk in out.split(b"\x00") if chunk]
        rels = sorted(name.decode("utf-8", "surrogateescape") for name in names)
        for rel in rels:
            blob = _fs_blob(root, rel, coll, budget)
            if blob is not None:
                yield blob
    else:
        yield from _walk_fs(root, coll, budget)


# In non-git (exported payload) mode there is no .gitignore to honour, so the
# whole tree is product source. No directory is skipped by name: build caches,
# node_modules, hidden dirs, and even a dir named `.git`/`CVS`/`.svn` are
# scanned, because a payload can hide an executable under any such basename and
# a nested VCS-looking folder is not verified metadata. Directory symlinks are
# surfaced without traversal; whole-scan budgets bound a runaway tree.
def _walk_fs(root: Path, coll: Collector, budget: Budget) -> Iterator[Blob]:
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        base = Path(dirpath)
        descend: list[str] = []
        dir_symlinks: list[str] = []
        for name in sorted(dirnames):
            if (base / name).is_symlink():
                dir_symlinks.append(name)          # surface, never traverse
            else:
                descend.append(name)
        dirnames[:] = descend
        # a directory symlink is a payload symlink: report it, never follow it
        for name in dir_symlinks:
            rel = (base / name).relative_to(root).as_posix()
            blob = _fs_blob(root, rel, coll, budget)
            if blob is not None:
                yield blob
        for name in sorted(filenames):
            rel = (base / name).relative_to(root).as_posix()
            blob = _fs_blob(root, rel, coll, budget)
            if blob is not None:
                yield blob


def _fs_blob(root: Path, rel: str, coll: Collector, budget: Budget) -> Optional[Blob]:
    if not _check_name(coll, rel):
        return None
    full = root.joinpath(*PurePosixPath(rel).parts)
    try:
        st = full.lstat()
    except OSError:
        return None
    mode = st.st_mode
    if stat.S_ISLNK(mode):
        budget.charge(0)
        return Blob(rel, "symlink", mode, 0)
    if stat.S_ISDIR(mode):
        return None
    if not stat.S_ISREG(mode):
        budget.charge(0)
        return Blob(rel, "special", mode, 0)
    size = st.st_size
    budget.charge(size)
    data: Optional[bytes] = None
    if size <= MAX_FILE_BYTES:
        try:
            with open(full, "rb") as handle:
                data = handle.read(MAX_FILE_BYTES + 1)[:size]
        except OSError as exc:
            raise ScreenError(f"cannot read {rel}: {exc}") from exc
    return Blob(rel, "file", mode, size, data,
                sha256_hex(data) if data is not None else None)


def enum_index(root: Path, coll: Collector, budget: Budget) -> Iterator[Blob]:
    if not _is_git_worktree(root):
        raise ScreenError("--staged requires a Git work tree")
    out = _git_bytes(root, "ls-files", "-s", "-z")
    entries: dict[str, tuple[int, str]] = {}
    for record in out.split(b"\x00"):
        if not record:
            continue
        meta, _, path_bytes = record.partition(b"\t")
        fields = meta.split(b" ")
        if len(fields) < 3:
            continue
        mode = int(fields[0], 8)
        oid = fields[1].decode("ascii")
        stage = fields[2]
        rel = path_bytes.decode("utf-8", "surrogateescape")
        if stage != b"0" and rel in entries:
            continue
        entries[rel] = (mode, oid)
    yield from _git_blobs(root, entries, coll, budget)


def enum_revision(root: Path, ref: str, coll: Collector, budget: Budget) -> Iterator[Blob]:
    if not _is_git_worktree(root):
        raise ScreenError("--revision requires a Git repository")
    out = _git_bytes(root, "ls-tree", "-r", "-z", "--full-tree", ref)
    entries: dict[str, tuple[int, str]] = {}
    for record in out.split(b"\x00"):
        if not record:
            continue
        meta, _, path_bytes = record.partition(b"\t")
        fields = meta.split(b" ")
        if len(fields) != 3:
            continue
        mode = int(fields[0], 8)
        oid = fields[2].decode("ascii")
        rel = path_bytes.decode("utf-8", "surrogateescape")
        entries[rel] = (mode, oid)
    yield from _git_blobs(root, entries, coll, budget)


def _git_blobs(root: Path, entries: dict[str, tuple[int, str]],
               coll: Collector, budget: Budget) -> Iterator[Blob]:
    batch = GitBatch(root)
    try:
        for rel in sorted(entries):
            mode, oid = entries[rel]
            if not _check_name(coll, rel):
                continue
            if mode == 0o120000:
                budget.charge(0)
                yield Blob(rel, "symlink", mode, 0)
                continue
            if mode == 0o160000:
                budget.charge(0)
                yield Blob(rel, "submodule", mode, 0)
                continue
            data = batch.read(oid)
            size = len(data) if data is not None else MAX_FILE_BYTES + 1
            budget.charge(size)
            yield Blob(rel, "file", mode, size, data,
                       sha256_hex(data) if data is not None else None)
    finally:
        batch.close()


# --------------------------------------------------------------------------- #
# Exception allowlist (trusted policy only)
# --------------------------------------------------------------------------- #
@dataclass
class Exception_:
    rule: str
    path: str
    sha256: str
    reason: str
    expires: datetime.date
    used: bool = False


_GLOB_CHARS = set("*?[]!")


def load_exceptions(policy_root: Path, coll: Collector,
                    today: datetime.date) -> list[Exception_]:
    exc_path = policy_root / "security" / "exceptions.json"
    if not exc_path.exists():
        return []
    try:
        raw = exc_path.read_bytes()
    except OSError as exc:
        raise ScreenError(f"cannot read exceptions.json: {exc}") from exc
    try:
        doc = load_json_bytes(raw)
    except ValueError as exc:
        raise ScreenError(f"exceptions.json is not valid JSON: {exc}") from exc
    if not isinstance(doc, dict) or doc.get("schema") != 1 or not isinstance(
        doc.get("exceptions"), list
    ):
        raise ScreenError("exceptions.json must be {schema:1, exceptions:[...]}")

    result: list[Exception_] = []
    for index, entry in enumerate(doc["exceptions"]):
        loc = f"security/exceptions.json#{index}"
        parsed = _parse_exception(entry, loc, coll)
        if parsed is None:
            continue
        if parsed.expires < today:
            coll.add("exception.expired", loc, 0,
                     f"exception for {parsed.rule} on {parsed.path} expired "
                     f"{parsed.expires.isoformat()}", tag=parsed.sha256)
            continue
        result.append(parsed)
    return result


def _parse_exception(entry: object, loc: str, coll: Collector) -> Optional[Exception_]:
    if not isinstance(entry, dict):
        coll.add("exception.invalid", loc, 0, "exception must be an object", tag="type")
        return None
    allowed = {"rule", "path", "sha256", "reason", "expires"}
    extra = sorted(set(entry) - allowed)
    if extra:
        coll.add("exception.invalid", loc, 0,
                 f"exception has unknown field(s): {', '.join(extra)}", tag="extra")
        return None
    rule = entry.get("rule")
    path = entry.get("path")
    digest = entry.get("sha256")
    reason = entry.get("reason")
    expires = entry.get("expires")

    problems: list[str] = []
    if rule not in RULES:
        problems.append("unknown or missing rule id")
    if not isinstance(path, str) or not safe_relative(path):
        problems.append("path must be an exact safe relative path")
    elif _GLOB_CHARS & set(path):
        problems.append("path must not contain glob metacharacters")
    if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
        problems.append("sha256 must be a lowercase 64-hex full-file digest")
    if not isinstance(reason, str) or not reason.strip():
        problems.append("reason must be a non-empty string")
    parsed_date: Optional[datetime.date] = None
    if not isinstance(expires, str):
        problems.append("expires must be a YYYY-MM-DD string")
    else:
        try:
            parsed_date = datetime.date.fromisoformat(expires)
        except ValueError:
            problems.append("expires must be a valid YYYY-MM-DD date")

    if problems:
        coll.add("exception.invalid", loc, 0,
                 "; ".join(problems), tag="fields")
        return None
    return Exception_(rule, path, digest, reason, parsed_date)


def apply_exceptions(findings: list[Finding], exceptions: list[Exception_],
                     sha_by_path: dict[str, Optional[str]],
                     coll: Collector) -> list[Finding]:
    kept: list[Finding] = []
    for finding in findings:
        suppressed = False
        for exc in exceptions:
            if exc.rule == finding.rule and exc.path == finding.path:
                if sha_by_path.get(finding.path) == exc.sha256:
                    exc.used = True
                    suppressed = True
                    break
        if not suppressed:
            kept.append(finding)
    for exc in exceptions:
        if not exc.used:
            coll.add("exception.unused", f"security/exceptions.json", 0,
                     f"exception for {exc.rule} on {exc.path} matched nothing "
                     f"(stale sha256 or already-clean file)", tag=exc.sha256)
    return kept


# --------------------------------------------------------------------------- #
# Plugin-root discovery + the per-file dispatch
# --------------------------------------------------------------------------- #
def discover_plugin_roots(blobs: list[Blob]) -> dict[str, dict]:
    """Map plugin-root posix dir -> the manifest that owns its declared
    capabilities, for R4/network/command scoping. A dir is a plugin root when a
    manifest there has category 'plugins' or it matches the top-level
    ``plugins/<id>`` convention.

    The runtime ``manifest.json`` is authoritative for capabilities.network and
    dependencies.commands; ``product-manifest.json`` (the pack-tool integrity
    file) only locates the root and never overwrites those declarations."""
    runtime: dict[str, dict] = {}    # manifest.json per folder
    product: dict[str, dict] = {}    # product-manifest.json per folder
    for blob in blobs:
        if blob.kind != "file" or blob.data is None:
            continue
        name = PurePosixPath(blob.path).name
        if name not in ("manifest.json", "product-manifest.json"):
            continue
        try:
            doc = load_json_bytes(blob.data)
        except ValueError:
            continue
        if not isinstance(doc, dict):
            continue
        folder = str(PurePosixPath(blob.path).parent)
        folder = "" if folder == "." else folder
        if name == "manifest.json":
            runtime[folder] = doc
        else:
            product.setdefault(folder, doc)

    roots: dict[str, dict] = {}
    for folder in set(runtime) | set(product):
        # runtime manifest.json wins for capability lookups; product manifest is
        # only a fallback locator when no runtime manifest is present.
        owner = runtime.get(folder)
        locator = owner if owner is not None else product[folder]
        parts = folder.split("/") if folder else []
        is_plugin = (
            locator.get("category") == "plugins"
            or (len(parts) >= 2 and parts[-2] == "plugins")
        )
        if is_plugin:
            roots[folder] = owner if owner is not None else locator
    return roots


def plugin_root_for(path: str, roots: dict[str, dict]) -> Optional[str]:
    best: Optional[str] = None
    for root in roots:
        if root == "" or path == root or path.startswith(root + "/"):
            if best is None or len(root) > len(best):
                best = root
    return best


def scan_blob(coll: Collector, blob: Blob, roots: dict[str, dict]) -> None:
    path = blob.path
    if blob.kind == "symlink":
        coll.add("payload.symlink", path, 0, "symlink is forbidden in a submission", tag="lnk")
        return
    if blob.kind == "submodule":
        coll.add("payload.submodule", path, 0, "git submodule is forbidden in a submission", tag="sub")
        return
    if blob.kind == "special":
        coll.add("payload.special_file", path, 0, "special file is forbidden in a submission", tag="spc")
        return
    if blob.data is None:
        coll.add("file.too_large", path, 0,
                 f"file is larger than {MAX_FILE_BYTES} bytes and was not screened", tag="big")
        return

    data = blob.data
    label = detect_executable(data[:MAGIC_READ] if len(data) >= MAGIC_READ else data)
    if label is None and len(data) >= 0x40:
        label = detect_executable(data)
    if label is not None:
        coll.add("binary.executable", path, 0,
                 f"{label} shipped as {PurePosixPath(path).suffix or 'an extensionless file'}",
                 tag="exe")
        return

    ext = PurePosixPath(path).suffix.lower()
    name = PurePosixPath(path).name

    if not is_texty(data):
        if ext not in MEDIA_EXTS and ext not in DATA_EXTS:
            coll.add("binary.opaque", path, 0,
                     "opaque binary blob cannot be statically screened", tag="opaque")
        return

    if blob.size > MAX_SCAN_BYTES:
        coll.add("file.too_large", path, 0,
                 f"file exceeds {MAX_SCAN_BYTES} bytes; only magic/size were checked", tag="scanbig")
        return

    text = data.decode("utf-8", "replace")
    is_doc = ext in DOC_EXTS
    is_code = (
        ext in PY_EXTS or ext in SHELL_EXTS or ext in JS_QML_EXTS
        or text.startswith("#!")
    )
    # Fail closed on lines too long to fully screen. Secret patterns already
    # scanned the whole line uncapped; the remaining superlinear code-exec rules
    # are bounded by the ReDoS cap, so an over-long line is a real screening gap
    # for executable content (blocking) and an honest note for data (warning).
    for _lineno, _line in enumerate(text.split("\n"), start=1):
        if len(_line) > MAX_LINE_BYTES:
            coll.add("scan.line_too_long", path, _lineno,
                     f"line exceeds {MAX_LINE_BYTES} bytes and cannot be fully "
                     f"screened for execution patterns; split or shorten it",
                     tag="longline",
                     severity=(SEV_BLOCK if is_code else SEV_WARN))
    proot = plugin_root_for(path, roots)
    manifest = roots.get(proot) if proot is not None else None
    declared_hosts: set[str] = set()
    declared_cmds: Optional[set[str]] = None
    if manifest is not None:
        declared_hosts, declared_cmds = manifest_declared(manifest)

    scan_universal_text(coll, path, ext, text, is_doc)

    if name in ("manifest.json", "product-manifest.json"):
        scan_manifest(coll, path, text)
    elif ext == ".json":
        try:
            load_json_bytes(data)
        except ValueError:
            coll.add("parse.json_error", path, 0, "JSON document did not parse", tag="json")

    shebang = ""
    if text.startswith("#!"):
        shebang = text.split("\n", 1)[0]

    if ext in PY_EXTS or "python" in shebang:
        scan_python(coll, path, text, declared_cmds)
    if ext in SHELL_EXTS or re.search(r"\b(?:ba|z|da)?sh\b", shebang):
        scan_shell(coll, path, text, declared_cmds)
    if ext in JS_QML_EXTS:
        scan_js_qml(coll, path, text, proot)

    # undeclared network hosts: only inside a plugin folder, only in code.
    if proot is not None and not is_doc and (
        ext in PY_EXTS or ext in SHELL_EXTS or ext in JS_QML_EXTS
    ):
        scan_network_hosts(coll, path, text, declared_hosts)


def _postfilter(findings: list[Finding]) -> list[Finding]:
    """Drop a sensitive-reference warning when a sensitive-write blocking finding
    already covers the same path+line (avoid double reporting)."""
    blocked = {
        (f.path, f.line) for f in findings if f.rule == "config.sensitive_write"
    }
    return [
        f for f in findings
        if not (f.rule == "config.sensitive_reference" and (f.path, f.line) in blocked)
    ]


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #
def screen(root: Path, *, staged: bool = False, revision: Optional[str] = None,
           policy_root: Optional[Path] = None,
           today: Optional[datetime.date] = None) -> dict:
    """Run the screen. Returns the JSON envelope dict. Never raises for a scan
    problem: infrastructure/input failures land in ``errors``."""
    today = today or datetime.date.today()
    coll = Collector()
    errors: list[str] = []
    sha_by_path: dict[str, Optional[str]] = {}

    if not root.exists():
        return {"schema": 1, "findings": [], "errors": [f"root does not exist: {root}"]}
    if not root.is_dir():
        return {"schema": 1, "findings": [], "errors": [f"root is not a directory: {root}"]}

    if policy_root is None:
        policy_root = Path(__file__).resolve().parent.parent

    budget = Budget()
    try:
        if staged:
            source = enum_index(root, coll, budget)
        elif revision is not None:
            source = enum_revision(root, revision, coll, budget)
        else:
            source = enum_worktree(root, coll, budget)
        blobs = list(source)
    except ScreenError as exc:
        errors.append(str(exc))
        return _envelope(coll.findings(), errors)

    for blob in blobs:
        if blob.kind == "file":
            sha_by_path[blob.path] = blob.sha256

    roots = discover_plugin_roots(blobs)

    try:
        exceptions = load_exceptions(policy_root, coll, today)
    except ScreenError as exc:
        errors.append(str(exc))
        return _envelope(coll.findings(), errors)

    for blob in blobs:
        try:
            scan_blob(coll, blob, roots)
        except ScreenError as exc:
            errors.append(str(exc))
        except Exception as exc:                       # never crash on one file
            errors.append(f"internal error screening {blob.path}: {exc!r}")

    findings = _postfilter(coll.findings())

    # Exceptions never suppress allowlist-integrity findings themselves.
    integrity = [f for f in findings if f.rule.startswith("exception.")]
    scannable = [f for f in findings if not f.rule.startswith("exception.")]
    kept = apply_exceptions(scannable, exceptions, sha_by_path, coll)
    kept.extend(f for f in coll.findings() if f.rule == "exception.unused")
    kept.extend(integrity)

    return _envelope(kept, errors)


_CONTROL_CHARS = re.compile(r"[\x00-\x1f\x7f]")


def _redact_out(text: str) -> str:
    """Central output scrubber applied to every candidate-derived string that
    leaves the tool (finding message, path, error). It redacts secret-shaped
    substrings so a token embedded in a URL, filename or manifest value cannot
    leak through a diagnostic, escapes control characters so a crafted name
    cannot spoof the report, and bounds length."""
    if not isinstance(text, str):
        text = str(text)
    for rule, pattern in _SECRET_PATTERNS:
        text = pattern.sub("<redacted:%s>" % rule.split(".")[-1], text)
    text = _CONTROL_CHARS.sub(lambda m: "\\x%02x" % ord(m.group()), text)
    if len(text) > 300:
        text = text[:300] + "...(truncated)"
    return text


def _envelope(findings: list[Finding], errors: list[str]) -> dict:
    unique: dict[str, Finding] = {f.fingerprint: f for f in findings}
    ordered = sorted(
        unique.values(),
        key=lambda f: (f.path, f.line, f.rule, f.fingerprint),
    )
    out_findings = []
    for f in ordered:
        row = f.as_dict()
        row["path"] = _redact_out(row["path"])
        row["message"] = _redact_out(row["message"])
        out_findings.append(row)
    return {
        "schema": 1,
        "findings": out_findings,
        "errors": [_redact_out(e) for e in errors],
    }


def exit_code(envelope: dict) -> int:
    if envelope["errors"]:
        return 2
    if any(f["severity"] == SEV_BLOCK for f in envelope["findings"]):
        return 1
    return 0


# --------------------------------------------------------------------------- #
# Output
# --------------------------------------------------------------------------- #
def format_text(envelope: dict) -> str:
    lines: list[str] = []
    blocking = [f for f in envelope["findings"] if f["severity"] == SEV_BLOCK]
    warnings = [f for f in envelope["findings"] if f["severity"] == SEV_WARN]
    for finding in envelope["findings"]:
        loc = finding["path"]
        if finding["line"]:
            loc += f":{finding['line']}"
        lines.append(
            f"{finding['severity'].upper():8} {finding['rule']:32} {loc}\n"
            f"         {finding['message']}"
        )
    for error in envelope["errors"]:
        lines.append(f"ERROR    {error}")
    summary = (
        f"security-screen: {len(blocking)} blocking, {len(warnings)} warning(s), "
        f"{len(envelope['errors'])} error(s)"
    )
    lines.append(summary)
    return "\n".join(lines)


def format_json(envelope: dict) -> str:
    return json.dumps(envelope, indent=2, ensure_ascii=True)


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Statically screen a RyoStore submission for unsafe content."
    )
    parser.add_argument("--root", type=Path, default=Path("."),
                        help="candidate tree to scan (default: current directory)")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--staged", action="store_true",
                      help="screen the exact Git index tree instead of the disk tree")
    mode.add_argument("--revision", metavar="REF",
                      help="screen the exact Git tree at REF instead of the disk tree")
    parser.add_argument("--policy-root", type=Path, default=None,
                        help="trusted policy root for the exception allowlist "
                             "(default: the repository shipping this tool)")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--list-rules", action="store_true",
                        help="print the rule catalogue and exit")
    args = parser.parse_args(argv)

    if args.list_rules:
        for rule, (severity, title) in sorted(RULES.items()):
            print(f"{severity:8} {rule:32} {title}")
        return 0

    try:
        envelope = screen(
            args.root, staged=args.staged, revision=args.revision,
            policy_root=args.policy_root,
        )
    except ScreenError as exc:               # defensive: should be caught inside
        envelope = {"schema": 1, "findings": [], "errors": [str(exc)]}

    if args.format == "json":
        print(format_json(envelope))
    else:
        print(format_text(envelope))
    return exit_code(envelope)


if __name__ == "__main__":
    raise SystemExit(main())
