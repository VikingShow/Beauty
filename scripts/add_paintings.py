#!/usr/bin/env python3
"""
往 David/scene.gltf 合并 9 幅文艺复兴时期公有领域画作 + 金色画框。

数据源：Wikimedia Commons（全部原作者去世 >70 年，公有领域）。
下载到 rawfile/gltf/David/paintings/，压缩为 JPEG 品质 85，最长边 1024px。
glTF 修改：追加 9 个 quad mesh（贴图）+ 9 个 box mesh（画框），
         新数据用 base64 内嵌 buffer，不碰原 scene.bin。

用法：
    python scripts/add_paintings.py
"""
import base64
import http.client
import json
import math
import os
import struct
import time
import urllib.parse
import urllib.request
from io import BytesIO
from PIL import Image
# Wikimedia 提供的图可能超过默认 180M 像素阈值；我们信任来源，抬高阈值。
Image.MAX_IMAGE_PIXELS = None

# === 路径 ===
GLTF_PATH = os.path.join("entry", "src", "main", "resources", "rawfile", "gltf", "David", "scene.gltf")
BACKUP_PATH = GLTF_PATH + ".orig"
PAINTINGS_DIR = os.path.join("entry", "src", "main", "resources", "rawfile", "gltf", "David", "paintings")

MAX_TEXTURE_SIDE = 1024
JPEG_QUALITY = 85

