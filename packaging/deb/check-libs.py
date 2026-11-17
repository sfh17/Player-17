#!/usr/bin/env python3
"""Build check: every system library the package's compiled parts (.so) need must either be
inside the package, be part of every Linux system, or be listed in the package's dependencies.

Why: pedalboard needs libatomic.so.1. Ubuntu / Zorin have it anyway, a clean Fedora does not,
and VST3 silently disappeared there. Now such a library stops the build here, with the line to
add, instead of turning up on users' computers.

    check-libs.py <package folder>
"""
import os
import subprocess
import sys

# On every system that can run the app (glibc, the C++ runtime, zlib under GTK itself)
ALWAYS = {
    "libc.so.6", "libm.so.6", "libpthread.so.0", "librt.so.1", "libdl.so.2", "libutil.so.1",
    "ld-linux-x86-64.so.2", "ld-linux-aarch64.so.1", "libstdc++.so.6", "libgcc_s.so.1",
    "libz.so.1",
}
# Libraries the package declares as dependencies: deb / rpm / Arch name.
# A new one: add it here AND to Depends / Requires / depends in build.sh.
DECLARED = {
    "libatomic.so.1": ("libatomic1", "libatomic", "gcc-libs"),
}


def needed(path):
    out = subprocess.run(["readelf", "-d", path], capture_output=True, text=True).stdout
    return [l.split("[", 1)[1].rstrip("]") for l in out.splitlines() if "(NEEDED)" in l and "[" in l]


def main(root):
    sos, names = [], set()
    for d, _dirs, files in os.walk(root):
        for f in files:
            p = os.path.join(d, f)
            if (".so" in f) and not os.path.islink(p):
                with open(p, "rb") as fh:
                    if fh.read(4) != b"\x7fELF":
                        continue
                sos.append(p)
                names.add(f)
    missing = {}
    for so in sos:
        for lib in needed(so):
            if lib in ALWAYS or lib in DECLARED or lib in names:
                continue
            missing.setdefault(lib, []).append(os.path.relpath(so, root))
    if missing:
        print("\n!! System libraries the package needs but does not declare:")
        for lib, users in sorted(missing.items()):
            print(f"   {lib}   (needed by {users[0]}{' and more' if len(users) > 1 else ''})")
        print("   Add each one to DECLARED in packaging/check-libs.py and to the dependencies\n"
              "   (Depends / Requires / depends) in the build script, then build again.\n")
        return 1
    print(f"libraries: OK ({len(sos)} compiled files checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
