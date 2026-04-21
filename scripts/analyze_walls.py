#!/usr/bin/env python3
"""
Dump every axis-aligned wall surface in the David model.

读 scene.gltf.orig（合并画作前的原始模型），抓 "walls" mesh 的三角形，
把所有顶点经由节点矩阵变换到世界空间，然后按法线+平面 offset 分组，
列出每段墙在哪个平面、X/Z/Y 覆盖范围是什么。

目的：搞清楚 David alcove 的实际几何，以便在 Waypoint.ets 里正确建模
alcove 两侧"伸出的墙体"（现在的 david_enclosure 只模了南半截 pedestal）。
"""
import base64
import json
import os
import struct
from collections import defaultdict

GLTF = os.path.join("entry", "src", "main", "resources", "rawfile", "gltf",
                    "David", "scene.gltf.orig")

def mul_mat(a, b):
    r = [0.0] * 16
    for i in range(4):
        for j in range(4):
            r[i * 4 + j] = sum(a[i * 4 + k] * b[k * 4 + j] for k in range(4))
    return r

def trs_matrix(node):
    t = node.get("translation", [0, 0, 0])
    r = node.get("rotation", [0, 0, 0, 1])
    s = node.get("scale", [1, 1, 1])
    x, y, z, w = r
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z
    rot = [
        1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy), 0,
        2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx), 0,
        2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy), 0,
        0, 0, 0, 1,
    ]
    scl = [s[0], 0, 0, 0, 0, s[1], 0, 0, 0, 0, s[2], 0, 0, 0, 0, 1]
    tr = [1, 0, 0, t[0], 0, 1, 0, t[1], 0, 0, 1, t[2], 0, 0, 0, 1]
    return mul_mat(tr, mul_mat(rot, scl))

def apply_mat(m, v):
    x = m[0] * v[0] + m[1] * v[1] + m[2] * v[2] + m[3]
    y = m[4] * v[0] + m[5] * v[1] + m[6] * v[2] + m[7]
    z = m[8] * v[0] + m[9] * v[1] + m[10] * v[2] + m[11]
    return [x, y, z]

def build_world_mats(gltf):
    """Return list of world matrix per node (by node index)."""
    nodes = gltf["nodes"]
    world = [None] * len(nodes)

    def visit(idx, parent):
        local = trs_matrix(nodes[idx])
        w = mul_mat(parent, local) if parent else local
        world[idx] = w
        for c in nodes[idx].get("children", []):
            visit(c, w)

    identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    for scene in gltf.get("scenes", []):
        for root in scene.get("nodes", []):
            visit(root, identity)
    return world

def load_buffer(gltf, base_dir):
    buf = gltf["buffers"][0]
    uri = buf["uri"]
    if uri.startswith("data:"):
        b64 = uri.split(",", 1)[1]
        return base64.b64decode(b64)
    with open(os.path.join(base_dir, uri), "rb") as f:
        return f.read()

def accessor_data(gltf, buf, acc_idx):
    acc = gltf["accessors"][acc_idx]
    bv = gltf["bufferViews"][acc["bufferView"]]
    offset = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    count = acc["count"]
    ctype = acc["componentType"]
    typ = acc["type"]
    comp_map = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
    comps = comp_map[typ]
    ctype_map = {
        5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2),
        5125: ("I", 4), 5126: ("f", 4),
    }
    fmt_char, sz = ctype_map[ctype]
    stride = bv.get("byteStride", comps * sz)
    out = []
    for i in range(count):
        base = offset + i * stride
        if comps == 1:
            out.append(struct.unpack_from("<" + fmt_char, buf, base)[0])
        else:
            out.append(list(struct.unpack_from("<" + fmt_char * comps, buf, base)))
    return out

