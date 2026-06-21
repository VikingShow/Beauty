"""
Download 12 Chinese painting images from Wikimedia Commons.
Uses proper thumbnail URL pattern to avoid rate limiting.
Waits 3s between requests per Wikimedia policy.
"""
import urllib.request
import ssl
import os
import time

OUT_DIR = os.path.join(os.path.dirname(__file__), '..',
    'entry/src/main/resources/rawfile/gltf/chinese_gallery/paintings')

HEADERS = {
    'User-Agent': 'ArTree/1.0 (educational art gallery app) Mozilla/5.0',
}

# Wikimedia Commons filenames (URL-encoded)
FILES = {
    'qianli_jiangshan': '%E5%8D%83%E9%87%8C%E6%B1%9F%E5%B1%B1%E5%9B%BE.jpg',
    'fuchun_shanju': 'Huang_Gongwang_-_Dwelling_in_the_Fuchun_Mountains_%28Remaining_Mountain%29.jpg',
    'xishan_xinglv': 'Fan_Kuan_-_Travelers_Among_Mountains_and_Streams.jpg',
    'xiao_xiang': 'Dong_Yuan_-_Xiao_and_Xiang_Rivers.jpg',
    'zaochun': 'Guo_Xi_-_Early_Spring_%28Google_Art_Project%29.jpg',
    'luoshen_fu': 'Gu_Kaizhi_-_Nymph_of_the_Luo_River.jpg',
    'hanxizai_yeyan': 'Gu_Hongzhong%27s_Night_Revels_1.jpg',
    'zanhua_shinv': 'Zhou_Fang._Court_Ladies_Wearing_Flowered_Headdresses._%28Copy%29.jpg',
    'wuniu': 'Han_Huang_-_Five_Oxen.jpg',
    'lushan_gao': 'Shen_Zhou._Lofty_Mount_Lu._1467.%28Palace_Museum%29.jpg',
    'mo_putao': 'Xu_Wei_-_Ink_Grapes.jpg',
    'bada_shanren_lotus': 'Bada_Shanren_-_Lotus_and_Birds.jpg',
}

BASE = 'https://upload.wikimedia.org/wikipedia/commons/'

def download_one(exhibit_id, filename, width=2048):
    """Download using special:FilePath redirect with thumbnail size."""
    out_path = os.path.join(OUT_DIR, f"{exhibit_id}.jpg")

    # Try special:FilePath redirect (works with rate limits better)
    urls = [
        # Special FilePath redirect - more rate-limit friendly
        f'https://commons.wikimedia.org/wiki/Special:FilePath/{filename}?width={width}',
        # Direct URL as fallback
        f'{BASE}{filename[0]}/{filename}',
    ]

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    for url in urls:
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            resp = urllib.request.urlopen(req, timeout=120, context=ctx)
            data = resp.read()
            if len(data) > 10000:
                with open(out_path, 'wb') as f:
                    f.write(data)
                return len(data)
            else:
                print(f"    Too small: {len(data)} bytes from {url[:80]}")
        except Exception as e:
            print(f"    Error: {e}")
            time.sleep(1)
    return 0

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0

    for exhibit_id, filename in FILES.items():
        out_path = os.path.join(OUT_DIR, f"{exhibit_id}.jpg")
        if os.path.exists(out_path) and os.path.getsize(out_path) > 10000:
            kb = os.path.getsize(out_path) // 1024
            print(f"  [{total+1}/12] {exhibit_id}: exists ({kb}KB)")
            total += 1
            continue

        print(f"  [{total+1}/12] {exhibit_id}: downloading...")
        size = download_one(exhibit_id, filename)
        if size > 0:
            print(f"    OK {size//1024}KB")
            total += 1
        else:
            print(f"    FAILED")

        # Respect rate limit - 3s between requests
        if total < 12:
            time.sleep(3)

    print(f"\nDone: {total}/12 paintings downloaded to {OUT_DIR}")

if __name__ == '__main__':
    main()
