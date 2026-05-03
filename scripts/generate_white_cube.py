#!/usr/bin/env python3
"""
生成 MoMA 白立方展厅 glTF + 槽位数据。
- 单间：15m 宽 × 10m 深 × 5m 高
- PBR 材质：抛光混凝土地板 + 纯白石膏墙 + 方格吊顶
- 内置 Slot_Painting_* / Slot_Sculpture_* / Slot_Spawn 空节点（含 extras 元数据）
- 同时导出 white_cube_slots.ets 供 ArkTS 直接使用

用法：
    python scripts/generate_white_cube.py
"""
import base64
import json
import math
import os
import random
import struct
from PIL import Image, ImageDraw

# ==================== 房间参数 ====================
WIDTH = 15.0    # X：东西
DEPTH = 10.0    # Z：南北
HEIGHT = 5.0    # Y：层高

HW = WIDTH / 2
HD = DEPTH / 2
HH = HEIGHT / 2

OUT_DIR = os.path.join("entry", "src", "main", "resources", "rawfile", "gltf", "white_cube")
TEX_DIR = os.path.join(OUT_DIR, "textures")
SLOT_TS_PATH = os.path.join("entry", "src", "main", "ets", "scenes", "WhiteCubeSlots.ets")

random.seed(42)

# ==================== 纹理生成 ====================

def make_concrete_floor(size: int = 256) -> Image.Image:
    """抛光混凝土地板：中灰底色 + 细颗粒"""
    r0, g0, b0 = (180, 178, 174)
    img = Image.new('RGB', (size, size), (r0, g0, b0))
    pixels = img.load()
    for x in range(size):
        for y in range(size):
            n = random.randint(-6, 6)
            pixels[x, y] = (
                max(0, min(255, r0 + n)),
                max(0, min(255, g0 + n)),
                max(0, min(255, b0 + n))
            )
    return img


def make_white_wall(size: int = 256) -> Image.Image:
    """纯白石膏墙：极细颗粒"""
    r0, g0, b0 = (248, 247, 243)
    img = Image.new('RGB', (size, size), (r0, g0, b0))
    pixels = img.load()
    for x in range(size):
        for y in range(size):
            n = random.randint(-3, 3)
            pixels[x, y] = (
                max(0, min(255, r0 + n)),
                max(0, min(255, g0 + n)),
                max(0, min(255, b0 + n))
            )
    return img


def make_grid_ceiling(size: int = 256) -> Image.Image:
    """方格吊顶：浅灰白底 + 纵横格线（仿石膏板天花 + 轨道射灯槽）"""
    r0, g0, b0 = (232, 231, 228)
    img = Image.new('RGB', (size, size), (r0, g0, b0))
    draw = ImageDraw.Draw(img)
    grid = (60, 60, 60)
    step = size // 4  # 4×4 格
    for i in range(1, 4):
        x = i * step
        draw.line([(x, 0), (x, size)], fill=grid, width=1)
        draw.line([(0, x), (size, x)], fill=grid, width=1)
    return img


# ==================== 几何生成 ====================

MAT_FLOOR = 0
MAT_CEILING = 1
MAT_WALL = 2

# UV 缩放
UV_FLOOR = 1.0 / 1.5    # 每 1.5m 重复
UV_WALL = 1.0 / 2.5
UV_CEILING = 1.0 / 2.0

faces: list = []  # (verts4, normal, uv_u_extent, uv_v_extent, material)


def add_face(positions, normal, material_idx, uv_u_m, uv_v_m):
    if material_idx == MAT_FLOOR:
        repeat = UV_FLOOR
    elif material_idx == MAT_CEILING:
        repeat = UV_CEILING
    else:
        repeat = UV_WALL
    faces.append((positions, normal, uv_u_m * repeat, uv_v_m * repeat, material_idx))


