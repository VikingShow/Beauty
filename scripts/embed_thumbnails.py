#!/usr/bin/env python3
"""将 David 场景的画作 JPEG 编码为 base64，输出 JS 文件供 Web 端使用"""
import base64, json, os

PAINT_DIR = os.path.join("entry", "src", "main", "resources", "rawfile", "gltf", "David", "paintings")
OUT_PATH = os.path.join("entry", "src", "main", "resources", "rawfile", "web", "js", "thumbnails.js")

# Map artwork IDs to painting filenames (can omit .jpg extension)
ARTWORK_MAP = {
    "mona_lisa": "mona_lisa.jpg",
    "birth_of_venus": "birth_of_venus.jpg",
    "school_of_athens": "school_of_athens.jpg",
    "creation_of_adam": "creation_of_adam.jpg",
    "primavera": "botticelli_primavera.jpg",
    "starry_night": "birth_of_venus.jpg",  # fallback for starry_night
}

thumbs = {}
for art_id, filename in ARTWORK_MAP.items():
    path = os.path.join(PAINT_DIR, filename)
    if os.path.exists(path):
        with open(path, "rb") as f:
            data = f.read()
        b64 = base64.b64encode(data).decode("ascii")
        thumbs[art_id] = f"data:image/jpeg;base64,{b64}"
        print(f"  {art_id}: {filename} ({len(data):,} bytes)")
    else:
        print(f"  SKIP {art_id}: {filename} not found")

js = "window.THUMBS = " + json.dumps(thumbs) + ";"
with open(OUT_PATH, "w") as f:
    f.write(js)
print(f"\nWrote {OUT_PATH} ({len(js):,} bytes)")