# === 画作清单 ===
# 每项：id, 原 Wikimedia 文件名（%编码）、用 jpg/png 后缀
# 尺寸按原作比例计算：landscape 固定 W=1.8m、portrait 固定 H=1.2m
# 15 幅**主流名作**文艺复兴画作。size 字段：landscape=宽度，portrait=高度。
# 全部避开 David 展台（X=[7, 10] × Z=[-3.5, 3.5]），全挂在周边墙/中央隔断。
PAINTINGS = [
    # ========= Space A · 文艺复兴意大利 =========
    {
        "id": "mona_lisa",
        "title_zh": "蒙娜丽莎",
        "title_en": "Mona Lisa",
        "artist": "Leonardo da Vinci",
        "year": "1503–1519",
        "filename": "Mona Lisa, by Leonardo da Vinci, from C2RMF retouched.jpg",
        "orient": "portrait",
        "aspect": 53 / 77,
        "size": 1.4,
        "pos": (-7.0, 1.7, -7.5),
        "facing": "+Z",
    },
    {
        "id": "botticelli_primavera",
        "title_zh": "春",
        "title_en": "Primavera",
        "artist": "Sandro Botticelli",
        "year": "c.1480",
        "filename": "Botticelli-primavera.jpg",
        "orient": "landscape",
        "aspect": 314 / 203,
        "size": 2.0,
        "pos": (-4.3, 1.7, -7.5),
        "facing": "+Z",
    },
    {
        "id": "school_of_athens",
        "title_zh": "雅典学院",
        "title_en": "The School of Athens",
        "artist": "Raphael",
        "year": "1509–1511",
        "filename": "\"The School of Athens\" by Raffaello Sanzio da Urbino.jpg",
        "orient": "landscape",
        "aspect": 770 / 500,
        "size": 2.0,
        "pos": (-1.6, 1.7, -7.5),
        "facing": "+Z",
    },
    {
        "id": "david_napoleon",
        "title_zh": "拿破仑穿越阿尔卑斯山",
        "title_en": "Napoleon Crossing the Alps",
        "artist": "Jacques-Louis David",
        "year": "1801",
        "filename": "Jacques-Louis David 007.jpg",
        "orient": "portrait",
        "aspect": 221 / 261,
        "size": 1.8,
        "pos": (1.8, 1.7, -7.5),
        "facing": "+Z",
    },
    {
        "id": "mantegna_triumphs",
        "title_zh": "凯撒的凯旋",
        "title_en": "Triumphs of Caesar",
        "artist": "Andrea Mantegna",
        "year": "1484–1492",
        "filename": "Andrea Mantegna - The Triumphs of Caesar - Trumpeters and Standard-Bearer - WGA13990.jpg",
        "orient": "landscape",
        "aspect": 278 / 266,
        "size": 1.4,
        "pos": (5.0, 1.7, -7.5),
        "facing": "+Z",
    },
    # ========= Space B · 北方文艺复兴与荷兰黄金时代 =========
    {
        "id": "van_eyck_arnolfini",
        "title_zh": "阿诺芬尼夫妇像",
        "title_en": "The Arnolfini Portrait",
        "artist": "Jan van Eyck",
        "year": "1434",
        "filename": "Van Eyck - Arnolfini Portrait.jpg",
        "orient": "portrait",
        "aspect": 60 / 82.2,
        "size": 1.5,
        "pos": (14.1, 1.7, -7.5),
        "facing": "+Z",
    },
    {
        "id": "bruegel_hunters",
        "title_zh": "雪中猎人",
        "title_en": "Hunters in the Snow",
        "artist": "Pieter Bruegel the Elder",
        "year": "1565",
        "filename": "Pieter Bruegel the Elder - Hunters in the Snow (Winter) - Google Art Project.jpg",
        "orient": "landscape",
        "aspect": 162 / 117,
        "size": 1.8,
        "pos": (16.0, 1.7, -7.5),
        "facing": "+Z",
    },
    {
        "id": "vermeer_pearl_earring",
        "title_zh": "戴珍珠耳环的少女",
        "title_en": "Girl with a Pearl Earring",
        "artist": "Johannes Vermeer",
        "year": "c.1665",
        "filename": "Girl with a Pearl Earring.jpg",
        "orient": "portrait",
        "aspect": 39 / 44.5,
        "size": 1.2,
        "pos": (10.20, 1.85, 0.0),
        "facing": "+X",
    },
    {
        "id": "vermeer_milkmaid",
        "title_zh": "倒牛奶的女仆",
        "title_en": "The Milkmaid",
        "artist": "Johannes Vermeer",
        "year": "c.1658",
        "filename": "Johannes Vermeer - Het melkmeisje - Google Art Project.jpg",
        "orient": "portrait",
        "aspect": 41 / 45.5,
        "size": 1.2,
        "pos": (-5.5, 1.7, 7.50),
        "facing": "-Z",
    },
    {
        "id": "friedrich_wanderer",
        "title_zh": "雾海上的旅人",
        "title_en": "Wanderer above the Sea of Fog",
        "artist": "Caspar David Friedrich",
        "year": "1818",
        "filename": "Caspar David Friedrich - Wanderer above the sea of fog.jpg",
        "orient": "portrait",
        "aspect": 74.8 / 94.8,
        "size": 1.5,
        "pos": (-2.5, 1.7, 7.50),
        "facing": "-Z",
    },
    # ========= Space C · 肖像与日常生活 =========
    {
        "id": "antonello_portrait",
        "title_zh": "男子肖像",
        "title_en": "Portrait of a Man",
        "artist": "Antonello da Messina",
        "year": "c.1475",
        "filename": "Antonello da Messina - Portrait of a Man - National Gallery London.jpg",
        "orient": "portrait",
        "aspect": 25 / 35,
        "size": 1.0,
        "pos": (-0.69, 1.7, 2.0),
        "facing": "-X",
    },
    {
        "id": "renoir_luncheon",
        "title_zh": "船上的午宴",
        "title_en": "Luncheon of the Boating Party",
        "artist": "Pierre-Auguste Renoir",
        "year": "1881",
        "filename": "Pierre-Auguste Renoir - Luncheon of the Boating Party - Google Art Project.jpg",
        "alt_filenames": [
            "Renoir - Luncheon of the Boating Party.jpg",
            "Auguste Renoir - Luncheon of the Boating Party - WGA.jpg",
        ],
        "orient": "landscape",
        "aspect": 120 / 92,
        "size": 1.6,
        "pos": (-10.0, 1.7, -5.0),
        "facing": "+X",
    },
    {
        "id": "hopper_nighthawks",
        "title_zh": "夜鹰",
        "title_en": "Nighthawks",
        "artist": "Edward Hopper",
        "year": "1942",
        "filename": "Nighthawks by Edward Hopper 1942.jpg",
        "alt_filenames": [
            "Edward Hopper - Nighthawks - Google Art Project.jpg",
            "Nighthawks by Edward Hopper.jpg",
            "Edward Hopper Nighthawks.jpg",
        ],
        "orient": "landscape",
        "aspect": 152.4 / 84.1,
        "size": 2.0,
        "pos": (-10.0, 1.8, 2.0),
        "facing": "+X",
    },
    {
        "id": "giorgione_tempest",
        "title_zh": "暴风雨",
        "title_en": "The Tempest",
        "artist": "Giorgione",
        "year": "c.1508",
        "filename": "Accademia - La tempesta - Giorgione.jpg",
        "orient": "portrait",
        "aspect": 73 / 82,
        "size": 1.2,
        "pos": (-0.69, 1.7, -2.0),
        "facing": "-X",
    },
    {
        "id": "uccello_san_romano",
        "title_zh": "圣罗马诺之战",
        "title_en": "The Battle of San Romano",
        "artist": "Paolo Uccello",
        "year": "c.1438–1440",
        "filename": "Paolo uccello, la battaglia di san romano, 1438-40 ca. 03.jpg",
        "orient": "landscape",
        "aspect": 323 / 182,
        "size": 1.8,
        "pos": (-10.0, 1.7, -2.0),
        "facing": "+X",
    },
    {
        "id": "monet_sunrise",
        "title_zh": "日出·印象",
        "title_en": "Impression, Sunrise",
        "artist": "Claude Monet",
        "year": "1872",
        "filename": "Claude Monet, Impression, soleil levant, 1872.jpg",
        "orient": "landscape",
        "aspect": 63 / 48,
        "size": 1.4,
        "pos": (11.8, 1.7, -7.5),
        "facing": "+Z",
    },
    {
        "id": "klimt_kiss",
        "title_zh": "吻",
        "title_en": "The Kiss",
        "artist": "Gustav Klimt",
        "year": "1908",
        "filename": "Gustav Klimt - The Kiss - Google Art Project.jpg",
        "alt_filenames": [
            "Gustav Klimt 017.jpg",
            "Klimt - The Kiss.jpg",
            "The Kiss - Gustav Klimt - Google Cultural Institute.jpg",
        ],
        "orient": "landscape",
        "aspect": 180 / 180,
        "size": 1.8,
        "pos": (-0.32, 1.7, -2.0),
        "facing": "+X",
    },
    {
        "id": "degas_dance",
        "title_zh": "舞蹈课",
        "title_en": "The Dance Class",
        "artist": "Edgar Degas",
        "year": "c.1874",
        "filename": "Edgar Degas - The Dance Class - WGA06073.jpg",
        "alt_filenames": [
            "Edgar Degas - The Ballet Class - Google Art Project.jpg",
            "Edgar Degas - La clase de danza.jpg",
            "Edgar Degas - The Dance Class - WGA.jpg",
            "Edgar Germain Hilaire Degas 011.jpg",
        ],
        "orient": "landscape",
        "aspect": 85 / 75,
        "size": 1.3,
        "pos": (-0.32, 1.7, 2.0),
        "facing": "+X",
    },
]