# 地板
add_face(
    [(-HW, 0, HD), (HW, 0, HD), (HW, 0, -HD), (-HW, 0, -HD)],
    (0, 1, 0), MAT_FLOOR, WIDTH, DEPTH
)
# 天花板
add_face(
    [(-HW, HEIGHT, -HD), (HW, HEIGHT, -HD), (HW, HEIGHT, HD), (-HW, HEIGHT, HD)],
    (0, -1, 0), MAT_CEILING, WIDTH, DEPTH
)
# 北墙 z=-HD (法线 +Z，朝南)
add_face(
    [(-HW, 0, -HD), (HW, 0, -HD), (HW, HEIGHT, -HD), (-HW, HEIGHT, -HD)],
    (0, 0, 1), MAT_WALL, WIDTH, HEIGHT
)
# 南墙 z=+HD (法线 -Z，朝北)
add_face(
    [(HW, 0, HD), (-HW, 0, HD), (-HW, HEIGHT, HD), (HW, HEIGHT, HD)],
    (0, 0, -1), MAT_WALL, WIDTH, HEIGHT
)
# 东墙 x=+HW (法线 -X，朝西)
add_face(
    [(HW, 0, HD), (HW, 0, -HD), (HW, HEIGHT, -HD), (HW, HEIGHT, HD)],
    (-1, 0, 0), MAT_WALL, DEPTH, HEIGHT
)
# 西墙 x=-HW (法线 +X，朝东)
add_face(
    [(-HW, 0, -HD), (-HW, 0, HD), (-HW, HEIGHT, HD), (-HW, HEIGHT, -HD)],
    (1, 0, 0), MAT_WALL, DEPTH, HEIGHT
)

# ==================== 槽位定义 ====================
# 每个墙面的画作槽位：中心 Y = 1.55m（画作中心在视平线附近）
# 槽位宽 1.2m × 高 0.9m（默认 max 尺寸）
PAINTING_Y = 1.55
SLOT_W = 1.2
SLOT_H = 0.9

# 雕塑槽位：地面中央
SCULPTURE_CENTER = (0.0, 0.0, 0.0)

# 出生点：南墙入口处
SPAWN_POS = (0.0, 1.65, HD - 1.5)

# 画作槽位数据：(name, x, z, facing_vec) — 贴在墙上因此 y 固定
PAINTING_SLOTS = [
    # 北墙（3 幅）：z = -HD, facing = (0, 0, 1)
    ("Slot_Painting_North01", -4.5, -HD, [0, 0, 1], "北墙左"),
    ("Slot_Painting_North02",  0.0, -HD, [0, 0, 1], "北墙中"),
    ("Slot_Painting_North03",  4.5, -HD, [0, 0, 1], "北墙右"),
    # 南墙（2 幅，中间留空给入口）：z = +HD, facing = (0, 0, -1)
    ("Slot_Painting_South01", -3.0,  HD, [0, 0, -1], "南墙左"),
    ("Slot_Painting_South02",  3.0,  HD, [0, 0, -1], "南墙右"),
    # 东墙（2 幅）：x = +HW, facing = (-1, 0, 0)
    ("Slot_Painting_East01",  HW, -2.5, [-1, 0, 0], "东墙前"),
    ("Slot_Painting_East02",  HW,  2.5, [-1, 0, 0], "东墙后"),
    # 西墙（2 幅）：x = -HW, facing = (1, 0, 0)
    ("Slot_Painting_West01", -HW, -2.5, [1, 0, 0], "西墙前"),
    ("Slot_Painting_West02", -HW,  2.5, [1, 0, 0], "西墙后"),
]

SLOT_NODES = []  # glTF node entries for slots
SLOT_TS_ENTRIES = []  # TypeScript entries

