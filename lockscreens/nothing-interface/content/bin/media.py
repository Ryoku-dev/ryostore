#!/usr/bin/env python3
"""Read local MPRIS metadata through playerctl."""

import json
import subprocess


def read(argv):
    try:
        return subprocess.run(
            argv, capture_output=True, text=True, timeout=2, check=False,
        ).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ''


status = read(['playerctl', 'status'])
metadata = read(['playerctl', 'metadata', '--format', '{{title}}\n{{artist}}'])
art_url = read(['playerctl', 'metadata', '--format', '{{mpris:artUrl}}'])
lines = metadata.splitlines()
try:
    position = max(0.0, float(read(['playerctl', 'position'])))
except ValueError:
    position = 0.0
try:
    length = max(0.0, float(read(['playerctl', 'metadata', '--format', '{{mpris:length}}'])) / 1_000_000)
except ValueError:
    length = 0.0
print(json.dumps({
    'playing': status == 'Playing',
    'available': status in ('Playing', 'Paused'),
    'title': lines[0][:80] if lines else '',
    'artist': lines[1][:60] if len(lines) > 1 else '',
    'artUrl': art_url if status in ('Playing', 'Paused') else '',
    'position': position,
    'length': length,
}, ensure_ascii=False))
