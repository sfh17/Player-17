#!/usr/bin/env python3
"""Writes python3-requirements.json for the Flatpak build.

It takes ready-made wheels from PyPI (nothing is compiled), for the Python version
that is inside the GNOME SDK, and records their download address and checksum,
as Flathub wants. Run it from anywhere:

    python3 packaging/flatpak/make-python-modules.py

aubio (BPM analysis) is left out for now: it has no ready wheel and must be compiled.
The player works without it (BPM comes from the tags, or 120).
"""
import json
import subprocess
import sys
import urllib.request
from pathlib import Path

PACKAGES = ["numpy", "mutagen", "pedalboard"]   # pedalboard needs numpy
SDK = "org.gnome.Sdk//50"
HERE = Path(__file__).resolve().parent


def sdk_python():
    """The Python version inside the SDK, e.g. (3, 13)."""
    out = subprocess.run(
        ["flatpak", "run", "--command=python3", SDK, "-c",
         "import sys; print('%d %d' % sys.version_info[:2])"],
        capture_output=True, text=True, check=True,
    ).stdout.split()
    return int(out[0]), int(out[1])


def pick_wheel(files, tag):
    """The wheel for this Python on 64-bit Linux, or a pure-Python one."""
    best = None
    for f in files:
        name = f["filename"]
        if f["packagetype"] != "bdist_wheel" or f.get("yanked"):
            continue
        if name.endswith("-py3-none-any.whl") or "-py2.py3-none-any.whl" in name:
            best = best or f
            continue
        if "x86_64" not in name or "musllinux" in name:
            continue
        if ("manylinux" in name) and (f"-{tag}-{tag}-" in name or f"-{tag}-abi3-" in name
                                       or ("-abi3-" in name and "-cp3" in name)):
            return f
    return best


def main():
    major, minor = sdk_python()
    tag = f"cp{major}{minor}"
    print(f"Python inside {SDK}: {major}.{minor}")
    sources = []
    for package in PACKAGES:
        with urllib.request.urlopen(f"https://pypi.org/pypi/{package}/json", timeout=30) as resp:
            data = json.load(resp)
        version = data["info"]["version"]
        wheel = pick_wheel(data["urls"], tag)
        if wheel is None:
            sys.exit(f"No ready wheel of {package} {version} for Python {major}.{minor} on x86_64")
        print(f"  {package} {version}: {wheel['filename']}")
        sources.append({"type": "file", "url": wheel["url"], "sha256": wheel["digests"]["sha256"]})

    module = {
        "name": "python3-requirements",
        "buildsystem": "simple",
        "build-commands": [
            "pip3 install --verbose --exists-action=i --no-index --find-links=\"file://${PWD}\" "
            "--prefix=${FLATPAK_DEST} --no-build-isolation --no-deps " + " ".join(PACKAGES)
        ],
        "sources": sources,
    }
    target = HERE / "python3-requirements.json"
    target.write_text(json.dumps(module, indent=4) + "\n")
    print(f"Written: {target}")


if __name__ == "__main__":
    main()
