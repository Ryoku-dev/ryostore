#!/usr/bin/env python3
"""Read default PipeWire sink volume and mute state."""

import json
import re
import subprocess

try:
    result = subprocess.run(
        ['wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@'],
        capture_output=True, text=True, timeout=2, check=False,
    )
    raw = result.stdout
except (OSError, subprocess.TimeoutExpired):
    raw = ''
match = re.search(r'Volume:\s*([0-9.]+)', raw)
level = round(float(match.group(1)) * 100) if match else 0
print(json.dumps({'volume': level, 'muted': '[MUTED]' in raw}))
