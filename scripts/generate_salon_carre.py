#!/usr/bin/env python3
"""
生成 Salon Carré（卢浮宫方厅）glTF + 槽位数据。
- 长矩形：30m × 10m × 8m（含筒形拱顶）
- PBR 材质：深红墙面 + 木地板 + 拱顶天花
- 墙面 pilaster 分隔出画作槽位

用法：
    python scripts/generate_salon_carre.py
"""
import base64, json, math, os, random, struct
from PIL import Image, ImageDraw

# ==================== 房间参数 ====================
WIDTH = 30.0    # X（东西，长边）
DEPTH = 10.0    # Z（南北，短边）
WALL_HEIGHT = 5.5   # 墙面高度（拱顶起始处）
VAULT_RISE = 2.5    # 拱顶弧度高度
TOTAL_H = WALL_HEIGHT + VAULT_RISE  # 总高 8m

HW = WIDTH / 2
HD = DEPTH / 2

OUT_DIR = os.path.join("entry", "src", "main", "resources", "rawfile", "gltf", "salon_carre")
TEX_DIR = os.path.join(OUT_DIR, "textures")
SLOT_TS_PATH = os.path.join("entry", "src", "main", "ets", "scenes", "SalonCarreSlots.ets")

random.seed(17)

# ==================== 纹理生成 ====================

def make_wood_floor(size: int = 256) -> Image.Image:
    """深色橡木拼花地板"""
    r0, g0, b0 = (95, 62, 38)
    img = Image.new('RGB', (size, size), (r0, g0, b0))
    pixels = img.load()
    for x in range(size):
        for y in range(size):
            n = random.randint(-8, 8)
            # 木纹纵条
            grain = int(math.sin(y * 0.3 + x * 0.05) * 5)
            pixels[x, y] = (
                max(0, min(255, r0 + n + grain)),
                max(0, min(255, g0 + n + grain)),
                max(0, min(255, b0 + n + grain))
            )
    # 木板接缝
    draw = ImageDraw.Draw(img)
    plank_w = size // 8
    for i in range(1, 8):
        x = i * plank_w + random.randint(-2, 2)
        draw.line([(x, 0), (x, size)], fill=(55, 35, 20), width=2)
    return img


def make_red_wall(size: int = 256) -> Image.Image:
    """深红丝绒墙面 —— Salon Rouge"""
    r0, g0, b0 = (148, 28, 28)
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


def make_vault_ceiling(size: int = 256) -> Image.Image:
    """浅灰石膏拱顶 + 隐约分隔线"""
    r0, g0, b0 = (210, 205, 195)
    img = Image.new('RGB', (size, size), (r0, g0, b0))
    pixels = img.load()
    for x in range(size):
        for y in range(size):
            n = random.randint(-4, 4)
            pixels[x, y] = (
                max(0, min(255, r0 + n)),
                max(0, min(255, g0 + n)),
                max(0, min(255, b0 + n))
            )
    return img


def make_slot_frame(size: int = 256) -> Image.Image:
    """金色槽位边框（半透明）"""
    img = Image.new('RGBA', (size, size), (255, 255, 255, 35))
    draw = ImageDraw.Draw(img)
    border = (200, 160, 40, 210)
    m = 10
    draw.rectangle([m, m, size - m - 1, size - m - 1], outline=border, width=3)
    inner = 28
    draw.rectangle([inner, inner, size - inner - 1, size - inner - 1], outline=border, width=1)
    return img


# ==================== 材质索引 ====================
MAT_FLOOR = 0
MAT_CEILING = 1  # 拱顶
MAT_WALL = 2     # 红墙
MAT_SLOT = 3     # 槽位框

UV_FLOOR = 1.0 / 2.0
UV_WALL = 1.0 / 3.0
UV_CEILING = 1.0 / 3.0

faces: list = []  # (verts4, normal, uv_u, uv_v, mat)


def add_face(positions, normal, material_idx, uv_u_m, uv_v_m):
    if material_idx == MAT_FLOOR:
        repeat = UV_FLOOR
    elif material_idx == MAT_CEILING:
        repeat = UV_CEILING
    else:
        repeat = UV_WALL
    faces.append((positions, normal, uv_u_m * repeat, uv_v_m * repeat, material_idx))


# === 地板 ===
add_face(
    [(-HW, 0, HD), (HW, 0, HD), (HW, 0, -HD), (-HW, 0, -HD)],
    (0, 1, 0), MAT_FLOOR, WIDTH, DEPTH
)

