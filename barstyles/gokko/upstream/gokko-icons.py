#!/usr/bin/env python3
"""Gokko's reversible per-user WhiteSur icon activation.

Gokko owns no global icon assets: install via Nix if needed, activate only
while Gokko is selected, and restore only values still under our control.
No root access, no global config modifications, no arbitrary installer scripts.
"""
import configparser
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
CONFIG = Path(os.environ.get('XDG_CONFIG_HOME') or HOME / '.config')
DATA = Path(os.environ.get('XDG_DATA_HOME') or HOME / '.local/share')
STATE = Path(os.environ.get('XDG_STATE_HOME') or HOME / '.local/state') / 'ryoku/gokko-icons'
STATE_FILE = STATE / 'state.json'
PREFERRED = 'WhiteSur-dark'


def msg(*args):
    print('[gokko-icons]', *args, flush=True)


def run(cmd, check=False):
    return subprocess.run(cmd, text=True, capture_output=True, check=check)


def selected():
    path = CONFIG / 'ryoku/shell.json'
    try:
        cfg = json.loads(path.read_text())
    except (OSError, ValueError):
        return False
    if cfg.get('barStyle') == 'gokko':
        return True
    # Per-screen overrides must not cause the hook to restore while another
    # output is still running Gokko.
    def deep(v):
        if isinstance(v, dict):
            if v.get('barStyle') == 'gokko':
                return True
            return any(deep(x) for x in v.values())
        if isinstance(v, list):
            return any(deep(x) for x in v)
        return False
    return deep(cfg.get('displays', {}))


def roots():
    roots = [DATA / 'icons', HOME / '.icons']
    for part in (os.environ.get('XDG_DATA_DIRS') or '/usr/local/share:/usr/share').split(':'):
        if part:
            roots.append(Path(part) / 'icons')
    roots.extend([Path('/run/current-system/sw/share/icons'), Path('/usr/share/icons')])
    return list(dict.fromkeys(roots))


def available(name):
    return any((r / name / 'index.theme').is_file() for r in roots())


def nix_acquire():
    if not shutil.which('nix'):
        msg('WhiteSur is not installed and Nix is unavailable; leaving icons unchanged')
        return False
    # A persistent Nix output link prevents garbage collection, without adding
    # an unrelated package to the user's Nix profile or system generation.
    link = STATE / 'whitesur-nix'
    cmd = ['nix', 'build', '--out-link', str(link), '--print-out-paths',
           'nixpkgs#whitesur-icon-theme']
    try:
        p = subprocess.run(cmd, text=True, capture_output=True, timeout=600)
    except (OSError, subprocess.TimeoutExpired) as exc:
        msg('Nix package installation unavailable:', exc)
        return False
    if p.returncode:
        msg('Nix package installation failed:', p.stderr.strip()[-900:])
        return False
    where = link / 'share/icons'
    targets = ('WhiteSur', 'WhiteSur-dark', 'WhiteSur-light')
    if not (where / PREFERRED / 'index.theme').is_file():
        msg('Nix package lacks the expected WhiteSur-dark theme')
        return False
    dest = DATA / 'icons'
    dest.mkdir(parents=True, exist_ok=True)
    for name in targets:
        src = where / name
        out = dest / name
        if not (src / 'index.theme').is_file():
            continue
        # Existing user-owned themes always win. Never replace a symlink or dir.
        if not out.exists() and not out.is_symlink():
            out.symlink_to(src, target_is_directory=True)
    return available(PREFERRED)


def gtk_theme():
    if not shutil.which('gsettings'):
        return None
    p = run(['gsettings', 'get', 'org.gnome.desktop.interface', 'icon-theme'])
    if p.returncode:
        return None
    return p.stdout.strip().strip("'\"")


def set_gtk(theme):
    if not shutil.which('gsettings'):
        return False
    p = run(['gsettings', 'set', 'org.gnome.desktop.interface', 'icon-theme', theme])
    if p.returncode:
        msg('GTK icon-theme switch failed:', p.stderr.strip()[-400:])
    return p.returncode == 0


# On minimal NixOS/niri sessions, gsettings can exist without any installed
# org.gnome.desktop.interface schema. GTK then relies on per-user settings.ini.
# Only manipulate the icon-theme key, not GTK colours, fonts or user CSS.
def gtk_ini_path(version):
    return CONFIG / f'gtk-{version}.0/settings.ini'


