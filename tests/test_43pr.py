"""Checks for the 43PR extraction; Qt rendering is optional on CI."""
import json
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def luminance(color):
    values = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return sum(w * (v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4)
               for w, v in zip((.2126, .7152, .0722), values))


class PaletteTests(unittest.TestCase):
    def test_registered_palettes_match_and_are_legible(self):
        registry = json.loads((ROOT / 'colorschemes/registry.json').read_text())
        entries = [e for e in registry['themes'] if e['id'].startswith('43pr-')]
        self.assertEqual(len(entries), 13)
        for entry in entries:
            with self.subTest(scheme=entry['id']):
                data = json.loads((ROOT / entry['path'] / (entry['id'] + '.json')).read_text())
                for mode, block in data.items():
                    self.assertEqual(entry[mode], block)
                    for role, on_role in [('mSurface', 'mOnSurface'), ('mPrimary', 'mOnPrimary'),
                                          ('mSecondary', 'mOnSecondary'), ('mTertiary', 'mOnTertiary'),
                                          ('mError', 'mOnError')]:
                        a, b = sorted((luminance(block[role]), luminance(block[on_role])))
                        self.assertGreaterEqual((b + .05) / (a + .05), 4.5, role)
                    self.assertEqual(len(block['terminal']['normal']), 8)
                    self.assertEqual(len(block['terminal']['bright']), 8)

    def test_fastfetch_has_no_personal_paths_or_commands(self):
        config = json.loads((ROOT / 'fastfetch/43pr/config.jsonc').read_text())
        self.assertEqual(config['logo']['type'], 'small')
        self.assertNotIn('source', config['logo'])
        self.assertNotIn('command', [m['type'] for m in config['modules']])
        borders = [m['format'] for m in config['modules']
                   if m['type'] == 'custom' and m['format'].startswith(('┌', '└'))]
        self.assertEqual({len(s) for s in borders}, {44})

    def test_bar_has_no_legacy_actions_or_shared_writes(self):
        scene = (ROOT / 'barstyles/43pr/Scene.qml').read_text()
        self.assertNotIn('"sh", "-c"', scene)
        self.assertNotIn('qs ipc', scene)
        self.assertNotIn('/.config/quickshell/', scene)
        self.assertIn('target: "43pr-bar"', scene)
        self.assertIn('screen: root.modelData', scene)


try:
    from PySide6.QtCore import QObject, Signal, Slot, QUrl, QMetaObject
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQuick import QQuickView
except ImportError:
    QGuiApplication = None


@unittest.skipIf(QGuiApplication is None, 'PySide6 is required for lockscreen runtime tests')
class LockTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
        cls.app = QGuiApplication.instance() or QGuiApplication([])

    def setUp(self):
        class Auth(QObject):
            loginFailed = Signal()

            def __init__(self):
                super().__init__()
                self.calls = []

            @Slot(str, str, int)
            def login(self, user, password, session):
                self.calls.append((user, password, session))

        self.auth = Auth()
        self.view = QQuickView()
        self.view.rootContext().setContextProperty('sddm', self.auth)
        self.view.setSource(QUrl.fromLocalFile(str(ROOT / 'lockscreens/43pr/content/Main.qml')))
        self.assertEqual(self.view.status(), QQuickView.Ready, self.view.errors())
        self.root = self.view.rootObject()
        self.password = self.root.findChild(QObject, 'password')

    def tearDown(self):
        self.view.close()
        self.view.deleteLater()
        self.app.processEvents()

    def submit(self):
        self.assertTrue(QMetaObject.invokeMethod(self.root, 'submit'))

    def test_empty_password_is_not_submitted(self):
        self.submit()
        self.assertEqual(self.auth.calls, [])

    def test_password_clears_and_duplicate_submit_is_blocked(self):
        self.password.setProperty('text', 'test-only-not-a-real-password')
        self.submit()
        self.submit()
        self.assertEqual(len(self.auth.calls), 1)
        self.assertEqual(self.auth.calls[0][1], 'test-only-not-a-real-password')
        self.assertEqual(self.password.property('text'), '')
        self.assertTrue(self.root.property('authenticating'))

    def test_failure_allows_retry(self):
        self.password.setProperty('text', 'test-only')
        self.submit()
        self.auth.loginFailed.emit()
        self.app.processEvents()
        self.assertFalse(self.root.property('authenticating'))
        self.assertIn('failed', self.root.property('errorMessage'))
        self.password.setProperty('text', 'retry-only')
        self.submit()
        self.assertEqual(len(self.auth.calls), 2)

    def test_small_screen_and_real_render(self):
        self.view.resize(1280, 720)
        self.view.show()
        for _ in range(10):
            self.app.processEvents()
        image = self.view.grabWindow()
        self.assertFalse(image.isNull())
        output = os.environ.get('RYOSTORE_43PR_LOCK_CAPTURE')
        if output:
            self.assertTrue(image.save(output))
        self.root.setWidth(480)
        self.root.setHeight(800)
        self.app.processEvents()
        self.assertGreater(self.password.width(), 0)
        self.assertLess(self.password.width(), 480)


if __name__ == '__main__':
    unittest.main()