# === 外墙 ===
# 北墙（长墙，z=-HD，法线 +Z）
add_face(
    [(-HW, 0, -HD), (HW, 0, -HD), (HW, WALL_HEIGHT, -HD), (-HW, WALL_HEIGHT, -HD)],
    (0, 0, 1), MAT_WALL, WIDTH, WALL_HEIGHT
)
# 南墙（长墙，z=+HD，法线 -Z）
add_face(
    [(HW, 0, HD), (-HW, 0, HD), (-HW, WALL_HEIGHT, HD), (HW, WALL_HEIGHT, HD)],
    (0, 0, -1), MAT_WALL, WIDTH, WALL_HEIGHT
)
# 东墙（短墙，x=+HW，法线 -X）
add_face(
    [(HW, 0, HD), (HW, 0, -HD), (HW, WALL_HEIGHT, -HD), (HW, WALL_HEIGHT, HD)],
    (-1, 0, 0), MAT_WALL, DEPTH, WALL_HEIGHT
)
# 西墙（短墙，x=-HW，法线 +X）
add_face(
    [(-HW, 0, -HD), (-HW, 0, HD), (-HW, WALL_HEIGHT, HD), (-HW, WALL_HEIGHT, -HD)],
    (1, 0, 0), MAT_WALL, DEPTH, WALL_HEIGHT
)

# === 筒形拱顶（分段近似） ===
# 拱顶沿 X 轴延伸（长边方向），截面是半圆拱
# 每个拱段是一个沿 X 的 strip，由多个小平面组成
ARCH_SEGMENTS = 12    # 拱截面分段数
ARCH_STRIPS = 20      # 沿 X 轴的分段数
ARCH_RADIUS = HD      # 拱半径 = 房间半深

for xi in range(ARCH_STRIPS):
    x0 = -HW + (WIDTH / ARCH_STRIPS) * xi
    x1 = -HW + (WIDTH / ARCH_STRIPS) * (xi + 1)
    for ai in range(ARCH_SEGMENTS):
        a0 = math.pi * ai / ARCH_SEGMENTS       # 0..π
        a1 = math.pi * (ai + 1) / ARCH_SEGMENTS

        z0_sin = math.sin(a0)
        z1_sin = math.sin(a1)
        z0_cos = math.cos(a0)
        z1_cos = math.cos(a1)

        z0 = -ARCH_RADIUS * z0_cos  # z = -R*cos(a), from -R to +R
        z1 = -ARCH_RADIUS * z1_cos
        y0 = WALL_HEIGHT + ARCH_RADIUS * z0_sin  # y = wall + R*sin(a)
        y1 = WALL_HEIGHT + ARCH_RADIUS * z1_sin

        v0 = (x0, y0, z0)
        v1 = (x1, y0, z0)
        v2 = (x1, y1, z1)
        v3 = (x0, y1, z1)

        # 法线：从拱中心向外（中心在 y=WALL_HEIGHT, z=0）
        cy = WALL_HEIGHT
        cz = 0.0
        mid_y = (y0 + y1) / 2
        mid_z = (z0 + z1) / 2
        nx = 0.0
        ny = mid_y - cy
        nz = mid_z - cz
        nl = math.sqrt(ny * ny + nz * nz)
        if nl > 0.001:
            ny /= nl
            nz /= nl

        add_face([v0, v1, v2, v3], (nx, ny, nz), MAT_CEILING,
                  (x1 - x0), math.sqrt((y1 - y0) ** 2 + (z1 - z0) ** 2))

# ==================== 槽位定义 ====================
# Pilasters 沿长墙分布，间距约 5m
# 北墙（z=-HD）和南墙（z=+HD）各有画作槽位在 pilaster 之间
PILASTER_SPACING = 5.0    # pilaster 间距
PILASTER_WIDTH = 0.4      # pilaster 宽度
PAINTING_Y = 2.8          # 画作中心高度（沙龙挂法：较高）
SLOT_W = 2.0              # 画作槽位宽度（沙龙画作较大）
SLOT_H = 2.5              # 画作槽位高度

# 沿长墙均匀分布画作槽位
PAINTING_SLOTS = []
slot_id_counter = 1
for wall_z, wall_name, facing, fz in [(-HD, "北墙", [0, 0, 1], "N"), (HD, "南墙", [0, 0, -1], "S")]:
    # 每个槽位中心在 pilaster 之间
    start_x = -HW + 1.0  # 留边距
    while start_x + SLOT_W < HW - 1.0:
        px = start_x + SLOT_W / 2
        if px + SLOT_W / 2 + PILASTER_WIDTH < HW - 1.0:
            name = f"Slot_Painting_{fz}{slot_id_counter:02d}"
            label = f"{wall_name} #{slot_id_counter}"
            PAINTING_SLOTS.append((name, px, wall_z, facing, label))
            slot_id_counter += 1
        start_x += SLOT_W + PILASTER_WIDTH

# 短墙（东西墙）各 1 个大幅画作槽位
PAINTING_SLOTS.append(
    ("Slot_Painting_East", HW, 0, [-1, 0, 0], "东墙大幅")
)
PAINTING_SLOTS.append(
    ("Slot_Painting_West", -HW, 0, [1, 0, 0], "西墙大幅")
)

