"""
Generate stylized placeholder textures for 12 Chinese paintings.
Each placeholder matches the painting's aspect ratio and uses the
ChinesePaintingWorlds.ets color palette for an ink-wash aesthetic.
"""
from PIL import Image, ImageDraw, ImageFont
import os
import math

OUT_DIR = os.path.join(os.path.dirname(__file__), '..',
    'entry/src/main/resources/rawfile/gltf/chinese_gallery/paintings')

# From ChinesePaintingWorlds.ets — color themes
THEMES = {
    'qianli_jiangshan':   {'sky': '#4A7C59', 'ground': '#2D5A27', 'fog': '#8FBC8F', 'accent': '#FFD700'},
    'fuchun_shanju':      {'sky': '#C8D5C0', 'ground': '#8B7355', 'fog': '#B8C8B0', 'accent': '#2F2F2F'},
    'xishan_xinglv':      {'sky': '#D4C5A9', 'ground': '#6B5B3A', 'fog': '#A89880', 'accent': '#FFFFFF'},
    'xiao_xiang':         {'sky': '#B0C4DE', 'ground': '#5A7A5A', 'fog': '#87AFC0', 'accent': '#D2B48C'},
    'zaochun':            {'sky': '#E8D5B7', 'ground': '#8B6B4A', 'fog': '#D4C4A8', 'accent': '#90EE90'},
    'luoshen_fu':         {'sky': '#FFB6C1', 'ground': '#DDA0DD', 'fog': '#FFC0CB', 'accent': '#FFFFFF'},
    'hanxizai_yeyan':     {'sky': '#1A0A00', 'ground': '#3A1A00', 'fog': '#2A1000', 'accent': '#FFD700'},
    'zanhua_shinv':       {'sky': '#FFE4E1', 'ground': '#D4A574', 'fog': '#FFDAB9', 'accent': '#FF69B4'},
    'wuniu':              {'sky': '#87CEEB', 'ground': '#6B8E23', 'fog': '#98FB98', 'accent': '#8B4513'},
    'lushan_gao':         {'sky': '#4682B4', 'ground': '#2F4F2F', 'fog': '#708090', 'accent': '#FFFFFF'},
    'mo_putao':           {'sky': '#2F2F2F', 'ground': '#1A1A1A', 'fog': '#3A3A3A', 'accent': '#6B3FA0'},
    'bada_shanren_lotus': {'sky': '#D3D3D3', 'ground': '#2F4F4F', 'fog': '#A9A9A9', 'accent': '#FFFFFF'},
}

# Aspect ratios from ChineseExhibits.ets (width:height in cm)
ASPECTS = {
    'qianli_jiangshan':   (1191.5, 51.5),   # 23:1 handscroll
    'fuchun_shanju':      (636.9, 33.0),    # 19:1
    'xishan_xinglv':      (103.3, 206.3),   # 1:2 hanging
    'xiao_xiang':         (141.4, 50.0),    # 3:1
    'zaochun':            (108.1, 158.3),    # 2:3
    'luoshen_fu':         (572.8, 27.1),    # 21:1
    'hanxizai_yeyan':     (335.5, 28.7),    # 11:1
    'zanhua_shinv':       (180.0, 46.0),    # 4:1
    'wuniu':              (139.8, 20.8),    # 7:1
    'lushan_gao':         (98.1, 193.8),    # 1:2
    'mo_putao':           (64.5, 165.7),    # 1:2.5
    'bada_shanren_lotus': (76.0, 165.0),    # 1:2
}

TITLES = {
    'qianli_jiangshan':   '千里江山图',
    'fuchun_shanju':      '富春山居图',
    'xishan_xinglv':      '溪山行旅图',
    'xiao_xiang':         '潇湘图',
    'zaochun':            '早春图',
    'luoshen_fu':         '洛神赋图',
    'hanxizai_yeyan':     '韩熙载夜宴图',
    'zanhua_shinv':       '簪花仕女图',
    'wuniu':              '五牛图',
    'lushan_gao':         '庐山高图',
    'mo_putao':           '墨葡萄图',
    'bada_shanren_lotus': '荷花水鸟图',
}