WALL_OFFSET_BACK = 0.01       # 画框离墙的后表面空隙
FRAME_DEPTH = 0.05             # 画框厚度
FRAME_MARGIN = 0.06            # 每边金框宽度
PAINTING_FORWARD_OFFSET = 0.01 # 画幅在画框前面探出的距离

# === 画作尺寸计算 ===
def dims_of(p):
    """返回 (w, h) 世界米。size 字段：landscape=宽度，portrait=高度。"""
    a = p["aspect"]
    s = p.get("size", 1.8 if p["orient"] == "landscape" else 1.2)
    if p["orient"] == "landscape":
        return s, s / a
    else:
        return s * a, s

HTTP_HEADERS = {"User-Agent": "BeautyGalleryDemo/1.0 (HarmonyOS student project)"}

import time

def _fetch_with_retry(url, timeout=120, max_retries=6):
    """带指数退避的 GET。返回 bytes。"""
    delay = 3
    for attempt in range(max_retries):
        try:
            req = urllib.request.Request(url, headers=HTTP_HEADERS)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < max_retries - 1:
                print(f"    429, retry in {delay}s...")
                time.sleep(delay)
                delay *= 2
                continue
            raise
        except (http.client.IncompleteRead, ConnectionResetError, TimeoutError,
                urllib.error.URLError, OSError) as e:
            if attempt < max_retries - 1:
                print(f"    network error ({type(e).__name__}), retry in {delay}s...")
                time.sleep(delay)
                delay *= 2
                continue
            raise

