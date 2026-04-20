#!/usr/bin/env python3
"""
生成 3 个相连展厅的 glTF + 程序化 PBR 纹理。
- 总占地 25m × 35m × 12m（高），含 3 间展厅 + 2 道带门洞的内墙
- 地板：暖米色大理石瓷砖
- 墙面：浅灰白涂料
- 天花板：纯白漫反射
- 单 .gltf + 3 张 PNG，buffer base64 内嵌

布局（俯视）：
   北 (-Z)
   ┌──────────────────────────────┐
   │       R1 (北厅) 25×10        │
   ├══◇══════════════════◇═══════┤   ← 内墙 1 (z=-7.5) + 2 个门洞
   │                              │
   │     R2 (中央大厅) 25×15       │
   │                              │
   ├══◇══════════════════◇═══════┤   ← 内墙 2 (z=+7.5)
   │       R3 (南厅) 25×10        │
   └──────────────────────────────┘
   南 (+Z)

用法：
    python scripts/generate_gallery.py
"""
import base64
import json
import math
import os
import random
import struct
from PIL import Image, ImageDraw

# ==================== 房间参数 ====================
WIDTH = 25.0   # X：东西
HEIGHT = 12.0  # Y：层高
DEPTH = 35.0   # Z：南北

INTERNAL_WALL_ZS = [-7.5, 7.5]
DOORWAY_X_CENTERS = [-5.0, 5.0]   # 每道内墙 2 个门洞
DOORWAY_WIDTH = 4.0
DOORWAY_HEIGHT = 5.0

OUT_DIR = os.path.join("entry", "src", "main", "resources", "rawfile", "gltf", "gallery")
TEX_DIR = os.path.join(OUT_DIR, "textures")

random.seed(42)

# ==================== 纹理生成 ====================

def make_marble_tile(size: int = 256) -> Image.Image:
    """深色大理石瓷砖：明显的瓷砖效果，墨灰底色 + 粗石纹 + 较深灰缝。"""
    base = (155, 152, 148)  # 较深的暖灰色
    img = Image.new('RGB', (size, size), base)
    pixels = img.load()
    # 底色噪点
    for x in range(size):
        for y in range(size):
            n = random.randint(-12, 12)
            r, g, b = pixels[x, y]
            pixels[x, y] = (
                max(0, min(255, r + n)),
                max(0, min(255, g + n)),
                max(0, min(255, b + n))
            )
    # 多条明显石纹
    for _ in range(6):
        start_x = random.randint(0, size)
        start_y = random.randint(0, size)
        dx = random.uniform(-0.5, 0.5)
        for step in range(size):
            t = step / size
            x = int(start_x + t * size * dx + math.sin(t * 7) * 14)
            y = int(start_y + t * size * random.uniform(0.5, 1.0))
            for ddx in range(-1, 2):
                for ddy in range(-1, 2):
                    nx, ny = x + ddx, y + ddy
                    if 0 <= nx < size and 0 <= ny < size:
                        pixels[nx, ny] = (115, 112, 108)
    # 加几个高光斑驳，增加质感
    for _ in range(20):
        cx = random.randint(20, size - 20)
        cy = random.randint(20, size - 20)
        for dx in range(-12, 13):
            for dy in range(-12, 13):
                d2 = dx * dx + dy * dy
                if d2 < 144:
                    falloff = 1 - d2 / 144
                    r, g, b = pixels[cx + dx, cy + dy]
                    boost = int(15 * falloff)
                    pixels[cx + dx, cy + dy] = (
                        min(255, r + boost),
                        min(255, g + boost),
                        min(255, b + boost)
                    )
    # 深灰缝边框（明显的瓷砖感）
    EDGE = 5
    grout = (75, 72, 68)
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, size - 1, EDGE - 1], fill=grout)
    draw.rectangle([0, size - EDGE, size - 1, size - 1], fill=grout)
    draw.rectangle([0, 0, EDGE - 1, size - 1], fill=grout)
    draw.rectangle([size - EDGE, 0, size - 1, size - 1], fill=grout)
    return img

