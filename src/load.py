"""Load the Olist CSVs in data/ into olist.db (SQLite) using schema.sql.

Usage: python3 src/load.py
Rebuilds the database from scratch each run. Prints a row count per table.
"""
import csv
import os
import sqlite3

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(HERE, "data")
DB_PATH = os.path.join(HERE, "olist.db")
SCHEMA_PATH = os.path.join(HERE, "schema.sql")

TABLES = [
    ("customers", "olist_customers_dataset.csv"),
    ("orders", "olist_orders_dataset.csv"),
    ("order_items", "olist_order_items_dataset.csv"),
    ("payments", "olist_order_payments_dataset.csv"),
    ("reviews", "olist_order_reviews_dataset.csv"),
    ("products", "olist_products_dataset.csv"),
    ("sellers", "olist_sellers_dataset.csv"),
    ("category_translation", "product_category_name_translation.csv"),
]


def main():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    con = sqlite3.connect(DB_PATH)
    with open(SCHEMA_PATH, encoding="utf-8") as f:
        con.executescript(f.read())
    for table, fname in TABLES:
        path = os.path.join(DATA_DIR, fname)
        with open(path, encoding="utf-8-sig", newline="") as f:
            reader = csv.reader(f)
            cols = next(reader)
            placeholders = ",".join("?" * len(cols))
            con.executemany(
                f"INSERT INTO {table} ({','.join(cols)}) VALUES ({placeholders})",
                reader,
            )
        print(f"{table}: {con.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0]:,} rows")
    con.commit()
    con.close()
    print(f"wrote {DB_PATH}")


if __name__ == "__main__":
    main()