def resolve_wikimedia_url(filename):
    """通过 Wikimedia API 拿文件真实 URL。"""
    params = {
        "action": "query",
        "titles": f"File:{filename}",
        "prop": "imageinfo",
        "iiprop": "url",
        "format": "json"
    }
    api = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(api, headers=HTTP_HEADERS)
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read())
    pages = data.get("query", {}).get("pages", {})
    for pg in pages.values():
        info = pg.get("imageinfo")
        if info and info[0].get("url"):
            return info[0]["url"]
    return None

# === 下载 + 压缩 ===
def download_and_compress(p):
    out_path = os.path.join(PAINTINGS_DIR, f"{p['id']}.jpg")
    if os.path.exists(out_path):
        print(f"  [skip] {p['id']}.jpg already exists")
        return out_path
    print(f"  resolving {p['id']}...")
    # 尝试主文件名 + 备选文件名列表
    filenames = [p["filename"]]
    if p.get("alt_filenames"):
        filenames.extend(p["alt_filenames"])
    url = None
    for fn in filenames:
        try:
            url = resolve_wikimedia_url(fn)
            if url:
                print(f"    matched: {fn}")
                break
        except Exception:
            continue
    try:
        if url:
            print(f"    url: {url}")
            data = _fetch_with_retry(url)
            time.sleep(1.5)
            img = Image.open(BytesIO(data))
            if img.mode != "RGB":
                img = img.convert("RGB")
            w, h = img.size
            if max(w, h) > MAX_TEXTURE_SIDE:
                s = MAX_TEXTURE_SIDE / max(w, h)
                img = img.resize((int(w * s), int(h * s)), Image.LANCZOS)
            img.save(out_path, "JPEG", quality=JPEG_QUALITY, optimize=True)
            print(f"    saved -> {out_path}  ({os.path.getsize(out_path)//1024} KB, {img.size})")
            return out_path
        else:
            print(f"    Wikimedia resolve failed, using placeholder")
    except Exception as e:
        print(f"    download error ({e}), using placeholder")
    # 生成纯色占位图
    placeholder = Image.new("RGB", (512, 384), (
        hash(p["id"]) % 80 + 60,
        hash(p["id"] + "g") % 80 + 40,
        hash(p["id"] + "b") % 80 + 60
    ))
    placeholder.save(out_path, "JPEG", quality=85)
    print(f"    placeholder -> {out_path}  ({os.path.getsize(out_path)//1024} KB)")
    return out_path

# === 几何生成器 ===
def make_quad(w, h):
    """本地 XY 平面四边形，法线 +Z。返回 positions/normals/uvs/indices。"""
    w2, h2 = w / 2, h / 2
    positions = [
        -w2,  h2, 0,   # TL
        -w2, -h2, 0,   # BL
         w2, -h2, 0,   # BR
         w2,  h2, 0,   # TR
    ]
    normals = [0, 0, 1] * 4
    uvs = [0, 0,  0, 1,  1, 1,  1, 0]  # TL BL BR TR
    indices = [0, 1, 2,  0, 2, 3]
    return positions, normals, uvs, indices