def make_wall(size: int = 256) -> Image.Image:
    """美术馆白墙：明亮纯净的白色 + 极细颗粒 + 偶尔的纹理纵纹（仿石膏拉花）。"""
    base = (242, 240, 235)  # 明亮的米白
    img = Image.new('RGB', (size, size), base)
    pixels = img.load()
    for x in range(size):
        for y in range(size):
            # 主噪点
            n = random.randint(-5, 5)
            # 加一点垂直方向的微弱拉花纹理
            stripe = int(math.sin(x * 0.4) * 2 + math.sin(x * 1.3 + y * 0.02) * 1.5)
            r, g, b = pixels[x, y]
            pixels[x, y] = (
                max(0, min(255, r + n + stripe)),
                max(0, min(255, g + n + stripe)),
                max(0, min(255, b + n + stripe))
            )
    return img

def make_ceiling(size: int = 256) -> Image.Image:
    """天花板：略灰白 + 隐约的方格分割（仿吊顶板）。"""
    base = (215, 215, 218)  # 略偏冷灰白，与墙明显区分
    img = Image.new('RGB', (size, size), base)
    pixels = img.load()
    for x in range(size):
        for y in range(size):
            n = random.randint(-4, 4)
            r, g, b = pixels[x, y]
            pixels[x, y] = (
                max(0, min(255, r + n)),
                max(0, min(255, g + n)),
                max(0, min(255, b + n))
            )
    # 方格分割线（吊顶感）
    grid_color = (185, 185, 188)
    draw = ImageDraw.Draw(img)
    half = size // 2
    draw.line([(half, 0), (half, size)], fill=grid_color, width=2)
    draw.line([(0, half), (size, half)], fill=grid_color, width=2)
    return img

# ==================== 几何 ====================

W, H, D = WIDTH, HEIGHT, DEPTH
HW, HD = W / 2.0, D / 2.0

# 材质索引
MAT_FLOOR = 0
MAT_CEILING = 1
MAT_WALL = 2

# 每米对应的 UV 重复倍数（值越大，纹理越密）
UV_PER_M_FLOOR = 1.0 / 1.2    # 每 1.2m 一块瓷砖（更密集，瓷砖感更强）
UV_PER_M_WALL = 1.0 / 4.0     # 墙 4m 一段
UV_PER_M_CEILING = 1.0 / 3.0  # 天花板 3m 一格（吊顶分割线明显）

# faces: list of (positions[4], normal, material_idx, uv_repeat_u, uv_repeat_v)
# 顶点顺序对应 UV [0,0],[1,0],[1,1],[0,1]
faces: list = []

def add_face(positions, normal, material_idx, uv_extent_u_m, uv_extent_v_m):
    if material_idx == MAT_FLOOR:
        repeat = UV_PER_M_FLOOR
    elif material_idx == MAT_CEILING:
        repeat = UV_PER_M_CEILING
    else:
        repeat = UV_PER_M_WALL
    faces.append((positions, normal,
                  uv_extent_u_m * repeat, uv_extent_v_m * repeat,
                  material_idx))

# === 地板（连续穿过 3 间房）===
add_face(
    [(-HW, 0, HD), (HW, 0, HD), (HW, 0, -HD), (-HW, 0, -HD)],
    (0.0, 1.0, 0.0),
    MAT_FLOOR,
    W, D
)

# === 天花板 ===
add_face(
    [(-HW, H, -HD), (HW, H, -HD), (HW, H, HD), (-HW, H, HD)],
    (0.0, -1.0, 0.0),
    MAT_CEILING,
    W, D
)

# === 4 面外墙 ===
# 北墙 z=-HD（法线 +Z）
add_face(
    [(-HW, 0, -HD), (HW, 0, -HD), (HW, H, -HD), (-HW, H, -HD)],
    (0.0, 0.0, 1.0),
    MAT_WALL, W, H
)
# 南墙 z=+HD（法线 -Z）
add_face(
    [(HW, 0, HD), (-HW, 0, HD), (-HW, H, HD), (HW, H, HD)],
    (0.0, 0.0, -1.0),
    MAT_WALL, W, H
)
# 东墙 x=+HW（法线 -X）
add_face(
    [(HW, 0, HD), (HW, 0, -HD), (HW, H, -HD), (HW, H, HD)],
    (-1.0, 0.0, 0.0),
    MAT_WALL, D, H
)
# 西墙 x=-HW（法线 +X）
add_face(
    [(-HW, 0, -HD), (-HW, 0, HD), (-HW, H, HD), (-HW, H, -HD)],
    (1.0, 0.0, 0.0),
    MAT_WALL, D, H
)

