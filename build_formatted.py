import json
import re

with open("tmp_products_full.json", "r", encoding="utf-8") as f:
    items = json.load(f)

formatted_products = {}

for item in items:
    cat = item["category"]
    group = item["group"]
    label = item["label"]
    doc_text = item["doc_text"]
    
    # Extract Title (usually line 1)
    lines = [line.strip() for line in doc_text.splitlines() if line.strip()]
    
    title = ""
    overview = ""
    specs = []
    
    if lines:
        title = lines[0]
        # Remove markdown headers if any
        title = re.sub(r'^[#*_\s]+', '', title)
        
        # Find Product Overview section
        overview_lines = []
        in_overview = False
        in_specs = False
        
        for line in lines[1:]:
            if "Product Overview" in line or "Overview" in line:
                in_overview = True
                in_specs = False
                continue
            elif "Product Specifications" in line or "Specifications" in line or "Key Features" in line:
                in_overview = False
                in_specs = True
                continue
            elif line.startswith("Product ") or line.startswith("Storage") or line.startswith("Usage"):
                in_overview = False
                in_specs = False
                
            if in_overview:
                overview_lines.append(line)
            elif in_specs:
                if line.startswith("*") or line.startswith("-") or ":" in line:
                    specs.append(line.lstrip("*- ").strip())
                    
        overview = " ".join(overview_lines)
        if not overview and len(lines) > 1:
            # Fallback to lines 1 to 4
            overview = " ".join([l for l in lines[1:5] if not l.startswith("*") and "Specification" not in l])
            
    # Clean title if label is richer
    if group:
        full_name = f"{group} — {label}" if label not in group and label not in ["1 mL", "2 mL", "100 mg", "200 mg", "300 mg", "10 mL", "50 U", "100 U", "200 U", "300 U", "500 U"] else (f"{group} {label}" if label in ["1 mL", "2 mL", "100 mg", "200 mg", "300 mg", "10 mL", "50 U", "100 U", "200 U", "300 U", "500 U"] else title)
    else:
        full_name = title or label
        
    if cat not in formatted_products:
        formatted_products[cat] = []
        
    slug = re.sub(r'[^a-z0-9]+', '-', full_name.lower()).strip('-')
    
    formatted_products[cat].append({
        "slug": slug,
        "name": title or full_name,
        "group": group,
        "label": label,
        "detail": overview,
        "specs": specs[:5]
    })

print("Categories and item counts:")
for cat, list_items in formatted_products.items():
    print(f"  {cat}: {len(list_items)} items")

with open("formatted_products.json", "w", encoding="utf-8") as f:
    json.dump(formatted_products, f, indent=2, ensure_ascii=False)
