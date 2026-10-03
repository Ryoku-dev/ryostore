#!/usr/bin/env python3
"""Read the local battery for the Nothing-style battery tile."""

import json
from pathlib import Path


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
            return {'level': max(0, min(level, 100)),
                    'charging': status == 'charging',
                    'plugged': plugged or status in ('charging', 'full')}
        except (OSError, ValueError):
            pass
    return {'level': -1, 'charging': False, 'plugged': plugged}


print(json.dumps(battery()))