def gtk_ini_value(path):
    if not path.is_file():
        return None
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        cfg.read_string(path.read_text())
        return cfg.get('Settings', 'gtk-icon-theme-name', fallback=None)
    except (OSError, UnicodeError, configparser.Error):
        return None


def set_gtk_ini(path, value):
    if path.is_symlink():
        msg('GTK settings are a symlink; leaving them unchanged:', path)
        return False
    if path.exists() and (not path.is_file() or not (path.stat().st_mode & 0o222)):
        msg('GTK settings are managed or read-only; leaving unchanged:', path)
        return False
    if not path.exists() and value is None:
        return True
    try:
        old = path.read_text() if path.exists() else ''
        # Refuse malformed INI instead of silently damaging a user's settings.
        if old:
            cfg = configparser.ConfigParser(interpolation=None, strict=False)
            cfg.read_string(old)
    except (OSError, UnicodeError, configparser.Error) as exc:
        msg('Cannot edit GTK settings:', path, exc)
        return False

    # On restore, delete only an INI file we created and still exclusively own.
    if value is None and old.strip() == '[Settings]\ngtk-icon-theme-name=' + PREFERRED:
        path.unlink()
        return True

    lines = old.splitlines(keepends=True)
    out = []
    in_settings = False
    seen_section = False
    seen_key = False
    for line in lines:
        match = re.match(r'^\s*\[([^]]+)\]\s*$', line)
        if match:
            if in_settings and not seen_key and value is not None:
                out.append(f'gtk-icon-theme-name={value}\n')
                seen_key = True
            in_settings = match.group(1) == 'Settings'
            seen_section = seen_section or in_settings
        if in_settings and re.match(r'^\s*gtk-icon-theme-name\s*=', line):
            if not seen_key and value is not None:
                out.append(f'gtk-icon-theme-name={value}\n')
            seen_key = True
            continue
        out.append(line)
    if in_settings and not seen_key and value is not None:
        out.append(f'gtk-icon-theme-name={value}\n')
    if not seen_section and value is not None:
        if old and not old.endswith('\n'):
            out.append('\n')
        out.append(f'[Settings]\ngtk-icon-theme-name={value}\n')
    updated = ''.join(out)
    if updated == old:
        return True
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(updated)
    except OSError as exc:
        msg('Could not write GTK settings:', path, exc)
        return False
    return True


def activate_gtk_fallback(state):
    # Don't create a competing fallback when a real GSettings theme is readable.
    if gtk_theme() is not None:
        return
    state.setdefault('gtk_ini', {})
    for version in (3, 4):
        name = str(version)
        if name in state['gtk_ini']:
            continue  # user may have changed this key since last activation
        path = gtk_ini_path(version)
        before = gtk_ini_value(path)
        rec = {'before': before, 'owned': False}
        state['gtk_ini'][name] = rec
        write_state(state)
        if before != PREFERRED and set_gtk_ini(path, PREFERRED):
            rec['owned'] = True
            write_state(state)


def restore_gtk_fallback(state):
    ok = True
    for version, rec in state.get('gtk_ini', {}).items():
        if not rec.get('owned'):
            continue
        path = gtk_ini_path(version)
        # The user or a theme manager changed it: preserve that decision.
        if gtk_ini_value(path) != PREFERRED:
            continue
        if not set_gtk_ini(path, rec.get('before')):
            ok = False
    return ok


def qtfile():
    return CONFIG / 'qt6ct/qt6ct.conf'


def qt_theme():
    path = qtfile()
    if not path.is_file():
        return None
    cfg = configparser.ConfigParser(interpolation=None)
    try:
        cfg.read(path)
        return cfg.get('Appearance', 'icon_theme', fallback=None)
    except (OSError, configparser.Error):
        return None


