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
import json
import math
import os
import struct
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
    # Zone A - 三杰（北墙 alcove 西侧 X=1 ~ 6）
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
        "pos": (5.0, 1.7, -7.5),
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
        "pos": (-1.0, 1.7, -7.5),
        "facing": "+Z",
    },
    {
        "id": "creation_of_adam",
        "title_zh": "创造亚当",
        "title_en": "The Creation of Adam",
        "artist": "Michelangelo",
        "year": "1508–1512",
        "filename": "Michelangelo - Creation of Adam (cropped).jpg",
        "orient": "landscape",
        "aspect": 1.6,
        "size": 2.1,
        "pos": (2.3, 1.7, -7.5),
        "facing": "+Z",
    },
    # Zone B - 威尼斯画派（北墙东段 X=[10.2, 16.95] 内）
    {
        "id": "venus_of_urbino",
        "title_zh": "乌尔比诺的维纳斯",
        "title_en": "Venus of Urbino",
        "artist": "Titian",
        "year": "1538",
        "filename": "Tiziano - Venere di Urbino - Google Art Project.jpg",
        "orient": "landscape",
        "aspect": 165 / 119,
        "size": 1.6,
        "pos": (11.8, 1.7, -7.5),
        "facing": "+Z",
    },
    {
        "id": "wedding_at_cana",
        "title_zh": "加纳的婚礼",
        "title_en": "The Wedding at Cana",
        "artist": "Veronese",
        "year": "1563",
        "filename": "Paolo Veronese 008.jpg",
        "orient": "landscape",
        "aspect": 994 / 677,
        "size": 1.6,
        "pos": (13.8, 1.7, -7.5),
        "facing": "+Z",
    },
    {
        "id": "tintoretto_last_supper",
        "title_zh": "最后的晚餐（圣乔治版）",
        "title_en": "The Last Supper (San Giorgio)",
        "artist": "Tintoretto",
        "year": "1592–1594",
        "filename": "Jacopo Tintoretto - The Last Supper - WGA22649.jpg",
        "orient": "landscape",
        "aspect": 568 / 365,
        "size": 1.6,
        "pos": (15.8, 1.7, -7.5),
        "facing": "+Z",
    },
    # Zone "盛期三杰之序曲" - 北墙西段新增（Leonardo + Raphael 两幅名作）
    {
        "id": "leonardo_last_supper",
        "title_zh": "最后的晚餐",
        "title_en": "The Last Supper",
        "artist": "Leonardo da Vinci",
        "year": "1495–1498",
        "filename": "Última Cena - Da Vinci 5.jpg",
        "orient": "landscape",
        "aspect": 880 / 460,
        "size": 2.5,
        "pos": (-7.0, 1.7, -7.5),
        "facing": "+Z",
    },
    {
        "id": "raphael_sistine_madonna",
        "title_zh": "西斯廷圣母",
        "title_en": "Sistine Madonna",
        "artist": "Raphael",
        "year": "1513–1514",
        "filename": "Raphael - The Sistine Madonna - Google Arts & Culture.jpg",
        "orient": "portrait",
        "aspect": 196 / 265,
        "size": 1.4,
        "pos": (-4.0, 1.7, -7.5),
        "facing": "+Z",
    },
    # Zone "西墙：早期文艺复兴与尼德兰"
    {
        "id": "birth_of_venus",
        "title_zh": "维纳斯的诞生",
        "title_en": "The Birth of Venus",
        "artist": "Sandro Botticelli",
        "year": "1485",
        "filename": "Sandro Botticelli - La nascita di Venere - Google Art Project - edited.jpg",
        "orient": "landscape",
        "aspect": 278.9 / 172.5,
        "size": 2.0,
        "pos": (-10.0, 1.7, -4.5),
        "facing": "+X",
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
        "pos": (-10.0, 1.7, -1.5),
        "facing": "+X",
    },
    {
        "id": "arnolfini_portrait",
        "title_zh": "阿尔诺芬尼夫妇像",
        "title_en": "The Arnolfini Portrait",
        "artist": "Jan van Eyck",
        "year": "1434",
        "filename": "Van Eyck - Arnolfini Portrait.jpg",
        "orient": "portrait",
        "aspect": 60 / 82,
        "size": 1.0,
        "pos": (-10.0, 1.7, 4.0),
        "facing": "+X",
    },
    # Zone "中央隔断东面" - 北方文艺复兴肖像
    {
        "id": "durer_self_portrait",
        "title_zh": "自画像（1500）",
        "title_en": "Self-Portrait",
        "artist": "Albrecht Dürer",
        "year": "1500",
        "filename": "Albrecht Dürer - 1500 self-portrait (High resolution and detail).jpg",
        "orient": "portrait",
        "aspect": 49 / 67,
        "size": 1.0,
        "pos": (-0.32, 1.5, -2.0),
        "facing": "+X",
    },
    {
        "id": "holbein_ambassadors",
        "title_zh": "大使们",
        "title_en": "The Ambassadors",
        "artist": "Hans Holbein the Younger",
        "year": "1533",
        "filename": "Hans Holbein the Younger - The Ambassadors - Google Art Project.jpg",
        "orient": "landscape",
        "aspect": 209.5 / 207,
        "size": 1.3,
        "pos": (-0.32, 1.6, 2.0),
        "facing": "+X",
    },
    # Zone "中央隔断西面" - 尼德兰风景叙事
    {
        "id": "bruegel_hunters_snow",
        "title_zh": "雪中猎人",
        "title_en": "Hunters in the Snow",
        "artist": "Pieter Bruegel the Elder",
        "year": "1565",
        "filename": "Pieter Bruegel the Elder - Hunters in the Snow (Winter) - Google Art Project.jpg",
        "orient": "landscape",
        "aspect": 162 / 117,
        "size": 1.8,
        "pos": (-0.69, 1.6, -2.0),
        "facing": "-X",
    },
    {
        "id": "bruegel_tower_of_babel",
        "title_zh": "巴别塔",
        "title_en": "The Tower of Babel",
        "artist": "Pieter Bruegel the Elder",
        "year": "1563",
        "filename": "Pieter Bruegel the Elder - The Tower of Babel (Vienna) - Google Art Project - edited.jpg",
        "orient": "landscape",
        "aspect": 155 / 114,
        "size": 1.8,
        "pos": (-0.69, 1.6, 2.0),
        "facing": "-X",
    },
    # 西墙添补：Leonardo 岩间圣母（Primavera 与 Arnolfini 之间）
    {
        "id": "virgin_of_the_rocks",
        "title_zh": "岩间圣母",
        "title_en": "Virgin of the Rocks",
        "artist": "Leonardo da Vinci",
        "year": "1483–1486",
        "filename": "Leonardo Da Vinci - Vergine delle Rocce (Louvre).jpg",
        "orient": "portrait",
        "aspect": 122 / 199,
        "size": 1.6,
        "pos": (-10.0, 1.7, 2.5),
        "facing": "+X",
    },
    # 南墙西段（入口门洞 X=3.6 以西）：威尼斯 + 帕多瓦 + Michelangelo + Raphael 四幅
    {
        "id": "titian_assumption",
        "title_zh": "圣母升天",
        "title_en": "Assumption of the Virgin",
        "artist": "Titian",
        "year": "1516–1518",
        "filename": "Tizian 041.jpg",
        "orient": "portrait",
        "aspect": 360 / 690,
        "size": 2.0,
        "pos": (-5.0, 1.7, 7.50),
        "facing": "-Z",
    },
    {
        "id": "mantegna_lamentation",
        "title_zh": "哀悼基督",
        "title_en": "Lamentation of Christ",
        "artist": "Andrea Mantegna",
        "year": "c.1480",
        "filename": "Andrea Mantegna - Lamentation of Christ - Pinacoteca di Brera (Milan).jpg",
        "orient": "landscape",
        "aspect": 81 / 68,
        "size": 1.2,
        "pos": (-3.0, 1.6, 7.50),
        "facing": "-Z",
    },
    {
        "id": "doni_tondo",
        "title_zh": "多尼圆形画（圣家族）",
        "title_en": "Doni Tondo",
        "artist": "Michelangelo",
        "year": "c.1506",
        "filename": "Tondo Doni by Michelangelo Buonarroti-Uffizi.jpg",
        "orient": "landscape",
        "aspect": 1.0,
        "size": 1.2,
        "pos": (-0.8, 1.7, 7.50),
        "facing": "-Z",
    },
    {
        "id": "raphael_transfiguration",
        "title_zh": "基督显圣",
        "title_en": "The Transfiguration",
        "artist": "Raphael",
        "year": "1516–1520",
        "filename": "Raphael - The Transfiguration - Google Art Project.jpg",
        "orient": "portrait",
        "aspect": 278 / 410,
        "size": 2.0,
        "pos": (1.4, 1.7, 7.50),
        "facing": "-Z",
    },
    # David 展台四围（面向游客可见的 E/W 面）：三杰作围绕米开朗琪罗雕像
    {
        "id": "caravaggio_david",
        "title_zh": "大卫与歌利亚的头颅",
        "title_en": "David with the Head of Goliath",
        "artist": "Caravaggio",
        "year": "c.1610",
        "filename": "Caravaggio - David with the Head of Goliath - Vienna.jpg",
        "orient": "portrait",
        "aspect": 101 / 125,
        "size": 1.4,
        "pos": (7.02, 1.7, -1.5),
        "facing": "-X",
    },
    {
        "id": "lady_with_ermine",
        "title_zh": "抱银貂的女子",
        "title_en": "Lady with an Ermine",
        "artist": "Leonardo da Vinci",
        "year": "c.1489",
        "filename": "Lady with an Ermine - Leonardo da Vinci - Google Art Project.jpg",
        "orient": "portrait",
        "aspect": 40.3 / 54.8,
        "size": 1.2,
        "pos": (7.02, 1.7, 1.5),
        "facing": "-X",
    },
    {
        "id": "raphael_madonna_meadow",
        "title_zh": "草地上的圣母",
        "title_en": "Madonna of the Meadow",
        "artist": "Raphael",
        "year": "1506",
        "filename": "Raphael - Madonna in the Meadow - Google Art Project.jpg",
        "orient": "portrait",
        "aspect": 88 / 113,
        "size": 1.4,
        "pos": (10.20, 1.7, 0.0),
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

def _fetch_with_retry(url, timeout=120, max_retries=4):
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
    url = resolve_wikimedia_url(p["filename"])
    if not url:
        raise RuntimeError(f"cannot resolve Wikimedia URL for: {p['filename']}")
    print(f"    url: {url}")
    data = _fetch_with_retry(url)
    time.sleep(1.5)  # 下载间隔，规避 Wikimedia 速率限制
    img = Image.open(BytesIO(data))
    if img.mode != "RGB":
        img = img.convert("RGB")
    w, h = img.size
    if max(w, h) > MAX_TEXTURE_SIDE:
        s = MAX_TEXTURE_SIDE / max(w, h)
        img = img.resize((int(w * s), int(h * s)), Image.LANCZOS)
    img.save(out_path, "JPEG", quality=JPEG_QUALITY, optimize=True)
    print(f"    saved → {out_path}  ({os.path.getsize(out_path)//1024} KB, {img.size})")
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
