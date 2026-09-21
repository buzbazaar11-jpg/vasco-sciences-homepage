import json

with open("formatted_products.json", "r", encoding="utf-8") as f:
    data = json.load(f)

for cat in data:
    print(f"\n=================== {cat.upper()} ===================")
    for p in data[cat][:3]:
        print(f"Name: {p['name']}")
        print(f"Group: {p['group']}")
        print(f"Detail: {p['detail'][:150]}...")
        print(f"Specs: {p['specs']}")
        print("-")