for name, px, pz, facing, label in PAINTING_SLOTS:
    # glTF node: translation places it at the wall surface
    SLOT_NODES.append({
        "name": name,
        "translation": [px, PAINTING_Y, pz],
        "rotation": [0, 0, 0, 1],  # identity; rotation derived from facing in runtime
        "extras": {
            "slotType": "painting",
            "slotId": name.replace("Slot_Painting_", "").lower(),
            "maxWidth": SLOT_W,
            "maxHeight": SLOT_H,
            "facing": facing,
            "label": label
        }
    })
    SLOT_TS_ENTRIES.append({
        "name": name,
        "position": [px, PAINTING_Y, pz],
        "facing": facing,
        "maxWidth": SLOT_W,
        "maxHeight": SLOT_H,
        "label": label
    })

# 雕塑槽位
SLOT_NODES.append({
    "name": "Slot_Sculpture_Center",
    "translation": [SCULPTURE_CENTER[0], SCULPTURE_CENTER[1], SCULPTURE_CENTER[2]],
    "rotation": [0, 0, 0, 1],
    "extras": {
        "slotType": "sculpture",
        "slotId": "center",
        "maxWidth": 2.0,
        "maxHeight": 3.0,
        "facing": [0, 0, 0],
        "label": "中央雕塑位"
    }
})
SLOT_TS_ENTRIES.append({
    "name": "Slot_Sculpture_Center",
    "position": [SCULPTURE_CENTER[0], SCULPTURE_CENTER[1], SCULPTURE_CENTER[2]],
    "facing": [0, 0, 0],
    "maxWidth": 2.0,
    "maxHeight": 3.0,
    "label": "中央雕塑位"
})

# 出生点
SLOT_NODES.append({
    "name": "Slot_Spawn",
    "translation": [SPAWN_POS[0], SPAWN_POS[1], SPAWN_POS[2]],
    "rotation": [0, 0, 0, 1],
    "extras": {
        "slotType": "spawn",
        "slotId": "spawn",
        "maxWidth": 0,
        "maxHeight": 0,
        "facing": [0, 0, -1],
        "label": "入口"
    }
})

# ==================== Buffer 编码 ====================

positions: list[float] = []
normals: list[float] = []
uvs: list[float] = []
indices_by_mat: dict[int, list[int]] = {MAT_FLOOR: [], MAT_CEILING: [], MAT_WALL: []}

vertex_count = 0
for verts4, normal, uv_u, uv_v, mat in faces:
    base = vertex_count
    for vx, vy, vz in verts4:
        positions.extend([vx, vy, vz])
    for _ in range(4):
        normals.extend(list(normal))
    for u, v in [(0, 0), (1, 0), (1, 1), (0, 1)]:
        uvs.extend([u * uv_u, v * uv_v])
    indices_by_mat[mat].extend([base, base + 1, base + 2, base, base + 2, base + 3])
    vertex_count += 4

all_indices: list[int] = []
primitive_ranges: list[tuple[int, int, int]] = []
for mat in [MAT_FLOOR, MAT_CEILING, MAT_WALL]:
    start = len(all_indices)
    all_indices.extend(indices_by_mat[mat])
    count = len(all_indices) - start
    primitive_ranges.append((start, count, mat))

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
make_concrete_floor().save(os.path.join(TEX_DIR, 'floor_basecolor.png'), optimize=True)
make_white_wall().save(os.path.join(TEX_DIR, 'wall_basecolor.png'), optimize=True)
make_grid_ceiling().save(os.path.join(TEX_DIR, 'ceiling_basecolor.png'), optimize=True)
print("  floor_basecolor.png | wall_basecolor.png | ceiling_basecolor.png")

# ==================== glTF 文档 ====================

# Building nodes: root node (gallery mesh) + slot nodes
all_nodes = [{"mesh": 0, "name": "WhiteCube"}]  # index 0: room mesh
for slot in SLOT_NODES:
    all_nodes.append(slot)  # indices 1..N: slot nodes