# === 内墙：每道墙包含 5 段（左 / 门洞1上方过梁 / 中 / 门洞2上方过梁 / 右）===
def add_internal_wall(z_pos: float):
    # 计算门洞水平区间
    door1_x_left = DOORWAY_X_CENTERS[0] - DOORWAY_WIDTH / 2
    door1_x_right = DOORWAY_X_CENTERS[0] + DOORWAY_WIDTH / 2
    door2_x_left = DOORWAY_X_CENTERS[1] - DOORWAY_WIDTH / 2
    door2_x_right = DOORWAY_X_CENTERS[1] + DOORWAY_WIDTH / 2

    # 法线统一指向 +Z（doubleSided 材质两面都渲染）
    n = (0.0, 0.0, 1.0)

    # 左段（从西外墙到 door1_x_left，全高）
    if door1_x_left > -HW:
        seg_w = door1_x_left - (-HW)
        add_face(
            [(-HW, 0, z_pos), (door1_x_left, 0, z_pos), (door1_x_left, H, z_pos), (-HW, H, z_pos)],
            n, MAT_WALL, seg_w, H
        )

    # 门洞 1 上方过梁
    add_face(
        [(door1_x_left, DOORWAY_HEIGHT, z_pos), (door1_x_right, DOORWAY_HEIGHT, z_pos),
         (door1_x_right, H, z_pos), (door1_x_left, H, z_pos)],
        n, MAT_WALL, DOORWAY_WIDTH, H - DOORWAY_HEIGHT
    )

    # 中段
    if door2_x_left > door1_x_right:
        seg_w = door2_x_left - door1_x_right
        add_face(
            [(door1_x_right, 0, z_pos), (door2_x_left, 0, z_pos),
             (door2_x_left, H, z_pos), (door1_x_right, H, z_pos)],
            n, MAT_WALL, seg_w, H
        )

    # 门洞 2 上方过梁
    add_face(
        [(door2_x_left, DOORWAY_HEIGHT, z_pos), (door2_x_right, DOORWAY_HEIGHT, z_pos),
         (door2_x_right, H, z_pos), (door2_x_left, H, z_pos)],
        n, MAT_WALL, DOORWAY_WIDTH, H - DOORWAY_HEIGHT
    )

    # 右段（从 door2_x_right 到东外墙）
    if door2_x_right < HW:
        seg_w = HW - door2_x_right
        add_face(
            [(door2_x_right, 0, z_pos), (HW, 0, z_pos), (HW, H, z_pos), (door2_x_right, H, z_pos)],
            n, MAT_WALL, seg_w, H
        )

for z in INTERNAL_WALL_ZS:
    add_internal_wall(z)

# ==================== 转换为 buffer ====================

positions: list[float] = []
normals: list[float] = []
uvs: list[float] = []
indices_by_material: dict[int, list[int]] = {MAT_FLOOR: [], MAT_CEILING: [], MAT_WALL: []}

vertex_count = 0
for verts4, normal, uv_u, uv_v, mat in faces:
    base = vertex_count
    for vx, vy, vz in verts4:
        positions.extend([vx, vy, vz])
    for _ in range(4):
        normals.extend(list(normal))
    for u, v in [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]:
        uvs.extend([u * uv_u, v * uv_v])
    indices_by_material[mat].extend([base, base + 1, base + 2, base, base + 2, base + 3])
    vertex_count += 4

# 按 primitive（material）顺序拼接 indices
all_indices: list[int] = []
primitive_index_ranges: list[tuple[int, int, int]] = []  # (offset, count, mat)
for mat in [MAT_FLOOR, MAT_CEILING, MAT_WALL]:
    start = len(all_indices)
    all_indices.extend(indices_by_material[mat])
    count = len(all_indices) - start
    primitive_index_ranges.append((start, count, mat))

# ==================== Buffer 编码 ====================

pos_bytes = struct.pack(f'<{len(positions)}f', *positions)
norm_bytes = struct.pack(f'<{len(normals)}f', *normals)
uv_bytes = struct.pack(f'<{len(uvs)}f', *uvs)
idx_bytes = struct.pack(f'<{len(all_indices)}H', *all_indices)

def pad4(b: bytes) -> bytes:
    return b + b'\x00' * ((-len(b)) % 4)