def make_box(w, h, d):
    """本地坐标长方体，中心在原点。返回 positions/normals/indices（无 UV）。"""
    w2, h2, d2 = w / 2, h / 2, d / 2
    faces = [
        # (normal, [4 CCW verts from outside])
        ((0, 0, 1),  [(-w2, h2, d2), (-w2,-h2, d2), ( w2,-h2, d2), ( w2, h2, d2)]),   # front +Z
        ((0, 0,-1),  [( w2, h2,-d2), ( w2,-h2,-d2), (-w2,-h2,-d2), (-w2, h2,-d2)]),   # back -Z
        ((0, 1, 0),  [(-w2, h2,-d2), (-w2, h2, d2), ( w2, h2, d2), ( w2, h2,-d2)]),   # top +Y
        ((0,-1, 0),  [(-w2,-h2, d2), (-w2,-h2,-d2), ( w2,-h2,-d2), ( w2,-h2, d2)]),   # bot -Y
        ((1, 0, 0),  [( w2, h2, d2), ( w2,-h2, d2), ( w2,-h2,-d2), ( w2, h2,-d2)]),   # right +X
        ((-1,0, 0),  [(-w2, h2,-d2), (-w2,-h2,-d2), (-w2,-h2, d2), (-w2, h2, d2)]),   # left -X
    ]
    positions, normals, indices = [], [], []
    for i, (normal, verts) in enumerate(faces):
        base = i * 4
        for v in verts:
            positions.extend(v)
            normals.extend(normal)
        indices.extend([base, base+1, base+2, base, base+2, base+3])
    return positions, normals, indices

# === 朝向 → 四元数（围绕 Y 轴旋转）===
def rotation_for_facing(facing):
    """返回四元数 [x, y, z, w]，把 +Z 法线旋到 facing 方向。"""
    if facing == "+Z":
        return [0.0, 0.0, 0.0, 1.0]
    if facing == "+X":
        # 绕 Y 轴 +90°：+Z → +X
        return [0.0, math.sin(math.pi/4), 0.0, math.cos(math.pi/4)]
    if facing == "-Z":
        return [0.0, 1.0, 0.0, 0.0]
    if facing == "-X":
        return [0.0, -math.sin(math.pi/4), 0.0, math.cos(math.pi/4)]
    raise ValueError(f"unknown facing: {facing}")

# === 节点位置（画作 & 画框各自的世界中心）===
def compute_node_positions(p):
    """返回 (painting_center, frame_center)。"""
    cx, cy, cz = p["pos"]
    # 朝向对应的向外单位向量
    dirs = {"+Z": (0,0,1), "-Z": (0,0,-1), "+X": (1,0,0), "-X": (-1,0,0)}
    dx, dy, dz = dirs[p["facing"]]
    # 画框 back 面距墙 WALL_OFFSET_BACK，中心再外推 FRAME_DEPTH/2
    frame_off = WALL_OFFSET_BACK + FRAME_DEPTH / 2
    # 画幅中心在画框 front 面外推 PAINTING_FORWARD_OFFSET
    paint_off = WALL_OFFSET_BACK + FRAME_DEPTH + PAINTING_FORWARD_OFFSET
    painting_center = (cx + dx*paint_off, cy + dy*paint_off, cz + dz*paint_off)
    frame_center = (cx + dx*frame_off, cy + dy*frame_off, cz + dz*frame_off)
    return painting_center, frame_center

# === glTF 累加器 ===
class GltfBuilder:
    def __init__(self, gltf_doc):
        self.gltf = gltf_doc
        self.buf = bytearray()  # 新 binary buffer 数据

    def _pad4(self, alignment=4):
        while len(self.buf) % alignment != 0:
            self.buf.append(0)

    def add_float_array(self, arr, target=34962):
        """append float32 数组，返回 bufferView index（指向新 buffer）。"""
        self._pad4()
        offset = len(self.buf)
        self.buf.extend(struct.pack(f"<{len(arr)}f", *arr))
        bv = {
            "buffer": self._new_buffer_index(),
            "byteOffset": offset,
            "byteLength": len(arr) * 4,
            "target": target
        }
        self.gltf.setdefault("bufferViews", []).append(bv)
        return len(self.gltf["bufferViews"]) - 1

    def add_ushort_array(self, arr, target=34963):
        self._pad4(2)
        offset = len(self.buf)
        self.buf.extend(struct.pack(f"<{len(arr)}H", *arr))
        self._pad4()
        bv = {
            "buffer": self._new_buffer_index(),
            "byteOffset": offset,
            "byteLength": len(arr) * 2,
            "target": target
        }
        self.gltf.setdefault("bufferViews", []).append(bv)
        return len(self.gltf["bufferViews"]) - 1

    def _new_buffer_index(self):
        """返回本工具新增的 buffer 的索引。"""
        return self._buffer_idx

    def finalize_buffer(self):
        """把累积的 binary 编码为 base64 data URI，append 到 gltf.buffers。"""
        b64 = base64.b64encode(bytes(self.buf)).decode("ascii")
        self.gltf.setdefault("buffers", []).append({
            "uri": "data:application/octet-stream;base64," + b64,
            "byteLength": len(self.buf)
        })
        self._buffer_idx = len(self.gltf["buffers"]) - 1
        # 注意：上面先加 buffer 条目拿到 index，但之前我们已经 append 了 bufferView 引用 _new_buffer_index
        # 先调用顺序要反过来：add_* 前先 reserve 新 buffer 的 index。
        # 解决：在 __init__ 时预留 buffer 条目。