def main():
    with open(GLTF) as f:
        gltf = json.load(f)
    base_dir = os.path.dirname(GLTF)
    buf = load_buffer(gltf, base_dir)
    world = build_world_mats(gltf)

    # find mesh usage: map mesh_idx → [node_idx] so we know the world matrix
    mesh_owner = {}
    for i, n in enumerate(gltf["nodes"]):
        if "mesh" in n:
            mesh_owner.setdefault(n["mesh"], []).append(i)

    # find all meshes whose name contains "wall"
    target_meshes = []
    for i, m in enumerate(gltf["meshes"]):
        name = m.get("name", "").lower()
        if "wall" in name or "floor" in name or name == "stair":
            target_meshes.append((i, name))

    print("=== Candidate meshes ===")
    for i, n in target_meshes:
        print(f"  [{i}] {n}")
    print()

    # group triangles by (normal, plane-offset)
    # bucket by rounding normal to 3 decimals and offset to 2 decimals
    buckets = defaultdict(lambda: {"x": [], "y": [], "z": []})

    for mesh_idx, mname in target_meshes:
        nodes_using = mesh_owner.get(mesh_idx, [])
        for nidx in nodes_using:
            wm = world[nidx]
            for prim in gltf["meshes"][mesh_idx]["primitives"]:
                pos_acc = prim["attributes"]["POSITION"]
                idx_acc = prim.get("indices")
                positions = accessor_data(gltf, buf, pos_acc)
                if idx_acc is not None:
                    indices = accessor_data(gltf, buf, idx_acc)
                else:
                    indices = list(range(len(positions)))
                # transform to world
                wpos = [apply_mat(wm, p) for p in positions]
                for t in range(0, len(indices), 3):
                    a = wpos[indices[t]]
                    b = wpos[indices[t + 1]]
                    c = wpos[indices[t + 2]]
                    # normal = (b-a) x (c-a), normalized
                    ux, uy, uz = b[0]-a[0], b[1]-a[1], b[2]-a[2]
                    vx, vy, vz = c[0]-a[0], c[1]-a[1], c[2]-a[2]
                    nx = uy*vz - uz*vy
                    ny = uz*vx - ux*vz
                    nz = ux*vy - uy*vx
                    L = (nx*nx + ny*ny + nz*nz) ** 0.5
                    if L < 1e-8:
                        continue
                    nx /= L; ny /= L; nz /= L

                    # only interested in axis-aligned walls: one of |n| ≈ 1
                    axis = None
                    if abs(nx) > 0.97: axis = "X"
                    elif abs(ny) > 0.97: axis = "Y"
                    elif abs(nz) > 0.97: axis = "Z"
                    if axis is None:
                        continue
                    if axis == "X":
                        offset = (a[0] + b[0] + c[0]) / 3
                        key = ("X", round(nx), round(offset, 2))
                    elif axis == "Y":
                        offset = (a[1] + b[1] + c[1]) / 3
                        key = ("Y", round(ny), round(offset, 2))
                    else:
                        offset = (a[2] + b[2] + c[2]) / 3
                        key = ("Z", round(nz), round(offset, 2))
                    buckets[key]["x"].extend([a[0], b[0], c[0]])
                    buckets[key]["y"].extend([a[1], b[1], c[1]])
                    buckets[key]["z"].extend([a[2], b[2], c[2]])

    # print sorted: Z walls (running along X) first, then X walls (running along Z), then floors/ceilings
    print("=== Axis-aligned wall surfaces (Z-walls run E-W, X-walls run N-S) ===\n")

    def sec(axis_code):
        label = {
            "X": "X-PLANE walls (run along Z)",
            "Y": "Y-PLANE surfaces (floors/ceilings)",
            "Z": "Z-PLANE walls (run along X)",
        }[axis_code]
        print(f"-- {label} --")
        entries = [(k, v) for k, v in buckets.items() if k[0] == axis_code]
        # sort by offset
        entries.sort(key=lambda kv: kv[0][2])
        for (ax, sign, off), ext in entries:
            xs = ext["x"]; ys = ext["y"]; zs = ext["z"]
            minx, maxx = min(xs), max(xs)
            miny, maxy = min(ys), max(ys)
            minz, maxz = min(zs), max(zs)
            facing = "+" if sign > 0 else "-"
            print(f"  {ax}={off:+.2f} facing {facing}{ax}  "
                  f"X=[{minx:+.2f},{maxx:+.2f}]  "
                  f"Y=[{miny:+.2f},{maxy:+.2f}]  "
                  f"Z=[{minz:+.2f},{maxz:+.2f}]  "
                  f"tris≈{len(xs)//3}")
        print()

    sec("Z")
    sec("X")
    sec("Y")

if __name__ == "__main__":
    main()
