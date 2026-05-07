#!/usr/bin/env python3
"""
为每幅画作生成深度图（color-based heuristic），存入 thumbnails.js 的 window.DEPTHS。
无需任何ML依赖，纯Pillow实现。

原理：
- Aerial perspective: 冷色调/低对比度 = 远处，暖色调/高细节 = 近处
- 亮度加权 + 饱和度加权 + 边缘密度 → 合成深度图
- 输出64x64灰度PNG → base64嵌入

用法: python scripts/estimate_depth.py
"""
import base64, json, os
from PIL import Image, ImageFilter

PAINT_DIR = os.path.join("entry", "src", "main", "resources", "rawfile", "gltf", "David", "paintings")
OUT_PATH = os.path.join("entry", "src", "main", "resources", "rawfile", "web", "js", "depth_data.js")

ARTWORK_MAP = {
    "mona_lisa": "mona_lisa.jpg",
    "birth_of_venus": "birth_of_venus.jpg",
    "school_of_athens": "school_of_athens.jpg",
    "creation_of_adam": "creation_of_adam.jpg",
    "primavera": "botticelli_primavera.jpg",
    "last_supper": "leonardo_last_supper.jpg",
    "virgin_of_the_rocks": "virgin_of_the_rocks.jpg",
    "venus_of_urbino": "venus_of_urbino.jpg",
    "sistine_madonna": "raphael_sistine_madonna.jpg",
    "last_judgment": "michelangelo_last_judgment.jpg",
    "masaccio_trinity": "masaccio_trinity.jpg",
    "uccello_san_romano": "uccello_san_romano.jpg",
}

SIZE = 64  # depth map resolution

def estimate_depth(img: Image.Image) -> Image.Image:
    """Color-heuristic depth estimation. Returns L-mode grayscale depth map."""
    img = img.convert('RGB')
    w, h = img.size

    # Resize to working size
    work = img.resize((SIZE*4, SIZE*4), Image.LANCZOS)
    work_arr = list(work.getdata())

    # Edge density (high detail = closer)
    edges = work.filter(ImageFilter.FIND_EDGES).convert('L')
    edge_arr = list(edges.getdata())

    depth = []
    for i, (r, g, b) in enumerate(work_arr):
        # Warmth: red vs blue ratio → warm things feel closer
        warmth = max(0, (r - b) / max(r + b + 1, 1))
        # Brightness: brighter = closer (aerial perspective reverses this, but works for paintings)
        brightness = (r + g + b) / 765.0
        # Edge density from precomputed edges
        edge = edge_arr[i] / 255.0
        # Composite: warmth 40% + brightness 30% + edge 30%
        d = warmth * 0.4 + brightness * 0.3 + edge * 0.3
        # Clamp and invert slightly for artistic depth
        d = max(0.0, min(1.0, d * 1.2))
        depth.append(int(d * 255))

    depth_img = Image.new('L', (SIZE*4, SIZE*4))
    depth_img.putdata(depth)
    # Gaussian blur for smooth transitions
    depth_img = depth_img.filter(ImageFilter.GaussianBlur(radius=SIZE//8))
    # Resize down to target
    depth_img = depth_img.resize((SIZE, SIZE), Image.LANCZOS)
    return depth_img


def main():
    depths = {}
    for art_id, filename in ARTWORK_MAP.items():
        path = os.path.join(PAINT_DIR, filename)
        if not os.path.exists(path):
            print(f"  SKIP {art_id}: not found")
            continue
        img = Image.open(path)
        depth_img = estimate_depth(img)
        # Encode as base64 PNG
        import io
        buf = io.BytesIO()
        depth_img.save(buf, format='PNG')
        b64 = base64.b64encode(buf.getvalue()).decode('ascii')
        depths[art_id] = f"data:image/png;base64,{b64}"
        print(f"  {art_id}: depth map {SIZE}x{SIZE} ({len(b64)} chars)")

    js = "window.DEPTHS = " + json.dumps(depths) + ";"
    with open(OUT_PATH, "w") as f:
        f.write(js)
    print(f"\nWrote {OUT_PATH} ({len(js):,} bytes)")

if __name__ == '__main__':
    main()
