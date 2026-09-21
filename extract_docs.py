import re
import os
import urllib.request
import urllib.parse
from html.parser import HTMLParser
import json

sitemap_path = r"C:\Users\JalipEmpire\.gemini\antigravity\brain\f5f78a70-1b37-445c-bd57-e6936d36322f\.system_generated\steps\21\content.md"

with open(sitemap_path, "r", encoding="utf-8") as f:
    text = f.read()

# Pattern for Google Doc URLs
# [Text](https://www.google.com/url?q=https://docs.google.com/document/d/DOC_ID/edit...)
pattern = r'\[([^\]]+)\]\(https://www\.google\.com/url\?q=https://docs\.google\.com/document/d/([a-zA-Z0-9_-]+)'

matches = re.findall(pattern, text)
print(f"Found {len(matches)} product links.")

# Create assets directory if not exists
assets_dir = r"c:\Users\JalipEmpire\Downloads\New folder (11)\vesco-vision - Copy\public\products"
os.makedirs(assets_dir, exist_ok=True)

products_data = []

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}

for idx, (label, doc_id) in enumerate(matches):
    print(f"[{idx+1}/{len(matches)}] Fetching: {label} ({doc_id})")
    txt_url = f"https://docs.google.com/document/d/{doc_id}/export?format=txt"
    html_url = f"https://docs.google.com/document/d/{doc_id}/export?format=html"
    
    doc_text = ""
    try:
        req = urllib.request.Request(txt_url, headers=headers)
        with urllib.request.urlopen(req) as resp:
            doc_text = resp.read().decode('utf-8-sig', errors='ignore').strip()
    except Exception as e:
        print(f"  Error fetching txt for {doc_id}: {e}")
        
    doc_html = ""
    img_urls = []
    try:
        req = urllib.request.Request(html_url, headers=headers)
        with urllib.request.urlopen(req) as resp:
            doc_html = resp.read().decode('utf-8-sig', errors='ignore')
            # extract img src
            img_urls = re.findall(r'<img[^>]+src=["\']([^"\']+)["\']', doc_html)
    except Exception as e:
        print(f"  Error fetching html for {doc_id}: {e}")
        
    # Download images if any
    saved_images = []
    for img_idx, img_url in enumerate(img_urls):
        if "googleusercontent.com" in img_url or "google.com" in img_url or img_url.startswith("http"):
            img_filename = f"prod_{doc_id}_{img_idx}.png"
            img_filepath = os.path.join(assets_dir, img_filename)
            try:
                img_req = urllib.request.Request(img_url, headers=headers)
                with urllib.request.urlopen(img_req) as resp:
                    with open(img_filepath, "wb") as out_img:
                        out_img.write(resp.read())
                saved_images.append(f"/products/{img_filename}")
            except Exception as e:
                print(f"  Failed to download image {img_url}: {e}")
                
    products_data.append({
        "id": doc_id,
        "label": label,
        "text": doc_text,
        "images": saved_images
    })

out_json = r"c:\Users\JalipEmpire\Downloads\New folder (11)\vesco-vision - Copy\tmp_products.json"
with open(out_json, "w", encoding="utf-8") as f:
    json.dump(products_data, f, indent=2, ensure_ascii=False)

print("Finished fetching all products.")
