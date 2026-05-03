#!/usr/bin/env python3
"""
读取 white_cube glTF，将其纹理替换为 base64 data URI，输出单一自包含 JSON 文件。
输出的 JSON 可直接嵌入 HTML 作为 JavaScript 字符串。
"""
import base64
import json
import os
import sys

SCENE_DIR = os.path.join("entry", "src", "main", "resources", "rawfile", "gltf", "white_cube")
GLTF_PATH = os.path.join(SCENE_DIR, "scene.gltf")
TEX_DIR = os.path.join(SCENE_DIR, "textures")
OUT_PATH = os.path.join(SCENE_DIR, "scene_embedded.gltf")

def main():
    with open(GLTF_PATH, 'r', encoding='utf-8') as f:
        gltf = json.load(f)

    images = gltf.get('images', [])
    for img in images:
        uri = img.get('uri', '')
        if uri.startswith('textures/'):
            tex_path = os.path.join(SCENE_DIR, uri)
            if os.path.exists(tex_path):
                with open(tex_path, 'rb') as tf:
                    tex_bytes = tf.read()
                b64 = base64.b64encode(tex_bytes).decode('ascii')
                ext = os.path.splitext(uri)[1].lower()
                mime = 'image/png' if ext == '.png' else 'image/jpeg'
                img['uri'] = f'data:{mime};base64,{b64}'
                print(f"  Embedded: {uri} ({len(tex_bytes)} bytes)")

    with open(OUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(gltf, f)
    print(f"\nWrote: {OUT_PATH} ({len(json.dumps(gltf))} bytes)")

if __name__ == '__main__':
    main()
