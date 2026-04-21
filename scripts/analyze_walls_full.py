#!/usr/bin/env python3
"""
List EVERY wall in walls mesh, not just axis-aligned ones.
Group by (normal direction rounded to 0.05, plane offset rounded to 0.1).
Vertical walls are those whose normal has |z| < 0.5 (Z is up in model space).

Output sorted by triangle count desc so big walls appear first.
"""
import base64, json, os, struct
from collections import defaultdict

GLTF = os.path.join("entry", "src", "main", "resources", "rawfile",
                    "gltf", "David", "scene.gltf.orig")

def mul_mat(a, b):
    r = [0.0]*16
    for i in range(4):
        for j in range(4):
            r[i*4+j] = sum(a[i*4+k]*b[k*4+j] for k in range(4))
    return r

def trs_matrix(node):
    t = node.get("translation",[0,0,0]); r = node.get("rotation",[0,0,0,1]); s = node.get("scale",[1,1,1])
    x,y,z,w = r
    xx,yy,zz=x*x,y*y,z*z; xy,xz,yz=x*y,x*z,y*z; wx,wy,wz=w*x,w*y,w*z
    rot=[1-2*(yy+zz),2*(xy-wz),2*(xz+wy),0, 2*(xy+wz),1-2*(xx+zz),2*(yz-wx),0, 2*(xz-wy),2*(yz+wx),1-2*(xx+yy),0, 0,0,0,1]
    scl=[s[0],0,0,0, 0,s[1],0,0, 0,0,s[2],0, 0,0,0,1]
    tr=[1,0,0,t[0], 0,1,0,t[1], 0,0,1,t[2], 0,0,0,1]
    return mul_mat(tr, mul_mat(rot, scl))

def apply_mat(m, v):
    return [m[0]*v[0]+m[1]*v[1]+m[2]*v[2]+m[3], m[4]*v[0]+m[5]*v[1]+m[6]*v[2]+m[7], m[8]*v[0]+m[9]*v[1]+m[10]*v[2]+m[11]]

def build_world_mats(g):
    nodes=g["nodes"]; world=[None]*len(nodes)
    def visit(i,p):
        l=trs_matrix(nodes[i]); w=mul_mat(p,l) if p else l; world[i]=w
        for c in nodes[i].get("children",[]): visit(c,w)
    I=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
    for sc in g.get("scenes",[]):
        for r in sc.get("nodes",[]): visit(r, I)
    return world

def load_buffer(g, base):
    b = g["buffers"][0]
    if b["uri"].startswith("data:"): return base64.b64decode(b["uri"].split(",",1)[1])
    return open(os.path.join(base, b["uri"]),"rb").read()

def accessor_data(g, buf, idx):
    a=g["accessors"][idx]; bv=g["bufferViews"][a["bufferView"]]
    off=bv.get("byteOffset",0)+a.get("byteOffset",0); cnt=a["count"]; ct=a["componentType"]; ty=a["type"]
    cm={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}; comps=cm[ty]
    cmap={5120:("b",1),5121:("B",1),5122:("h",2),5123:("H",2),5125:("I",4),5126:("f",4)}
    f,sz=cmap[ct]; stride=bv.get("byteStride",comps*sz); out=[]
    for i in range(cnt):
        b=off+i*stride
        if comps==1: out.append(struct.unpack_from("<"+f, buf, b)[0])
        else: out.append(list(struct.unpack_from("<"+f*comps, buf, b)))
    return out

def main():
    g = json.load(open(GLTF))
    base = os.path.dirname(GLTF)
    buf = load_buffer(g, base)
    world = build_world_mats(g)
    mesh_owner = {}
    for i,n in enumerate(g["nodes"]):
        if "mesh" in n: mesh_owner.setdefault(n["mesh"],[]).append(i)

    target_idxs = []
    for i,m in enumerate(g["meshes"]):
        nm = m.get("name","").lower()
        if "wall" in nm or "ceiling" in nm:
            target_idxs.append(i)
    for i in target_idxs:
        print(f"  using mesh [{i}] {g['meshes'][i]['name']}")
    print()

    # bucket by (rounded normal x/y/z, rounded plane offset)
    # plane offset = (a + b + c)/3 dot normal
    buckets = defaultdict(lambda: {"x":[],"y":[],"z":[], "n": (0,0,0)})

    for tgt in target_idxs:
     for nidx in mesh_owner.get(tgt, []):
        wm = world[nidx]
        for prim in g["meshes"][tgt]["primitives"]:
            pos = accessor_data(g, buf, prim["attributes"]["POSITION"])
            idx = accessor_data(g, buf, prim["indices"]) if "indices" in prim else list(range(len(pos)))
            wpos = [apply_mat(wm, p) for p in pos]
            for t in range(0, len(idx), 3):
                a = wpos[idx[t]]; b = wpos[idx[t+1]]; c = wpos[idx[t+2]]
                ux,uy,uz=b[0]-a[0],b[1]-a[1],b[2]-a[2]
                vx,vy,vz=c[0]-a[0],c[1]-a[1],c[2]-a[2]
                nx=uy*vz-uz*vy; ny=uz*vx-ux*vz; nz=ux*vy-uy*vx
                L=(nx*nx+ny*ny+nz*nz)**0.5
                if L<1e-8: continue
                nx/=L; ny/=L; nz/=L
                # only VERTICAL walls (normal mostly horizontal)
                if abs(nz) > 0.5: continue
                # round normal to 0.1 (so similar normals group)
                rnx = round(nx*10)/10; rny = round(ny*10)/10
                # plane offset along normal
                cx,cy,cz=(a[0]+b[0]+c[0])/3,(a[1]+b[1]+c[1])/3,(a[2]+b[2]+c[2])/3
                d = cx*rnx + cy*rny
                rd = round(d, 1)
                key = (rnx, rny, rd)
                buckets[key]["x"].extend([a[0],b[0],c[0]])
                buckets[key]["y"].extend([a[1],b[1],c[1]])
                buckets[key]["z"].extend([a[2],b[2],c[2]])
                buckets[key]["n"] = (rnx, rny, 0)

    # Print sorted by triangle count desc
    rows = []
    for k,v in buckets.items():
        ntris = len(v["x"]) // 3
        xs,ys,zs = v["x"],v["y"],v["z"]
        rows.append((ntris, k, min(xs),max(xs), min(ys),max(ys), min(zs),max(zs)))
    rows.sort(reverse=True)
    print(f"{'tris':>4}  {'nx':>5} {'ny':>5} {'d':>6}    X-range            Y-range            Z-range")
    for ntris, (rnx,rny,rd), xmin,xmax, ymin,ymax, zmin,zmax in rows:
        if ntris < 2: continue  # skip tiny scraps
        print(f"{ntris:>4}  {rnx:>+5.1f} {rny:>+5.1f} {rd:>+6.1f}  X[{xmin:+6.2f},{xmax:+6.2f}]  "
              f"Y[{ymin:+6.2f},{ymax:+6.2f}]  Z[{zmin:+6.2f},{zmax:+6.2f}]")

if __name__ == "__main__":
    main()