pos_bytes = pad4(pos_bytes)
norm_bytes = pad4(norm_bytes)
uv_bytes = pad4(uv_bytes)
idx_bytes = pad4(idx_bytes)

buf = pos_bytes + norm_bytes + uv_bytes + idx_bytes
b64 = base64.b64encode(buf).decode('ascii')

pos_off = 0
norm_off = pos_off + len(pos_bytes)
uv_off = norm_off + len(norm_bytes)
idx_off = uv_off + len(uv_bytes)

# ==================== 写纹理 ====================

os.makedirs(TEX_DIR, exist_ok=True)
print("Generating textures...")
make_marble_tile().save(os.path.join(TEX_DIR, 'floor_basecolor.png'), optimize=True)
print("  floor_basecolor.png (marble)")
make_wall().save(os.path.join(TEX_DIR, 'wall_basecolor.png'), optimize=True)
print("  wall_basecolor.png")
make_ceiling().save(os.path.join(TEX_DIR, 'ceiling_basecolor.png'), optimize=True)
print("  ceiling_basecolor.png")

# ==================== glTF 文档 ====================

primitive_accessors = []
for offset, count, _ in primitive_index_ranges:
    primitive_accessors.append({
        "bufferView": 3,
        "byteOffset": offset * 2,
        "componentType": 5123,
        "count": count,
        "type": "SCALAR"
    })

gltf = {
    "asset": {"version": "2.0", "generator": "Beauty Multi-Room Gallery Generator"},
    "scene": 0,
    "scenes": [{"nodes": [0]}],
    "nodes": [{"mesh": 0, "name": "Gallery"}],
    "meshes": [{
        "name": "GalleryMesh",
        "primitives": [
            {
                "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                "indices": 3 + i,
                "material": primitive_index_ranges[i][2]
            } for i in range(len(primitive_index_ranges))
        ]
    }],
    "materials": [
        {
            "name": "Floor",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 0},
                "metallicFactor": 0.05,
                "roughnessFactor": 0.4
            },
            "doubleSided": True
        },
        {
            "name": "Ceiling",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 2},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.95
            },
            "doubleSided": True
        },
        {
            "name": "Wall",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 1},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.85
            },
            "doubleSided": True
        }
    ],
    "textures": [
        {"source": 0, "sampler": 0},
        {"source": 1, "sampler": 0},
        {"source": 2, "sampler": 0}
    ],
    "samplers": [{
        "magFilter": 9729,
        "minFilter": 9987,
        "wrapS": 10497,
        "wrapT": 10497
    }],
    "images": [
        {"uri": "textures/floor_basecolor.png"},
        {"uri": "textures/wall_basecolor.png"},
        {"uri": "textures/ceiling_basecolor.png"}
    ],
    "buffers": [{
        "uri": "data:application/octet-stream;base64," + b64,
        "byteLength": len(buf)
    }],
    "bufferViews": [
        {"buffer": 0, "byteOffset": pos_off, "byteLength": 4 * len(positions), "target": 34962},
        {"buffer": 0, "byteOffset": norm_off, "byteLength": 4 * len(normals), "target": 34962},
        {"buffer": 0, "byteOffset": uv_off, "byteLength": 4 * len(uvs), "target": 34962},
        {"buffer": 0, "byteOffset": idx_off, "byteLength": 2 * len(all_indices), "target": 34963}
    ],
    "accessors": [
        {"bufferView": 0, "componentType": 5126, "count": vertex_count, "type": "VEC3",
         "min": [-HW, 0.0, -HD], "max": [HW, H, HD]},
        {"bufferView": 1, "componentType": 5126, "count": vertex_count, "type": "VEC3"},
        {"bufferView": 2, "componentType": 5126, "count": vertex_count, "type": "VEC2"},
        *primitive_accessors
    ]
}

OUT_PATH = os.path.join(OUT_DIR, "scene.gltf")
with open(OUT_PATH, 'w', encoding='utf-8') as f:
    json.dump(gltf, f, indent=2)

print(f"\nWrote {OUT_PATH}")
print(f"Layout: {W}m wide x {H}m tall x {D}m deep, 3 rooms with 2 doorways each")
print(f"Vertices: {vertex_count} | Indices: {len(all_indices)} | Buffer: {len(buf)} bytes")
