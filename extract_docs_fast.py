import re
import os
import urllib.request
import json
from concurrent.futures import ThreadPoolExecutor

sitemap_path = r"C:\Users\JalipEmpire\.gemini\antigravity\brain\f5f78a70-1b37-445c-bd57-e6936d36322f\.system_generated\steps\21\content.md"

with open(sitemap_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

assets_dir = r"c:\Users\JalipEmpire\Downloads\New folder (11)\vesco-vision - Copy\public\products"
os.makedirs(assets_dir, exist_ok=True)

current_category = ""
current_platform_or_collab = ""
current_group = ""

parsed_items = []

cat_mapping = {
    "01. EXOSOMES": "exosome",
    "02. DERMAL FILLERS": "dermal-fillers",
    "03. PEPTIDE-BASED BIO-REMODELING": "peptide-bio-remodeling",
    "04. Botulinum Toxin": "botulinum-toxin",
    "05. PDRN / PN SOLUTIONS": "pdrn-pn"
}

for line in lines:
    clean_line = line.strip()
    if "01. EXOSOMES" in clean_line:
        current_category = "exosome"
        current_group = ""
    elif "02. DERMAL FILLERS" in clean_line:
        current_category = "dermal-fillers"
        current_group = ""
    elif "03. PEPTIDE-BASED BIO-REMODELING" in clean_line:
        current_category = "peptide-bio-remodeling"
        current_group = ""
    elif "04. Botulinum Toxin" in clean_line:
        current_category = "botulinum-toxin"
        current_group = ""
    elif "05. PDRN / PN SOLUTIONS" in clean_line:
        current_category = "pdrn-pn"
        current_group = ""
    
    # Check for group headings like Lyophilized hUC-MSC Exosomes, ExoGenesis™, etc.
    # Lines that look like ├── Group or └── Group or without links
    link_match = re.search(r'\[([^\]]+)\]\(https://www\.google\.com/url\?q=https://docs\.google\.com/document/d/([a-zA-Z0-9_-]+)', line)
    
    if link_match:
        label = link_match.group(1).strip()
        doc_id = link_match.group(2).strip()
        parsed_items.append({
            "category": current_category,
            "group": current_group,
            "label": label,
            "doc_id": doc_id,
            "line": line.strip()
        })
    else:
        # It might be a group title
        # strip tree chars ├── └── │
        sub_title = re.sub(r'^[│├└──\s\xa0]+', '', line).strip()
        if sub_title and not sub_title.startswith("PRODUCTS:") and not sub_title.startswith("VESCO SCIENCE") and not sub_title.startswith("A. ") and not sub_title.startswith("B. ") and not sub_title.startswith("0"):
            current_group = sub_title

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}

def process_item(item):
    doc_id = item["doc_id"]
    label = item["label"]
    txt_url = f"https://docs.google.com/document/d/{doc_id}/export?format=txt"
    html_url = f"https://docs.google.com/document/d/{doc_id}/export?format=html"
    
    doc_text = ""
    try:
        req = urllib.request.Request(txt_url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            doc_text = resp.read().decode('utf-8-sig', errors='ignore').strip()
    except Exception as e:
        print(f"Error txt {label} ({doc_id}): {e}")
        
    img_urls = []
    try:
        req = urllib.request.Request(html_url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            doc_html = resp.read().decode('utf-8-sig', errors='ignore')
            img_urls = re.findall(r'<img[^>]+src=["\']([^"\']+)["\']', doc_html)
    except Exception as e:
        print(f"Error html {label} ({doc_id}): {e}")
        
    saved_images = []
    for img_idx, img_url in enumerate(img_urls):
        if ("googleusercontent.com" in img_url or "google.com" in img_url or img_url.startswith("http")) and "cleardot.gif" not in img_url:
            img_filename = f"prod_{doc_id}_{img_idx}.png"
            img_filepath = os.path.join(assets_dir, img_filename)
            try:
                img_req = urllib.request.Request(img_url, headers=headers)
                with urllib.request.urlopen(img_req, timeout=10) as resp:
                    with open(img_filepath, "wb") as out_img:
                        out_img.write(resp.read())
                saved_images.append(f"/products/{img_filename}")
            except Exception as e:
                pass
                
    item["doc_text"] = doc_text
    item["images"] = saved_images
    print(f"Done: {label} ({len(doc_text)} chars, {len(saved_images)} imgs)")
    return item

print(f"Processing {len(parsed_items)} items in parallel...")
with ThreadPoolExecutor(max_workers=15) as executor:
    results = list(executor.map(process_item, parsed_items))

out_json = r"c:\Users\JalipEmpire\Downloads\New folder (11)\vesco-vision - Copy\tmp_products_full.json"
with open(out_json, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)

print("COMPLETE!")
