#!/usr/bin/env python3
"""
panel-applet-add.py — adds an applet to the Cinnamon panel by appending a
correctly-formatted entry to org.cinnamon enabled-applets, computing an
unused instance id automatically. Idempotent: does nothing if that UUID
is already on the panel somewhere.

Usage:
    python3 panel-applet-add.py <uuid> [panel:zone] [order]

    panel:zone defaults to "panel1:right", order defaults to "0" (Cinnamon
    reflows applets in a zone by this value, duplicates are fine).

enabled-applets entries look like: "panel1:right:0:workspace-switcher@cinnamon.org:5"
                                     panel   zone  order  uuid                    instance-id
"""
import sys
import subprocess
import ast


def main():
    if len(sys.argv) < 2:
        print("Usage: panel-applet-add.py <uuid> [panel:zone] [order]", file=sys.stderr)
        sys.exit(2)

    uuid = sys.argv[1]
    panel_zone = sys.argv[2] if len(sys.argv) > 2 else "panel1:right"
    order = sys.argv[3] if len(sys.argv) > 3 else "0"

    out = subprocess.run(["gsettings", "get", "org.cinnamon", "enabled-applets"],
                          capture_output=True, text=True)
    if out.returncode != 0:
        print("FAILED")
        sys.exit(1)

    raw = out.stdout.strip()
    try:
        current = ast.literal_eval(raw) if raw else []
        if not isinstance(current, list):
            current = []
    except Exception:
        current = []

    if any(f":{uuid}:" in entry for entry in current):
        print("ALREADY_PRESENT")
        return

    used_ids = set()
    for entry in current:
        parts = entry.split(":")
        if len(parts) >= 5 and parts[-1].isdigit():
            used_ids.add(int(parts[-1]))

    next_id = 0
    while next_id in used_ids:
        next_id += 1

    new_entry = f"{panel_zone}:{order}:{uuid}:{next_id}"
    current.append(new_entry)
    new_value = str(current).replace('"', "'")

    result = subprocess.run(["gsettings", "set", "org.cinnamon", "enabled-applets", new_value])
    if result.returncode != 0:
        print("FAILED")
        sys.exit(1)

    print("OK")


if __name__ == "__main__":
    main()
