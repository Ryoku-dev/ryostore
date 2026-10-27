#!/usr/bin/env python3
"""kitsune-mantra's writer.

Reads one JSON line on stdin and rewrites the Kitsune theme.conf
with the gate, the order, the attempt limit, and the stored key
(set, keep, or clear). Keys it does not know are carried through.
The write is atomic and the file lands at mode 600.

Payload: {"gate": bool, "attempts": int, "order": [fold ids],
          "passAction": "set" | "keep" | "clear", "pass": "..."}
Prints the public state as JSON. Never the key.
"""
import json
import os
import sys
import tempfile

CANON = ["truth", "power", "wisdom", "judgment", "life", "love", "discipline"]
KNOWN = {"AllowUppercaseLettersInUsernames", "MantraGate", "MantraOrder",
         "MantraAttempts", "MantraPass"}

TEMPLATE = """[General]
# Kitsune — Ase, the seven-tailed kitsune, at the door.
#
# AllowUppercaseLettersInUsernames — the greeter's username rule.
# With it false, the name is lowered before it is spoken to PAM.
AllowUppercaseLettersInUsernames={uppercase}
#
# The mantra gate — a sequence in front of the password field.
# MantraGate=true stands it: the seven folds are dealt shuffled
# at every showing and answered — slot numbers, typed or tapped —
# in your MantraOrder before the field opens.
MantraGate={gate}
MantraOrder={order}
#
# MantraAttempts — wrong sequences allowed before the gate stands
# down to the password field for the rest of the showing.
MantraAttempts={attempts}
#
# MantraPass — leave empty. When set, a right sequence logs in
# directly with this key. It is your password in plain text;
# this file is mode 600. Keep it that way, or leave it empty.
MantraPass={mantra_pass}
"""


def read_old(path):
    old, unknown = {}, []
    if not os.path.exists(path):
        return old, unknown
    for line in open(path):
        t = line.strip()
        if "=" in t and not t.startswith("#"):
            key, value = t.split("=", 1)
            key = key.strip()
            if key in KNOWN:
                old[key] = value.strip()
            elif key:
                unknown.append(t)
    return old, unknown


def public_state(path):
    old, _ = read_old(path)
    order = [o for o in old.get("MantraOrder", "").split(",") if o in CANON]
    try:
        attempts = max(1, min(9, int(old.get("MantraAttempts", "3"))))
    except ValueError:
        attempts = 3
    return {
        "gate": old.get("MantraGate") == "true",
        "attempts": attempts,
        "order": order if len(order) == 7 else CANON,
        "keySet": bool(old.get("MantraPass", "")),
        "exists": bool(old),
    }


def main():
    path = sys.argv[1]
    if len(sys.argv) > 2 and sys.argv[2] == "read":
        print(json.dumps(public_state(path)))
        return
    try:
        payload = json.loads(sys.stdin.readline())
        int(payload.get("attempts", 3))
    except (ValueError, TypeError, AttributeError):
        sys.exit(2)
    old, unknown = read_old(path)

    order = [o for o in payload.get("order", []) if o in CANON]
    if len(order) != 7 or len(set(order)) != 7:
        order = [o for o in old.get("MantraOrder", "").split(",") if o in CANON]
    if len(order) != 7:
        order = CANON

    action = payload.get("passAction", "keep")
    if action == "set":
        mantra_pass = payload.get("pass", "")
    elif action == "clear":
        mantra_pass = ""
    else:
        mantra_pass = old.get("MantraPass", "")

    text = TEMPLATE.format(
        uppercase=old.get("AllowUppercaseLettersInUsernames", "false"),
        gate="true" if payload.get("gate") else "false",
        order=",".join(order),
        attempts=max(1, min(9, int(payload.get("attempts", 3)))),
        mantra_pass=mantra_pass,
    )
    if unknown:
        text += "#\n# Kept from the previous file:\n"
        text += "\n".join(unknown) + "\n"

    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".", prefix=".theme.conf.")
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)

    print(json.dumps({
        "gate": bool(payload.get("gate")),
        "attempts": max(1, min(9, int(payload.get("attempts", 3)))),
        "order": order,
        "keySet": bool(mantra_pass),
    }))


if __name__ == "__main__":
    main()
