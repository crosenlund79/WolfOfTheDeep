"""Shrink the rendered plates for the repository/build.

Plates: progressive JPEG q88. Masks: half resolution (they are soft edges and
are sampled with filtering), PNG.
Run:  python3 tools/interior/compress_plates.py assets/interior/control_room
"""
import glob
import os
import sys

from PIL import Image

d = sys.argv[1]
for f in glob.glob(os.path.join(d, "*_normal.jpg")) + glob.glob(os.path.join(d, "*_red.jpg")):
    im = Image.open(f).convert("RGB")
    im.save(f, "JPEG", quality=88, progressive=True, optimize=True)
    print("plate", os.path.basename(f), os.path.getsize(f) // 1024, "KB")
for f in glob.glob(os.path.join(d, "*_mask*.png")):
    im = Image.open(f).convert("RGB")
    im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
    im.save(f, optimize=True)
    print("mask", os.path.basename(f), os.path.getsize(f) // 1024, "KB")
