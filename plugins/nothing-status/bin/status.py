#!/usr/bin/env python3
"""Read local network, audio and battery state for the Ryoku bar."""

import json
import re
import subprocess
from pathlib import Path


def run(argv):
    try:
        return subprocess.run(
            argv, capture_output=True, text=True, timeout=2, check=False,
        ).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ''


def battery():
    plugged = False
    for supply in Path('/sys/class/power_supply').iterdir():
        try:
            if ((supply / 'type').read_text().strip().lower() != 'battery'
                    and (supply / 'online').read_text().strip() == '1'):
                plugged = True
                break
        except (OSError, ValueError):
            pass
    for root in sorted(Path('/sys/class/power_supply').glob('BAT*')):
        try:
            level = int((root / 'capacity').read_text().strip())
            status = (root / 'status').read_text().strip().lower()
            return level, status == 'charging', plugged or status in ('charging', 'full')
        except (OSError, ValueError):
            pass
    return -1, False, plugged


network = run(['nmcli', '-t', '-f', 'CONNECTIVITY', 'general', 'status'])
audio = run(['wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@'])
volume_match = re.search(r'Volume:\s*([0-9.]+)', audio)
level, charging, plugged = battery()
print(json.dumps({
    'network': network.splitlines()[0] if network else 'unknown',
    'volume': round(float(volume_match.group(1)) * 100) if volume_match else 0,
    'muted': '[MUTED]' in audio,
    'battery': level,
    'charging': charging,
    'plugged': plugged,
}))
