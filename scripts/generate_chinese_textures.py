"""Generate procedural textures for Chinese gallery."""
from PIL import Image, ImageDraw, ImageFilter
import random
import os

OUT = os.path.join(os.path.dirname(__file__), '..',
    'entry/src/main/resources/rawfile/gltf/chinese_gallery/textures')

def gen_floor_stone(size=256):
    """Warm gray stone tile with subtle grain."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            gray = 130 + int(random.gauss(0, 8))
            # Subtle tile grid lines every 64px
            if x % 64 < 2 or y % 64 < 2:
                gray = max(80, gray - 20)
            gray = max(0, min(255, gray))
            pixels[x, y] = (gray, gray - 2, gray - 6, 255)
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    return img

def gen_wall_plaster(size=256):
    """Warm cream plaster with fine texture."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            r = 245 + int(random.gauss(0, 3))
            g = 240 + int(random.gauss(0, 3))
            b = 232 + int(random.gauss(0, 3))
            pixels[x, y] = (
                max(0, min(255, r)),
                max(0, min(255, g)),
                max(0, min(255, b)),
                255
            )
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    return img

def gen_wood_beam(size=256):
    """Dark brown wood grain."""
    img = Image.new('RGBA', (size, 256), (0, 0, 0, 0))
    pixels = img.load()
    # Wood base
    for y in range(256):
        for x in range(size):
            r = 80 + int(random.gauss(0, 5))
            g = 55 + int(random.gauss(0, 4))
            b = 30 + int(random.gauss(0, 3))
            # Grain lines
            if y % 12 < 1:
                r = max(40, r - 15)
                g = max(20, g - 12)
                b = max(10, b - 10)
            pixels[x, y] = (
                max(0, min(255, r)),
                max(0, min(255, g)),
                max(0, min(255, b)),
                255
            )
    return img

def gen_roof_tile(size=256):
    """Dark gray roof tile with subtle ridges."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            g = 74 + int(random.gauss(0, 4))
            # Ridges every 16px
            if y % 16 < 2:
                g = max(50, g - 10)
            pixels[x, y] = (g, g, g, 255)
    return img

def gen_lattice_window(size=256):
    """Dark wood lattice with transparent gaps."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            # Cross-hatch pattern
            bar_w = 12
            in_vbar = (x % 64) < bar_w
            in_hbar = (y % 48) < bar_w
            if in_vbar or in_hbar:
                pixels[x, y] = (50, 35, 18, 255)
            else:
                pixels[x, y] = (0, 0, 0, 0)  # transparent
    return img

def main():
    os.makedirs(OUT, exist_ok=True)
    textures = {
        'floor_stone.png': gen_floor_stone,
        'wall_plaster.png': gen_wall_plaster,
        'wood_beam.png': gen_wood_beam,
        'roof_tile.png': gen_roof_tile,
        'lattice_window.png': gen_lattice_window,
    }
    for fname, gen in textures.items():
        path = os.path.join(OUT, fname)
        img = gen()
        img.save(path, 'PNG')
        print(f"  {fname} ({img.width}x{img.height}) → {path}")

if __name__ == '__main__':
    main()