ARTISTS = {
    'qianli_jiangshan': '王希孟 · 北宋',
    'fuchun_shanju': '黄公望 · 元代',
    'xishan_xinglv': '范宽 · 北宋',
    'xiao_xiang': '董源 · 五代',
    'zaochun': '郭熙 · 北宋',
    'luoshen_fu': '顾恺之 · 东晋',
    'hanxizai_yeyan': '顾闳中 · 五代',
    'zanhua_shinv': '周昉 · 唐代',
    'wuniu': '韩滉 · 唐代',
    'lushan_gao': '沈周 · 明代',
    'mo_putao': '徐渭 · 明代',
    'bada_shanren_lotus': '八大山人 · 清初',
}

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def generate(exhibit_id, theme, aspect, title, artist):
    tw, th = aspect
    ratio = tw / th

    # Determine image size based on aspect
    if ratio > 3:  # Horizontal handscroll — wide
        w, h = 2048, max(128, int(2048 / ratio))
    elif ratio > 1:  # Slightly horizontal
        w, h = 1024, max(256, int(1024 / ratio))
    else:  # Vertical hanging scroll
        h_img = 1536
        w = max(128, int(h_img * ratio))
        h = h_img

    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    sky = hex_to_rgb(theme['sky'])
    ground = hex_to_rgb(theme['ground'])
    fog = hex_to_rgb(theme['fog'])
    accent = hex_to_rgb(theme['accent'])

    # Ink wash gradient background
    for y in range(h):
        t = y / h
        r = int(sky[0] * (1-t) + ground[0] * t)
        g = int(sky[1] * (1-t) + ground[1] * t)
        b = int(sky[2] * (1-t) + ground[2] * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # Fog/mist bands (horizontal semi-transparent bands)
    for band_y, band_h, alpha in [
        (int(h*0.25), int(h*0.12), 80),
        (int(h*0.55), int(h*0.10), 60),
        (int(h*0.78), int(h*0.08), 50),
    ]:
        for dy in range(band_h):
            y = band_y + dy
            if 0 <= y < h:
                t = 1 - abs((dy - band_h/2) / (band_h/2))
                a = int(alpha * t)
                draw.line([(0, y), (w, y)], fill=(fog[0], fog[1], fog[2], a))

    # Mountain silhouette shapes (procedural)
    import random
    random.seed(hash(exhibit_id) % 2**32)
    for peak in range(random.randint(2, 5)):
        px = random.randint(w//6, 5*w//6)
        ph = random.randint(h//3, 2*h//3)
        pw = random.randint(w//8, w//3)
        # Draw a simple triangle mountain
        mt_color = (ground[0]-20, ground[1]-20, ground[2]-20, 200)
        for dx in range(-pw, pw+1):
            x = px + dx
            if 0 <= x < w:
                peak_h = int(ph * (1 - abs(dx/pw)) * 0.8 + ph * 0.2)
                draw.line([(x, h), (x, h-peak_h)], fill=mt_color)

    # Accent seal (stamp) in top-left
    seal_size = min(w, h) // 8
    draw.rectangle(
        [w - seal_size - 20, 12, w - 12, seal_size + 12],
        outline=accent, width=3
    )
    # Simple character in seal
    try:
        font_large = ImageFont.truetype("simsun.ttc", size=min(w, h) // 12)
    except:
        font_large = ImageFont.load_default()

    # Title text centered
    try:
        font_title = ImageFont.truetype("simsun.ttc", size=min(w, h) // 10)
    except:
        font_title = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), title, font=font_title)
    tw_text = bbox[2] - bbox[0]
    draw.text((w//2 - tw_text//2, h//2 - 30), title,
              fill=accent + (220,), font=font_title)

    # Artist attribution
    try:
        font_artist = ImageFont.truetype("simsun.ttc", size=min(w, h) // 18)
    except:
        font_artist = ImageFont.load_default()
    bbox2 = draw.textbbox((0, 0), artist, font=font_artist)
    ta_w = bbox2[2] - bbox2[0]
    draw.text((w//2 - ta_w//2, h//2 + 10), artist,
              fill=(fog[0], fog[1], fog[2], 180), font=font_artist)

    # Silk border (narrow band on edges)
    border = 3
    for bx in range(border):
        draw.line([(0, bx), (w, bx)], fill=accent + (40,))
        draw.line([(0, h-1-bx), (w, h-1-bx)], fill=accent + (40,))
        draw.line([(bx, 0), (bx, h)], fill=accent + (40,))
        draw.line([(w-1-bx, 0), (w-1-bx, h)], fill=accent + (40,))

    out_path = os.path.join(OUT_DIR, f"{exhibit_id}.jpg")
    # Convert to RGB for JPEG
    img_rgb = Image.new('RGB', (w, h), (255, 255, 255))
    img_rgb.paste(img, mask=img.split()[3])
    img_rgb.save(out_path, 'JPEG', quality=85)
    print(f"  {exhibit_id}: {w}x{h} -> {out_path}")

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for eid in THEMES:
        generate(eid, THEMES[eid], ASPECTS[eid], TITLES[eid], ARTISTS[eid])
    print(f"\nGenerated {len(THEMES)} painting placeholders")

if __name__ == '__main__':
    main()