def set_qt(value):
    path = qtfile()
    if path.is_symlink() or (path.exists() and not os.access(path, os.W_OK)):
        msg('Qt config is managed or read-only; leaving it unchanged:', path)
        return False
    if not path.exists() and value is None:
        return False
    old = path.read_text() if path.exists() else '[Appearance]\n'
    lines = old.splitlines(keepends=True)
    current_section = None
    found = False
    out = []
    inserted = False
    for line in lines:
        header = re.match(r'^\s*\[([^]]+)\]\s*$', line)
        if header:
            if current_section == 'Appearance' and not found and value is not None and not inserted:
                out.append(f'icon_theme={value}\n')
                inserted = True
            current_section = header.group(1)
        if current_section == 'Appearance' and re.match(r'^\s*icon_theme\s*=', line):
            if not found and value is not None:
                out.append(f'icon_theme={value}\n')
            found = True
            continue
        out.append(line)
    if current_section == 'Appearance' and not found and value is not None and not inserted:
        out.append(f'icon_theme={value}\n')
    if '[Appearance]' not in old and value is not None:
        out.append(f'\n[Appearance]\nicon_theme={value}\n')
    new = ''.join(out)
    if new == old:
        return True
    path.parent.mkdir(parents=True, exist_ok=True)
    # Do not replace existing files by renaming: their owner or declaration
    # may depend on the original inode. Only regular, writable user configs.
    with path.open('w') as f:
        f.write(new)
    return True


def write_state(obj):
    tmp = STATE_FILE.with_suffix('.tmp')
    tmp.write_text(json.dumps(obj, indent=2) + '\n')
    tmp.replace(STATE_FILE)


def activate():
    if not selected():
        msg('Gokko is not selected; no icon changes')
        return 0
    if STATE_FILE.exists():
        # Upgrade an existing v0.2.7 session without losing its saved Qt theme.
        # Previously, a missing GNOME schema silently skipped GTK entirely.
        state = json.loads(STATE_FILE.read_text())
        activate_gtk_fallback(state)
        msg('existing icon session; GTK fallback checked, original preferences preserved')
        return 0
    if not available(PREFERRED) and not nix_acquire():
        return 0  # The shell must never be affected by a theme install failure.
    if not selected():
        msg("Selection changed during icon installation; not activating")
        return 0
    previous_gtk = gtk_theme()
    previous_qt = qt_theme()
    state = {'theme': PREFERRED, 'gtk': previous_gtk, 'qt': previous_qt,
             'gtk_owned': False, 'qt_owned': False,
             'qt_file_existed': qtfile().exists()}
    write_state(state)
    if previous_gtk is not None and previous_gtk != PREFERRED:
        state['gtk_owned'] = set_gtk(PREFERRED)
        write_state(state)
    if previous_qt != PREFERRED:
        state['qt_owned'] = set_qt(PREFERRED)
    write_state(state)
    activate_gtk_fallback(state)
    msg('activated', PREFERRED, '(GSettings:', state['gtk_owned'],
        'GTK INI:', sorted(k for k, v in state.get('gtk_ini', {}).items() if v['owned']),
        'Qt:', state['qt_owned'], ')')
    return 0


def restore():
    if selected():
        msg('Gokko remains selected; keeping icon theme')
        return 0
    if not STATE_FILE.exists():
        return 0
    state = json.loads(STATE_FILE.read_text())
    failed = False
    if state.get('gtk_owned') and state.get('gtk') is not None and gtk_theme() == PREFERRED:
        failed = not set_gtk(state['gtk']) or failed
    if state.get('qt_owned') and qt_theme() == PREFERRED:
        if not state.get('qt_file_existed') and qtfile().is_file() and not qtfile().is_symlink() \
                and qtfile().read_text().strip() == '[Appearance]\nicon_theme=' + PREFERRED:
            qtfile().unlink()
        else:
            failed = not set_qt(state.get('qt')) or failed
    if not restore_gtk_fallback(state):
        failed = True
    if failed:
        msg('Restore incomplete; keeping state so it can be retried')
        return 1
    STATE_FILE.unlink(missing_ok=True)
    msg('restored previous icon settings where still owned')
    return 0


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ('activate', 'restore', 'status'):
        print('usage: gokko-icons.py activate|restore|status', file=sys.stderr)
        return 2
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / '.lock').open('w') as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        if sys.argv[1] == 'activate':
            return activate()
        if sys.argv[1] == 'restore':
            return restore()
        msg('selected:', selected(), 'theme installed:', available(PREFERRED),
            'GSettings:', gtk_theme(), 'GTK3:', gtk_ini_value(gtk_ini_path(3)),
            'GTK4:', gtk_ini_value(gtk_ini_path(4)),
            'Qt:', qt_theme(), 'session:', STATE_FILE.exists())
        return 0


if __name__ == '__main__':
    sys.exit(main())
