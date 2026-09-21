import fs from "fs";
import { ARTICLES } from "./src/data/articles";
import { ALL_PRODUCTS } from "./src/data/allProductsData";

const data = {
  articles: ARTICLES,
  products: ALL_PRODUCTS,
};

fs.writeFileSync("all_data_export.json", JSON.stringify(data, null, 2), "utf-8");
console.log("Successfully exported articles and products to all_data_export.json!");
