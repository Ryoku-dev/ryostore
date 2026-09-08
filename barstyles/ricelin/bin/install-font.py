#!/usr/bin/env python3
"""Install an explicitly dropped font without overwriting a user's named fonts."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    source = Path(sys.argv[1])
    if source.suffix.lower() not in {".ttf", ".otf"}:
        raise ValueError("Expected a TrueType or OpenType font")
    directory = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "fonts/ricelin"
    directory.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with source.open("rb") as incoming:
            if incoming.read(4) not in {b"\x00\x01\x00\x00", b"OTTO", b"true", b"ttcf"}:
                raise ValueError("Not a supported font file")
            incoming.seek(0)
            with tempfile.NamedTemporaryFile(dir=directory, delete=False) as output:
                temporary = Path(output.name)
                shutil.copyfileobj(incoming, output)
        with temporary.open("rb") as font:
            digest = hashlib.file_digest(font, "sha256").hexdigest()
        destination = directory / (digest + source.suffix.lower())
        temporary.chmod(0o644)
        os.replace(temporary, destination)
        subprocess.run(["fc-cache", "-f", str(directory)], check=True)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