def reserve_new_buffer(gltf):
    """先占位一个空 buffer 条目，后面再填 uri。"""
    gltf.setdefault("buffers", []).append({"uri": "", "byteLength": 0})
    return len(gltf["buffers"]) - 1

# === 主流程 ===
def main():
    os.makedirs(PAINTINGS_DIR, exist_ok=True)

    # 备份
    if not os.path.exists(BACKUP_PATH):
        with open(GLTF_PATH) as f:
            orig = f.read()
        with open(BACKUP_PATH, "w") as f:
            f.write(orig)
        print(f"Backup saved → {BACKUP_PATH}")

    # 每次从 backup 恢复，重复跑不累加
    with open(BACKUP_PATH) as f:
        gltf = json.load(f)

    # 下载图片
    print("\n=== Downloading paintings ===")
    for p in PAINTINGS:
        p["_local_path"] = download_and_compress(p)

    # 为新增数据预留一个新 buffer
    new_buf_index = reserve_new_buffer(gltf)
    buf = bytearray()

    def pad4(al=4):
        while len(buf) % al != 0:
            buf.append(0)

    def append_floats(values, target):
        pad4()
        offset = len(buf)
        buf.extend(struct.pack(f"<{len(values)}f", *values))
        bv = {
            "buffer": new_buf_index,
            "byteOffset": offset,
            "byteLength": len(values) * 4,
            "target": target
        }
        gltf.setdefault("bufferViews", []).append(bv)
        return len(gltf["bufferViews"]) - 1

    def append_ushorts(values, target):
        pad4(2)
        offset = len(buf)
        buf.extend(struct.pack(f"<{len(values)}H", *values))
        pad4()
        bv = {
            "buffer": new_buf_index,
            "byteOffset": offset,
            "byteLength": len(values) * 2,
            "target": target
        }
        gltf.setdefault("bufferViews", []).append(bv)
        return len(gltf["bufferViews"]) - 1

    def append_accessor(bv_idx, count, type_str, component_type, mn=None, mx=None):
        acc = {
            "bufferView": bv_idx,
            "componentType": component_type,  # 5126 float, 5123 ushort
            "count": count,
            "type": type_str,
        }
        if mn is not None:
            acc["min"] = mn
        if mx is not None:
            acc["max"] = mx
        gltf.setdefault("accessors", []).append(acc)
        return len(gltf["accessors"]) - 1

    # 共享的金框材质
    frame_material_idx = len(gltf.setdefault("materials", []))
    gltf["materials"].append({
        "name": "painting_frame_gold",
        "pbrMetallicRoughness": {
            "baseColorFactor": [0.80, 0.60, 0.25, 1.0],
            "metallicFactor": 0.75,
            "roughnessFactor": 0.35
        },
        "doubleSided": True
    })

    # 共享的 sampler
    sampler_idx = len(gltf.setdefault("samplers", []))
    gltf["samplers"].append({
        "magFilter": 9729,  # LINEAR
        "minFilter": 9987,  # LINEAR_MIPMAP_LINEAR
        "wrapS": 33071,     # CLAMP_TO_EDGE（画作内容固定，不 repeat）
        "wrapT": 33071
    })

    scene_root_nodes = gltf["scenes"][0]["nodes"]

    print("\n=== Building meshes & nodes ===")
    for p in PAINTINGS:
        w, h = dims_of(p)
        painting_center, frame_center = compute_node_positions(p)
        quat = rotation_for_facing(p["facing"])

        # 画幅 quad
        pos, nml, uv, idx = make_quad(w, h)
        mins = [min(pos[0::3]), min(pos[1::3]), min(pos[2::3])]
        maxs = [max(pos[0::3]), max(pos[1::3]), max(pos[2::3])]
        pos_bv = append_floats(pos, 34962)
        nml_bv = append_floats(nml, 34962)
        uv_bv = append_floats(uv, 34962)
        idx_bv = append_ushorts(idx, 34963)
        pos_acc = append_accessor(pos_bv, 4, "VEC3", 5126, mins, maxs)
        nml_acc = append_accessor(nml_bv, 4, "VEC3", 5126)
        uv_acc = append_accessor(uv_bv, 4, "VEC2", 5126)
        idx_acc = append_accessor(idx_bv, 6, "SCALAR", 5123)

        # 贴图 image / texture / material
        img_idx = len(gltf.setdefault("images", []))
        gltf["images"].append({"uri": f"paintings/{p['id']}.jpg"})
        tex_idx = len(gltf.setdefault("textures", []))
        gltf["textures"].append({"source": img_idx, "sampler": sampler_idx})
        paint_mat_idx = len(gltf["materials"])
        gltf["materials"].append({
            "name": f"painting_{p['id']}",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": tex_idx},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.9
            },
            "doubleSided": True
        })

        # mesh
        mesh_idx = len(gltf.setdefault("meshes", []))
        gltf["meshes"].append({
            "name": f"painting_mesh_{p['id']}",
            "primitives": [{
                "attributes": {"POSITION": pos_acc, "NORMAL": nml_acc, "TEXCOORD_0": uv_acc},
                "indices": idx_acc,
                "material": paint_mat_idx
            }]
        })
        # node
        node_idx = len(gltf.setdefault("nodes", []))
        gltf["nodes"].append({
            "name": f"painting_node_{p['id']}",
            "mesh": mesh_idx,
            "translation": list(painting_center),
            "rotation": quat
        })
        scene_root_nodes.append(node_idx)

        # 画框 box
        fw = w + 2 * FRAME_MARGIN
        fh = h + 2 * FRAME_MARGIN
        fd = FRAME_DEPTH
        fpos, fnml, fidx = make_box(fw, fh, fd)
        fmins = [min(fpos[0::3]), min(fpos[1::3]), min(fpos[2::3])]
        fmaxs = [max(fpos[0::3]), max(fpos[1::3]), max(fpos[2::3])]
        fpos_bv = append_floats(fpos, 34962)
        fnml_bv = append_floats(fnml, 34962)
        fidx_bv = append_ushorts(fidx, 34963)
        fpos_acc = append_accessor(fpos_bv, 24, "VEC3", 5126, fmins, fmaxs)
        fnml_acc = append_accessor(fnml_bv, 24, "VEC3", 5126)
        fidx_acc = append_accessor(fidx_bv, 36, "SCALAR", 5123)
        fmesh_idx = len(gltf["meshes"])
        gltf["meshes"].append({
            "name": f"frame_mesh_{p['id']}",
            "primitives": [{
                "attributes": {"POSITION": fpos_acc, "NORMAL": fnml_acc},
                "indices": fidx_acc,
                "material": frame_material_idx
            }]
        })
        fnode_idx = len(gltf["nodes"])
        gltf["nodes"].append({
            "name": f"frame_node_{p['id']}",
            "mesh": fmesh_idx,
            "translation": list(frame_center),
            "rotation": quat
        })
        scene_root_nodes.append(fnode_idx)

        print(f"  {p['id']:<25} w={w:.2f} h={h:.2f}  center={tuple(round(v,2) for v in painting_center)}")

    # 填充 buffer
    b64 = base64.b64encode(bytes(buf)).decode("ascii")
    gltf["buffers"][new_buf_index] = {
        "uri": "data:application/octet-stream;base64," + b64,
        "byteLength": len(buf)
    }

    # 写回
    with open(GLTF_PATH, "w") as f:
        json.dump(gltf, f, separators=(",", ":"))  # 压缩 JSON
    size_kb = os.path.getsize(GLTF_PATH) // 1024
    print(f"\n=== Done ===")
    print(f"Wrote {GLTF_PATH}  ({size_kb} KB, buffer {len(buf)//1024} KB binary)")

if __name__ == "__main__":
    main()
