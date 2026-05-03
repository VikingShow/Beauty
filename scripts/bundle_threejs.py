#!/usr/bin/env python3
"""Download Three.js ESM builds to rawfile/web/js/"""
import os
import urllib.request

WEB_DIR = os.path.join("entry", "src", "main", "resources", "rawfile", "web", "js")
os.makedirs(WEB_DIR, exist_ok=True)

THREE_ESM = "https://unpkg.com/three@0.160.0/build/three.module.js"
GLTF_LOADER = "https://unpkg.com/three@0.160.0/examples/jsm/loaders/GLTFLoader.js"

def get(url, name):
    path = os.path.join(WEB_DIR, name)
    print(f"Downloading {url} ...")
    urllib.request.urlretrieve(url, path)
    size = os.path.getsize(path)
    print(f"  -> {path} ({size:,} bytes)")

get(THREE_ESM, "three.module.js")
get(GLTF_LOADER, "GLTFLoader.js")
print("\nDone! Now update index.html importmap to use local paths.")
