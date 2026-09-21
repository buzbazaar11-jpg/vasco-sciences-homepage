import json
import re

with open("formatted_products.json", "r", encoding="utf-8") as f:
    data = json.load(f)

ts_content = """// Auto-generated product database extracted directly from official Google Doc sitemap

export type ProductDetailItem = {
  slug: string;
  name: string;
  group: string;
  label: string;
  detail: string;
  specs: string[];
};

export type CategoryMeta = {
  num: string;
  title: string;
  description: string;
  count: number;
};

export const CATEGORY_META: Record<string, CategoryMeta> = {
  exosome: {
    num: "01",
    title: "Exosomes",
    description: "Lyophilized hUC-MSC exosome platforms, scalp and vital diluents, and branded collaboration kits for professional regenerative applications. Every format is produced under controlled conditions with full batch documentation.",
    count: 27,
  },
  "dermal-fillers": {
    num: "02",
    title: "Dermal Fillers",
    description: "Small and large-molecular hyaluronic acid fillers in multiple concentrations, alongside Hyalique-X and Luminelle™ branded collaboration formats for professional aesthetic and regenerative applications.",
    count: 17,
  },
  "peptide-bio-remodeling": {
    num: "03",
    title: "Peptide-Based Bio-Remodeling",
    description: "Blue copper peptide platforms in 100 mg, 200 mg and 300 mg formats, paired with HA diluent. BlueVive Booster and CuveraX™ are branded collaboration products for professional bio-remodeling use.",
    count: 7,
  },
  "botulinum-toxin": {
    num: "04",
    title: "Botulinum Toxin",
    description: "Botulinum toxin in 50 U to 500 U formats, alongside Botivex and Toxexa branded collaboration products. Manufactured under aseptic conditions with full quality documentation per batch.",
    count: 10,
  },
  "pdrn-pn": {
    num: "05",
    title: "PDRN / PN Solutions",
    description: "PDRN and PN injectable solutions including combination HA formats, plus Nucelvia, POLYNEXA and DNAVIA™ branded collaboration products for professional regenerative and aesthetic use.",
    count: 18,
  },
};

export const ALL_PRODUCTS: Record<string, ProductDetailItem[]> = """ + json.dumps(data, indent=2, ensure_ascii=False) + ";\n"

with open(r"c:\Users\JalipEmpire\Downloads\New folder (11)\vesco-vision - Copy\src\data\allProductsData.ts", "w", encoding="utf-8") as f:
    f.write(ts_content)

print("Created src/data/allProductsData.ts successfully!")
