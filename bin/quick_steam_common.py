"""What quick-steam-library and quick-steam-watch both need: finding Steam,
reading its text VDF files, and listing its library folders.

Every file is treated as untrusted input: sizes are capped and a file that
fails to parse reads as empty instead of failing the caller.
"""

import os
import re

MAX_TEXT = 64 * 1024 * 1024
APPID = re.compile(r"^[0-9]{1,10}$")


def steam_root():
    home = os.path.expanduser("~")
    for candidate in (
        os.path.join(home, ".steam/root"),
        os.path.join(home, ".local/share/Steam"),
        os.path.join(home, ".var/app/com.valvesoftware.Steam/.local/share/Steam"),
    ):
        if os.path.isfile(os.path.join(candidate, "config/config.vdf")):
            return os.path.realpath(candidate)
    return None


def read_file(path, limit):
    try:
        if os.path.getsize(path) > limit:
            return None
        with open(path, "rb") as handle:
            return handle.read()
    except OSError:
        return None


# ---- Text VDF ---------------------------------------------------------------

TOKEN = re.compile(r'"((?:[^"\\]|\\.)*)"|([{}])|(//[^\n]*)|\s+', re.S)


def parse_text_vdf(text):
    """Nested dicts; later duplicate keys win. Keys keep their original case."""
    root, stack, key = {}, [], None
    current = root
    for match in TOKEN.finditer(text):
        string, brace, comment = match.groups()
        if comment is not None or (string is None and brace is None):
            continue
        if brace == "{":
            child = {}
            if key is not None:
                current[key] = child
            stack.append(current)
            current, key = child, None
        elif brace == "}":
            current = stack.pop() if stack else root
            key = None
        elif key is None:
            key = string.replace('\\"', '"').replace("\\\\", "\\")
        else:
            current[key] = string.replace('\\"', '"').replace("\\\\", "\\")
            key = None
    return root


def load_text_vdf(path):
    data = read_file(path, MAX_TEXT)
    if data is None:
        return {}
    try:
        return parse_text_vdf(data.decode("utf-8", "replace"))
    except (IndexError, ValueError):
        return {}


def child(node, *names):
    """Case-insensitive descent through nested dicts."""
    for name in names:
        if not isinstance(node, dict):
            return {}
        lowered = name.lower()
        node = next((value for key, value in node.items() if key.lower() == lowered), {})
    return node


def as_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


# ---- Library folders -----------------------------------------------------------

def libraries(root):
    """Every Steam library folder, the Steam root first, with a short label,
    its index in libraryfolders.vdf (the volume index Steam's app_install
    takes, -1 when the file does not list it) and the free and total space of
    the disk it lives on."""
    found, seen = [], set()
    folders = load_text_vdf(os.path.join(root, "steamapps/libraryfolders.vdf"))
    entries = child(folders, "libraryfolders") or folders
    paths = [root] + [child(entry, "path") for entry in entries.values() if isinstance(entry, dict)]
    labels = {child(e, "path"): child(e, "label") for e in entries.values() if isinstance(e, dict)}
    indexes = {os.path.realpath(child(e, "path")): int(key) for key, e in entries.items()
               if isinstance(e, dict) and isinstance(child(e, "path"), str) and child(e, "path") and key.isdigit()}
    for path in paths:
        if not isinstance(path, str) or not path:
            continue
        real = os.path.realpath(path)
        if real in seen or not os.path.isdir(os.path.join(real, "steamapps")):
            continue
        seen.add(real)
        label = labels.get(path) if isinstance(labels.get(path), str) else ""
        if not label:
            mount = real
            while not os.path.ismount(mount) and mount != "/":
                mount = os.path.dirname(mount)
            label = "Steam" if real == root or mount == "/" else os.path.basename(mount)
        try:
            stats = os.statvfs(real)
            free, total = stats.f_bavail * stats.f_frsize, stats.f_blocks * stats.f_frsize
        except OSError:
            free = total = 0
        folder = indexes.get(real, 0 if real == root else -1)
        found.append({"path": real, "label": label, "folder": folder, "free": free, "total": total})
    return found
