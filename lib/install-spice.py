#!/usr/bin/env python3
"""
install-spice.py — fetches one Cinnamon Spice (extension or applet) directly
from the official linuxmint/cinnamon-spices-{extensions,applets} repo on
GitHub, using the Contents API so only that spice's files are downloaded —
not the whole multi-hundred-extension repo.

Usage:
    python3 install-spice.py <extensions|applets> <UUID> <dest_root_dir>

Writes to <dest_root_dir>/<UUID>/... (matching the layout Cinnamon itself
expects under ~/.local/share/cinnamon/extensions/ or .../applets/).

Every UUID this toolkit calls this with has been verified by hand against
the real linuxmint/cinnamon-spices-* repos — see fancyCinnamon.sh for the
list and where each one is documented.
"""
import sys
import os
import json
import urllib.request
import urllib.error

REPO = {
    "extensions": "linuxmint/cinnamon-spices-extensions",
    "applets": "linuxmint/cinnamon-spices-applets",
}


def api_get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "devuan-cinnamon-setup"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def download_file(url, dest_path):
    req = urllib.request.Request(url, headers={"User-Agent": "devuan-cinnamon-setup"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    with open(dest_path, "wb") as f:
        f.write(data)


def fetch_dir(api_url, local_dir, depth=0):
    if depth > 6:
        # Defensive recursion cap — no real spice nests this deep. Avoids a
        # runaway loop if the API ever returns something unexpected.
        return
    entries = api_get(api_url)
    if not isinstance(entries, list):
        raise RuntimeError(f"Unexpected API response (rate-limited or path wrong?): {entries}")
    for entry in entries:
        name = entry["name"]
        if entry["type"] == "dir":
            fetch_dir(entry["url"], os.path.join(local_dir, name), depth + 1)
        elif entry["type"] == "file":
            download_file(entry["download_url"], os.path.join(local_dir, name))


def main():
    if len(sys.argv) != 4:
        print("Usage: install-spice.py <extensions|applets> <UUID> <dest_root_dir>", file=sys.stderr)
        sys.exit(2)

    kind, uuid, dest_root = sys.argv[1], sys.argv[2], sys.argv[3]
    if kind not in REPO:
        print(f"Unknown kind '{kind}' (expected 'extensions' or 'applets')", file=sys.stderr)
        sys.exit(2)

    # Spice repo layout is UUID/files/UUID/<actual content> — see the
    # repos' own README for why (keeps the zip Cinnamon downloads clean).
    api_url = f"https://api.github.com/repos/{REPO[kind]}/contents/{uuid}/files/{uuid}"
    local_dir = os.path.join(dest_root, uuid)

    try:
        fetch_dir(api_url, local_dir)
    except urllib.error.HTTPError as e:
        print(f"HTTP error fetching {uuid}: {e.code} {e.reason}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Failed to fetch {uuid}: {e}", file=sys.stderr)
        sys.exit(1)

    if not os.path.isdir(local_dir) or not os.listdir(local_dir):
        print(f"Fetched nothing for {uuid} — dest dir is empty.", file=sys.stderr)
        sys.exit(1)

    print("OK")


if __name__ == "__main__":
    main()