# 雕塑槽位
SCULPTURE_CENTER = (0.0, 0.0, 0.0)
SPAWN_POS = (0.0, 1.65, HD - 1.5)

# ==================== 槽位占位框 ====================
SLOT_EPSILON = 0.005
slot_quad_faces: list = []


def add_slot_painting_quad(cx, cy, cz, nx, nz):
    right_x = nz
    right_z = -nx
    hw = SLOT_W / 2
    hh = SLOT_H / 2
    ox = cx + nx * SLOT_EPSILON
    oy = cy
    oz = cz + nz * SLOT_EPSILON
    tl = (ox + right_x * (-hw), oy + hh, oz + right_z * (-hw))
    tr = (ox + right_x * (hw), oy + hh, oz + right_z * (hw))
    br = (ox + right_x * (hw), oy - hh, oz + right_z * (hw))
    bl = (ox + right_x * (-hw), oy - hh, oz + right_z * (-hw))
    normal = (nx, 0.0, nz)
    slot_quad_faces.append(([bl, tl, tr, br], normal, 1.0, 1.0, MAT_SLOT))


def add_slot_sculpture_platform(cx, cz):
    hsize = 0.8
    y = 0.02
    v0 = (cx - hsize, y, cz - hsize)
    v1 = (cx - hsize, y, cz + hsize)
    v2 = (cx + hsize, y, cz + hsize)
    v3 = (cx + hsize, y, cz - hsize)
    slot_quad_faces.append(([v0, v1, v2, v3], (0.0, 1.0, 0.0), 1.0, 1.0, MAT_SLOT))


for name, px, pz, facing, label in PAINTING_SLOTS:
    add_slot_painting_quad(px, PAINTING_Y, pz, facing[0], facing[2])

add_slot_sculpture_platform(SCULPTURE_CENTER[0], SCULPTURE_CENTER[2])

# ==================== 槽位节点（glTF metadata） ====================
SLOT_NODES = []
SLOT_TS_ENTRIES = []

for name, px, pz, facing, label in PAINTING_SLOTS:
    SLOT_NODES.append({
        "name": name,
        "translation": [px, PAINTING_Y, pz],
        "rotation": [0, 0, 0, 1],
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

SLOT_NODES.append({
    "name": "Slot_Sculpture_Center",
    "translation": [SCULPTURE_CENTER[0], SCULPTURE_CENTER[1], SCULPTURE_CENTER[2]],
    "rotation": [0, 0, 0, 1],
    "extras": {
        "slotType": "sculpture", "slotId": "center",
        "maxWidth": 2.0, "maxHeight": 3.0,
        "facing": [0, 0, 0], "label": "中央雕塑位"
    }
})
SLOT_TS_ENTRIES.append({
    "name": "Slot_Sculpture_Center",
    "position": [SCULPTURE_CENTER[0], SCULPTURE_CENTER[1], SCULPTURE_CENTER[2]],
    "facing": [0, 0, 0], "maxWidth": 2.0, "maxHeight": 3.0, "label": "中央雕塑位"
})

SLOT_NODES.append({
    "name": "Slot_Spawn",
    "translation": [SPAWN_POS[0], SPAWN_POS[1], SPAWN_POS[2]],
    "rotation": [0, 0, 0, 1],
    "extras": {
        "slotType": "spawn", "slotId": "spawn",
        "maxWidth": 0, "maxHeight": 0,
        "facing": [0, 0, -1], "label": "入口"
    }
})

# ==================== Buffer 编码 ====================
indices_by_mat = {MAT_FLOOR: [], MAT_CEILING: [], MAT_WALL: [], MAT_SLOT: []}

positions: list[float] = []
normals: list[float] = []
uvs: list[float] = []

faces_with_slots = list(faces)
faces_with_slots.extend(slot_quad_faces)

vertex_count = 0
for verts4, normal, uv_u, uv_v, mat in faces_with_slots:
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
for mat in [MAT_FLOOR, MAT_CEILING, MAT_WALL, MAT_SLOT]:
    start = len(all_indices)
    all_indices.extend(indices_by_mat[mat])
    count = len(all_indices) - start
    if count > 0:
        primitive_ranges.append((start, count, mat))

pos_bytes = struct.pack(f'<{len(positions)}f', *positions)
norm_bytes = struct.pack(f'<{len(normals)}f', *normals)
uv_bytes = struct.pack(f'<{len(uvs)}f', *uvs)
idx_bytes = struct.pack(f'<{len(all_indices)}H', *all_indices)


def pad4(b):
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
make_wood_floor().save(os.path.join(TEX_DIR, 'floor_basecolor.png'), optimize=True)
make_red_wall().save(os.path.join(TEX_DIR, 'wall_basecolor.png'), optimize=True)
make_vault_ceiling().save(os.path.join(TEX_DIR, 'ceiling_basecolor.png'), optimize=True)
make_slot_frame().save(os.path.join(TEX_DIR, 'slot_frame.png'), optimize=True)
print("  floor_basecolor.png | wall_basecolor.png | ceiling_basecolor.png | slot_frame.png")

# ==================== glTF 文档 ====================
all_nodes = [{"mesh": 0, "name": "SalonCarre"}]
all_nodes.extend(SLOT_NODES)

primitive_accessors = []
for i, (offset, count, _) in enumerate(primitive_ranges):
    primitive_accessors.append({
        "bufferView": 3,
        "byteOffset": offset * 2,
        "componentType": 5123,
        "count": count,
        "type": "SCALAR"
    })

gltf = {
    "asset": {"version": "2.0", "generator": "Beauty Salon Carre Generator"},
    "scene": 0,
    "scenes": [{"nodes": list(range(len(all_nodes)))}],
    "nodes": all_nodes,
    "meshes": [{
        "name": "SalonCarreMesh",
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
                "metallicFactor": 0.05,
                "roughnessFactor": 0.35
            },
            "doubleSided": True
        },
        {
            "name": "VaultCeiling",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 2},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.9
            },
            "doubleSided": True
        },
        {
            "name": "RedWall",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 1},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.8
            },
            "doubleSided": True
        },
        {
            "name": "SlotFrame",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 3},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.7
            },
            "alphaMode": "BLEND",
            "doubleSided": True
        }
    ],
    "textures": [
        {"source": 0, "sampler": 0},
        {"source": 1, "sampler": 0},
        {"source": 2, "sampler": 0},
        {"source": 3, "sampler": 0}
    ],
    "samplers": [{
        "magFilter": 9729, "minFilter": 9987,
        "wrapS": 10497, "wrapT": 10497
    }],
    "images": [
        {"uri": "textures/floor_basecolor.png"},
        {"uri": "textures/wall_basecolor.png"},
        {"uri": "textures/ceiling_basecolor.png"},
        {"uri": "textures/slot_frame.png"}
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
         "min": [-HW, 0.0, -HD], "max": [HW, TOTAL_H, HD]},
        {"bufferView": 1, "componentType": 5126, "count": vertex_count, "type": "VEC3"},
        {"bufferView": 2, "componentType": 5126, "count": vertex_count, "type": "VEC2"},
        *primitive_accessors
    ]
}

