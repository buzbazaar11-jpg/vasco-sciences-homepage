import json

with open("tmp_products_full.json", "r", encoding="utf-8") as f:
    data = json.load(f)

print(f"Total products loaded: {len(data)}")
for i in range(min(5, len(data))):
    item = data[i]
    print(f"\n--- Item {i+1}: {item['label']} (Category: {item['category']}, Group: {item['group']}) ---")
    lines = item['doc_text'].splitlines()
    print("First 8 lines:")
    for l in lines[:8]:
        print("  ", l)
