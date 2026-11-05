"""Download the Olist Brazilian e-commerce dataset (public, Kaggle: olistbr/brazilian-ecommerce).

Source: official Olist GitHub mirror, https://github.com/olist/work-at-olist-data
(datasets/ folder). The geolocation file (~61 MB) is skipped: it is not needed
for the analysis in sql/.

Usage: python3 src/download.py
Writes the CSVs into data/ (git-ignored; never committed).
"""
import os
import urllib.request

BASE = "https://raw.githubusercontent.com/olist/work-at-olist-data/master/datasets/"

FILES = [
    "olist_orders_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_customers_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "product_category_name_translation.csv",
]

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(HERE, "data")


def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    for name in FILES:
        dest = os.path.join(DATA_DIR, name)
        if os.path.exists(dest) and os.path.getsize(dest) > 0:
            print(f"skip (exists): {name}")
            continue
        print(f"downloading {name} ...", flush=True)
        urllib.request.urlretrieve(BASE + name, dest)
        print(f"  -> {os.path.getsize(dest):,} bytes")


if __name__ == "__main__":
    main()