OUT_PATH = os.path.join(OUT_DIR, "scene.gltf")
with open(OUT_PATH, 'w', encoding='utf-8') as f:
    json.dump(gltf, f, indent=2)
print(f"\nWrote {OUT_PATH}")
print(f"Room: {WIDTH}m x {DEPTH}m x {TOTAL_H}m (vaulted)")
print(f"Slots: {len(PAINTING_SLOTS)} painting + 1 sculpture + 1 spawn")
print(f"Vertices: {vertex_count} | Indices: {len(all_indices)} | Buffer: {len(buf)} bytes")

# ==================== 写 TypeScript 槽位文件 ====================
ts_lines = [
    "/**",
    " * Salon Carré 展厅 · 槽位数据",
    " * 由 scripts/generate_salon_carre.py 自动生成，请勿手动编辑。",
    " */",
    "",
    "import { ParsedSlot } from './WhiteCubeSlots';",
    "",
    "export const SALON_CARRE_SLOTS: ParsedSlot[] = [",
]

for ts in SLOT_TS_ENTRIES:
    slot_type = "painting"
    if "Sculpture" in ts["name"]:
        slot_type = "sculpture"
    elif "Spawn" in ts["name"]:
        slot_type = "spawn"
    sid = ts["name"].replace("Slot_Painting_", "").replace("Slot_Sculpture_", "").replace("Slot_Spawn", "spawn").lower()
    px, py, pz = ts["position"]
    fx, fy, fz = ts["facing"]
    mw, mh = ts["maxWidth"], ts["maxHeight"]
    lbl = ts["label"]
    ts_lines.append(
        f"  {{ name: '{ts['name']}', slotType: '{slot_type}', slotId: '{sid}',"
        f" positionX: {px:.3f}, positionY: {py:.3f}, positionZ: {pz:.3f},"
        f" facingX: {fx}, facingY: {fy}, facingZ: {fz},"
        f" maxWidth: {mw:.1f}, maxHeight: {mh:.1f},"
        f" label: '{lbl}' }},"
    )

ts_lines.append("];")
ts_lines.append("")

os.makedirs(os.path.dirname(SLOT_TS_PATH), exist_ok=True)
with open(SLOT_TS_PATH, 'w', encoding='utf-8') as f:
    f.write("\n".join(ts_lines))
print(f"Wrote {SLOT_TS_PATH}")
