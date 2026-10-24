"""Make a still (the first frame) of the homepage's Left Hero Media gif.

Used by the "Left photo: play animation" switch in Pages CMS: when it's off,
the homepage shows this still instead of the gif, so it loads fast and the
mouth doesn't move (the cursor-following eyes still work on top of it).
Runs in the deploy workflow right before Jekyll builds. The file it writes is
not committed (see .gitignore).
"""
import os

import yaml
from PIL import Image

OUT = "assets/images/generated/hero-left-still.jpg"

home = yaml.safe_load(open("_data/home.yml", encoding="utf-8")) or {}
src = str(home.get("hero_left") or "").lstrip("/")

if src.lower().endswith(".gif") and os.path.exists(src):
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im = Image.open(src)
    im.seek(0)
    im.convert("RGB").save(OUT, "JPEG", quality=90, optimize=True, progressive=True)
    print(f"Wrote {OUT} from the first frame of {src}")
else:
    print(f"Left Hero Media is not a gif ({src or 'not set'}), no still needed")
