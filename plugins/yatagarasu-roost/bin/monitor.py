#!/usr/bin/env python3
# Yatagarasu Roost — the listener. Watches the session's
# notification bus from the public square (via dbus-monitor)
# and reports the mood of the moment: the priority of the
# freshest scroll still standing, or EMPTY when the wire is
# clear. Speaks on stdout: READY / ARRIVE <P> / MOOD <P|EMPTY>
import subprocess, sys, re

stack = {}    # notification id -> priority
pending = {}  # call serial -> (priority, replaces_id)

def emit_mood():
    top = ""
    for v in stack.values():
        top = v
    print("MOOD " + (top if top else "EMPTY"), flush=True)

def prio_of(hints):
    if "x-jurai-priority" in hints:
        v = str(hints["x-jurai-priority"]).upper()
        if v in ("LOW", "MEDIUM", "HIGH", "CRITICAL"):
            return v
    try:
        u = int(hints.get("urgency", 1))
    except Exception:
        u = 1
    return "CRITICAL" if u >= 2 else ("LOW" if u <= 0 else "MEDIUM")

proc = subprocess.Popen(
    ["dbus-monitor", "interface='org.freedesktop.Notifications'", "type='method_return'"],
    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)
print("READY", flush=True)

mode = None        # None | "notify" | "return" | "closed"
serial = None
reply_serial = None
body_lines = []

def finish_block():
    global mode
    if mode == "notify" and serial is not None:
        replaces = 0
        hints = {}
        first_uint = True
        lines = body_lines
        for i, ln in enumerate(lines):
            s = ln.strip()
            if first_uint:
                m = re.match(r"uint32 (\d+)", s)
                if m:
                    replaces = int(m.group(1)); first_uint = False
                    continue
            m = re.match(r'string "(urgency|x-jurai-priority)"', s)
            if m and i + 1 < len(lines):
                vm = re.search(r"variant\s+(?:byte (\d+)|string \"(.*)\")", lines[i + 1])
                if vm:
                    hints[m.group(1)] = vm.group(1) if vm.group(1) is not None else vm.group(2)
        p = prio_of(hints)
        pending[serial] = (p, replaces)
        print("ARRIVE " + p, flush=True)
    elif mode == "return" and reply_serial in pending:
        p, replaces = pending.pop(reply_serial)
        for ln in body_lines:
            m = re.match(r"uint32 (\d+)", ln.strip())
            if m:
                nid = int(m.group(1))
                if replaces:
                    stack.pop(replaces, None)
                if nid:
                    stack[nid] = p
                    emit_mood()
                break
    elif mode == "closed":
        for ln in body_lines:
            m = re.match(r"uint32 (\d+)", ln.strip())
            if m:
                nid = int(m.group(1))
                if nid in stack:
                    del stack[nid]
                    emit_mood()
                break
    mode = None

for line in proc.stdout:
    if not line.startswith((" ", "\t")):   # a new message header
        finish_block()
        body_lines = []
        serial = reply_serial = None
        if line.startswith("method call") and "member=Notify" in line:
            mode = "notify"
            m = re.search(r"serial=(\d+)", line)
            serial = int(m.group(1)) if m else None
        elif line.startswith("method return"):
            mode = "return"
            m = re.search(r"reply_serial=(\d+)", line)
            reply_serial = int(m.group(1)) if m else None
        elif line.startswith("signal") and "member=NotificationClosed" in line:
            mode = "closed"
        else:
            mode = None
    else:
        if mode:
            body_lines.append(line)
finish_block()
