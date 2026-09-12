"""Security boundaries exercised through real files, helper processes and TCP callbacks."""
import contextlib
import base64
import importlib
import io
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request

BIN = Path(__file__).resolve().parents[1] / "plugins" / "gmail" / "bin"


class GmailSecurityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.environment = {**os.environ, "XDG_STATE_HOME": str(self.root / "state"),
                            "HOME": str(self.root), "PYTHONDONTWRITEBYTECODE": "1"}
        self.environment_patch = patch.dict(os.environ, self.environment)
        self.environment_patch.start()
        self.addCleanup(self.environment_patch.stop)
        self.private = self.root / "state" / "ryoku" / "plugins" / "gmail"

    def helper(self, name, *arguments, payload="", check=True):
        return subprocess.run([sys.executable, str(BIN / name), *arguments], input=payload,
                              text=True, capture_output=True, env=self.environment,
                              timeout=5, check=check)

    def module(self, name):
        old_path = sys.path[:]
        saved = {key: sys.modules.get(key) for key in
                 ("gmail_config", "accounts_store", "oauth_server", "download_email_attachment",
                  "fetch_email_body", "send_email")}
        sys.path.insert(0, str(BIN))
        for key in saved:
            sys.modules.pop(key, None)
        with patch.object(sys, "dont_write_bytecode", True):
            module = importlib.import_module(name)

        def restore():
            sys.path[:] = old_path
            for key, value in saved.items():
                sys.modules.pop(key, None)
                if value is not None:
                    sys.modules[key] = value
        self.addCleanup(restore)
        return module

    def test_credentials_and_accounts_stay_private(self):
        previous_umask = os.umask(0)
        try:
            self.helper("backup_gmail_env.py", payload=json.dumps({
                "client_id": "example.apps.googleusercontent.com", "client_secret": "test-only"}))
            self.helper("accounts_store.py", "save", payload=json.dumps([{"email": "test@example.com"}]))
        finally:
            os.umask(previous_umask)
        self.assertEqual(self.private.stat().st_mode & 0o777, 0o700)
        for filename in ("gmail.env", "accounts.json"):
            self.assertEqual((self.private / filename).stat().st_mode & 0o777, 0o600)
        self.assertEqual(json.loads(self.helper("accounts_store.py", "get").stdout),
                         [{"email": "test@example.com"}])

    def test_private_file_symlink_cannot_read_or_overwrite_target(self):
        self.private.mkdir(parents=True)
        outside = self.root / "outside.json"
        outside.write_text('[{"email":"outside@example.com"}]')
        (self.private / "accounts.json").symlink_to(outside)
        self.assertNotEqual(self.helper("accounts_store.py", "get", check=False).returncode, 0)
        self.helper("accounts_store.py", "save", payload="[]")
        self.assertEqual(outside.read_text(), '[{"email":"outside@example.com"}]')
        self.assertFalse((self.private / "accounts.json").is_symlink())
        self.assertEqual(json.loads(self.helper("accounts_store.py", "get").stdout), [])

    def test_symlinked_plugin_namespace_is_rejected(self):
        parent = self.private.parent
        parent.mkdir(parents=True)
        outside = self.root / "outside"
        outside.mkdir()
        self.private.symlink_to(outside, target_is_directory=True)
        result = self.helper("accounts_store.py", "save", payload="[]", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])

    def test_credentials_reject_newline_injection(self):
        result = self.helper("backup_gmail_env.py", payload=json.dumps({
            "client_id": "valid\nINJECTED=value", "client_secret": "test-only"}), check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.private / "gmail.env").exists())

    def test_attachment_dangling_link_and_path_traversal_are_safe(self):
        downloader = self.module("download_email_attachment")
        downloads = self.root / "downloads"
        downloads.mkdir()
        outside = self.root / "must-not-exist"
        (downloads / "note.txt").symlink_to(outside)
        first = Path(downloader.save_attachment(str(downloads), "../../note.txt", b"first"))
        second = Path(downloader.save_attachment(str(downloads), "note.txt", b"second"))
        self.assertFalse(outside.exists())
        self.assertEqual(first.parent, downloads)
        self.assertEqual(first.read_bytes(), b"first")
        self.assertEqual(second.read_bytes(), b"second")
        self.assertNotEqual(first, second)
        self.assertEqual(first.stat().st_mode & 0o777, 0o600)

    def request(self, server, path):
        worker = threading.Thread(target=server.handle_request, daemon=True)
        worker.start()
        try:
            try:
                response = urllib.request.urlopen(f"http://127.0.0.1:{server.server_port}" + path, timeout=2)
            except urllib.error.HTTPError as error:
                response = error
            with response:
                return response.status, response.read(), response.headers
        finally:
            worker.join(timeout=3)
            self.assertFalse(worker.is_alive())

    def test_oauth_state_rejects_forgery_without_cancelling_real_session(self):
        oauth = self.module("oauth_server")
        with oauth.OAuthServer(("client", "test-only"), port=0) as server:
            for path in ("/callback?code=code", "/callback?code=code&state=wrong",
                         f"/callback?code=code&state={server.state}&state={server.state}",
                         "/callback?error=denied&state=wrong"):
                status, _, _ = self.request(server, path)
                self.assertEqual(status, 400)
                self.assertIsNone(server.result)
            with patch.object(oauth, "request_json", side_effect=[
                {"refresh_token": "test-refresh", "access_token": "test-access"},
                {"email": "test@example.com", "verified_email": True},
            ]):
                status, body, headers = self.request(server, f"/callback?code=code&state={server.state}")
            self.assertEqual(status, 200)
            self.assertEqual(headers["Cache-Control"], "no-store")
            self.assertNotIn(b"test-refresh", body)
            self.assertNotIn("refresh", server.result)
            self.assertEqual(json.loads((self.private / "accounts.json").read_text())[0]["email"],
                             "test@example.com")

    def test_oauth_timeout_closes_listener(self):
        oauth = self.module("oauth_server")
        server = oauth.OAuthServer(("client", "test-only"), port=0)
        port = server.server_port
        output = io.StringIO()
        with patch.object(oauth.gmail_config, "get_credentials", return_value=("client", "test-only")), \
             patch.object(oauth, "OAuthServer", return_value=server), \
             patch.object(oauth.subprocess, "Popen"), patch.object(oauth, "AUTH_SECONDS", 0), \
             contextlib.redirect_stdout(output):
            self.assertEqual(oauth.main(), 1)
        self.assertIn("timed out", json.loads(output.getvalue())["error"])
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", port))

    def test_browser_preview_is_private_and_inert(self):
        body = self.module("fetch_email_body")
        incoming = ('<p>Invoice</p><script>window.compromised=true</script>'
                    '<img src="https://tracker.invalid/open">'
                    '<a href="file:///etc/passwd">local</a>'
                    '<a href="javascript:alert(1)">script</a>'
                    '<a href="https://example.com/invoice">invoice link</a>')
        message = {"payload": {"mimeType": "text/html", "body": {
            "data": base64.urlsafe_b64encode(incoming.encode()).decode()}}}
        output = io.StringIO()
        with patch.object(body, "api_get", return_value=message), \
             patch.object(body.gmail_config, "runtime_token", return_value="ya29.test-only"), \
             patch.object(sys, "argv", ["fetch_email_body.py", "../untrusted-id"]), \
             contextlib.redirect_stdout(output):
            body.main()
        result = json.loads(output.getvalue())
        preview = Path(result["htmlPath"])
        document = preview.read_text()
        self.assertEqual(preview.parent, self.private)
        self.assertEqual(preview.stat().st_mode & 0o777, 0o600)
        self.assertIn('href="https://example.com/invoice"', document)
        for unsafe in ("<script", "<img", "file://", "javascript:", "tracker.invalid"):
            self.assertNotIn(unsafe, document)
        self.assertIn("default-src 'none'", document)
        self.assertIn("Invoice", result["body"])


if __name__ == "__main__":
    unittest.main()