gltf = {
    "asset": {"version": "2.0", "generator": "Beauty White Cube Generator"},
    "scene": 0,
    "scenes": [{"nodes": list(range(len(all_nodes)))}],  # all nodes at root level
    "nodes": all_nodes,
    "meshes": [{
        "name": "WhiteCubeMesh",
        "primitives": [
            {
                "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                "indices": 3 + i,
                "material": primitive_ranges[i][2]
            } for i in range(len(primitive_ranges))
        ]
    }],
    "materials": [
        {
            "name": "Floor",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 0},
                "metallicFactor": 0.1,
                "roughnessFactor": 0.3
            },
            "doubleSided": True
        },
        {
            "name": "Ceiling",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 2},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.9
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
         "min": [-HW, 0.0, -HD], "max": [HW, HEIGHT, HD]},
        {"bufferView": 1, "componentType": 5126, "count": vertex_count, "type": "VEC3"},
        {"bufferView": 2, "componentType": 5126, "count": vertex_count, "type": "VEC2"},
    ]
}

# Add index accessors for each primitive
for i, (offset, count, _) in enumerate(primitive_ranges):
    gltf["accessors"].append({
        "bufferView": 3,
        "byteOffset": offset * 2,
        "componentType": 5123,
        "count": count,
        "type": "SCALAR"
    })

OUT_PATH = os.path.join(OUT_DIR, "scene.gltf")
with open(OUT_PATH, 'w', encoding='utf-8') as f:
    json.dump(gltf, f, indent=2)
print(f"\nWrote {OUT_PATH}")
print(f"Room: {WIDTH}m × {DEPTH}m × {HEIGHT}m")
print(f"Slots: {len(SLOT_TS_ENTRIES)} ({len(PAINTING_SLOTS)} painting + 1 sculpture + 1 spawn)")
print(f"Vertices: {vertex_count} | Indices: {len(all_indices)} | Buffer: {len(buf)} bytes")

# ==================== 写 TypeScript 槽位文件 ====================

ts_lines = [
    "/**",
    " * 白立方展厅 · 槽位数据",
    " * 由 scripts/generate_white_cube.py 自动生成，请勿手动编辑。",
    " */",
    "",
    "export type SlotType = 'painting' | 'sculpture' | 'spawn';",
    "",
    "export interface ParsedSlot {",
    "  name: string;",
    "  slotType: SlotType;",
    "  slotId: string;",
    "  positionX: number;",
    "  positionY: number;",
    "  positionZ: number;",
    "  facingX: number;",
    "  facingY: number;",
    "  facingZ: number;",
    "  maxWidth: number;",
    "  maxHeight: number;",
    "  label: string;",
    "}",
    "",
    "export const WHITE_CUBE_SLOTS: ParsedSlot[] = [",
]

for ts in SLOT_TS_ENTRIES:
    name = ts["name"]
    slot_type = "painting"
    if "Sculpture" in name:
        slot_type = "sculpture"
    elif "Spawn" in name:
        slot_type = "spawn"
    slot_id = name.replace("Slot_Painting_", "").replace("Slot_Sculpture_", "").replace("Slot_Spawn", "spawn").lower()
    px, py, pz = ts["position"]
    fx, fy, fz = ts["facing"]
    mw = ts["maxWidth"]
    mh = ts["maxHeight"]
    label = ts["label"]
    ts_lines.append(
        f"  {{ name: '{name}', slotType: '{slot_type}', slotId: '{slot_id}',"
        f" positionX: {px}, positionY: {py}, positionZ: {pz},"
        f" facingX: {fx}, facingY: {fy}, facingZ: {fz},"
        f" maxWidth: {mw}, maxHeight: {mh},"
        f" label: '{label}' }},"
    )

ts_lines.append("];")
ts_lines.append("")

os.makedirs(os.path.dirname(SLOT_TS_PATH), exist_ok=True)
with open(SLOT_TS_PATH, 'w', encoding='utf-8') as f:
    f.write("\n".join(ts_lines))
print(f"\nWrote {SLOT_TS_PATH}")
