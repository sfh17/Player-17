#!/usr/bin/env python3
"""Builds libp17dsp.so (the Plugins 17 sound core) from the C code kept inside app.py.
Used while building the Flatpak: the runtime has no compiler, so the library comes ready.

    python3 build-p17dsp.py app.py /app/lib/player-17/libp17dsp.so
"""
import ast
import subprocess
import sys
import tempfile
from pathlib import Path

source, target = sys.argv[1], Path(sys.argv[2])
tree = ast.parse(Path(source).read_text(encoding="utf-8"))
code = next((node.value.value for node in tree.body if isinstance(node, ast.Assign)
             and getattr(node.targets[0], "id", "") == "P17DSP_C"), None)
if code is None:
    sys.exit(f"P17DSP_C not found in {source}")
target.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory() as tmp:
    c_file = Path(tmp) / "p17dsp.c"
    c_file.write_text(code)
    subprocess.run(["gcc", "-O2", "-shared", "-fPIC", "-o", str(target), str(c_file), "-lm"], check=True)
print("built", target)
