#!/usr/bin/env python3
"""Read today's screen time from Ryoku's own local counter."""

import json
import os
from datetime import datetime
from pathlib import Path


def main():
    state_home = Path(os.environ.get('XDG_STATE_HOME') or (Path.home() / '.local/state'))
    path = state_home / 'ryoku' / 'screentime.json'
    try:
        days = json.loads(path.read_text()).get('days', {})
        entry = days.get(datetime.now().strftime('%Y-%m-%d'), {})
        seconds = max(0, int(entry.get('total', 0)))
        available = True
    except (OSError, ValueError, TypeError, AttributeError):
        seconds = 0
        available = False
    print(json.dumps({'seconds': seconds, 'available': available}))


if __name__ == '__main__':
    main()
