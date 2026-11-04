#!/usr/bin/env python3
"""Turns renders (SRC/<char>_<tier>.webp) into app assets:
  assets/images/characters/<char>_<tier>.jpg       full body, 720x1080
  assets/images/characters/<char>_<tier>_face.jpg  square portrait, 320x320
Face position: detected as the topmost skin-toned blob near the figure, with
per-image overrides in faces.json ({"<char>_<tier>": [cx, cy, side]} as fractions)."""
import json, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = sys.argv[1]
OUT = os.path.join(ROOT, 'assets', 'images', 'characters')
WEB = os.path.join(ROOT, 'web', 'public', 'images', 'characters')
OVR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'faces.json')
os.makedirs(OUT, exist_ok=True)
os.makedirs(WEB, exist_ok=True)
over = json.load(open(OVR)) if os.path.exists(OVR) else {}


def skin(p):
    r, g, b = p[:3]
    return r > 60 and g > 30 and b > 15 and r > g > b and (r - b) > 25 and (r - g) < 90 and max(r, g, b) - min(r, g, b) > 15


def find_face(im):
    w, h = im.size
    small = im.resize((96, 144))
    px = small.load()
    rows = []
    for y in range(4, 70):
        xs = [x for x in range(20, 76) if skin(px[x, y])]
        if len(xs) >= 4:
            rows.append((y, sum(xs) / len(xs), len(xs)))
    if not rows:
        return 0.5, 0.17, 0.3
    top = rows[0][0]
    face = [r for r in rows if r[0] <= top + 22]
    cx = sum(r[1] for r in face) / len(face) / 96
    cy = (top + 11) / 144
    return cx, cy, 0.3


for f in sorted(os.listdir(SRC)):
    if not f.endswith('.webp') or os.path.getsize(os.path.join(SRC, f)) < 10000:
        continue
    name = f[:-5]
    im = Image.open(os.path.join(SRC, f)).convert('RGB')
    full = im.resize((720, 1080), Image.LANCZOS)
    for d in (OUT, WEB):
        full.save(os.path.join(d, f'{name}.jpg'), 'JPEG', quality=80, optimize=True, progressive=True)
    w, h = im.size
    cx, cy, side = over.get(name, find_face(im))
    s = side * w
    box = (int(cx * w - s / 2), int(cy * h - s / 2), int(cx * w + s / 2), int(cy * h + s / 2))
    face = im.crop(box).resize((320, 320), Image.LANCZOS)
    for d in (OUT, WEB):
        face.save(os.path.join(d, f'{name}_face.jpg'), 'JPEG', quality=84, optimize=True)
    print(name, [round(v, 3) for v in (cx, cy, side)])
