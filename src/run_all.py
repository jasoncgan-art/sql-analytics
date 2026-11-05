"""Run every query in sql/ against olist.db and print the results,
followed by a headline-numbers summary.

Usage: python3 src/run_all.py
If olist.db is missing it is rebuilt first (python3 src/load.py).
"""
import os
import sqlite3
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(HERE, "olist.db")
SQL_DIR = os.path.join(HERE, "sql")

HEADLINES = [
    ("Customers (unique)", """
        SELECT COUNT(DISTINCT customer_unique_id) FROM customers"""),
    ("Orders", "SELECT COUNT(*) FROM orders"),
    ("Repeat purchase rate (%)", """
        WITH pc AS (
            SELECT c.customer_unique_id, COUNT(*) AS n
            FROM orders o JOIN customers c ON c.customer_id = o.customer_id
            GROUP BY c.customer_unique_id)
        SELECT ROUND(100.0 * SUM(CASE WHEN n > 1 THEN 1 ELSE 0 END)
                     / COUNT(*), 2) FROM pc"""),
    ("Funnel: ordered -> delivered (%)", """
        SELECT ROUND(100.0 * SUM(CASE WHEN order_status = 'delivered'
                     THEN 1 ELSE 0 END) / COUNT(*), 2) FROM orders"""),
    ("Funnel: delivered -> reviewed (%)", """
        SELECT ROUND(100.0 * COUNT(DISTINCT o.order_id)
                     / (SELECT COUNT(*) FROM orders
                        WHERE order_status = 'delivered'), 2)
        FROM orders o JOIN reviews r ON r.order_id = o.order_id
        WHERE o.order_status = 'delivered'"""),
    ("Mean order value (BRL)", """
        SELECT ROUND(AVG(order_value), 2) FROM
            (SELECT SUM(payment_value) AS order_value FROM payments
             GROUP BY order_id)"""),
    ("Median days to 2nd order", """
        WITH f AS (
            SELECT c.customer_unique_id,
                   MIN(o.order_purchase_timestamp) AS first_ts
            FROM orders o JOIN customers c ON c.customer_id = o.customer_id
            GROUP BY c.customer_unique_id),
        g AS (
            SELECT CAST(julianday(MIN(o.order_purchase_timestamp))
                        - julianday(f.first_ts) AS INTEGER) AS gap
            FROM orders o
            JOIN customers c ON c.customer_id = o.customer_id
            JOIN f ON f.customer_unique_id = c.customer_unique_id
            WHERE o.order_purchase_timestamp > f.first_ts
            GROUP BY c.customer_unique_id)
        SELECT gap FROM g ORDER BY gap
        LIMIT 1 OFFSET (SELECT COUNT(*) / 2 FROM g)"""),
    ("Mean review score", "SELECT ROUND(AVG(review_score), 2) FROM reviews"),
]


def split_statements(text):
    stmts, buf = [], ""
    for line in text.splitlines():
        if line.strip().startswith("--"):
            continue
        buf += line + "\n"
        if sqlite3.complete_statement(buf):
            stmt = buf.strip()
            if stmt:
                stmts.append(stmt)
            buf = ""
    if buf.strip():
        stmts.append(buf.strip())
    return stmts


def run_query(con, sql, title):
    print(f"\n### {title}")
    cur = con.execute(sql)
    cols = [d[0] for d in cur.description] if cur.description else []
    rows = cur.fetchall()
    if cols:
        widths = [len(c) for c in cols]
        for r in rows:
            for i, v in enumerate(r):
                widths[i] = max(widths[i], len(str(v)))
        fmt = "  ".join("{:<%d}" % w for w in widths)
        print(fmt.format(*cols))
        print("  ".join("-" * w for w in widths))
        for r in rows:
            print(fmt.format(*[str(v) for v in r]))
    print(f"({len(rows)} rows)")


def main():
    if not os.path.exists(DB_PATH):
        print("olist.db not found, rebuilding...")
        subprocess.run([sys.executable,
                        os.path.join(HERE, "src", "load.py")], check=True)
    con = sqlite3.connect(DB_PATH)
    for fname in sorted(os.listdir(SQL_DIR)):
        if not fname.endswith(".sql"):
            continue
        path = os.path.join(SQL_DIR, fname)
        with open(path, encoding="utf-8") as f:
            text = f.read()
        stmts = split_statements(text)
        for i, stmt in enumerate(stmts):
            title = fname if len(stmts) == 1 else f"{fname} [query {i + 1}]"
            run_query(con, stmt, title)
    print("\n" + "=" * 60)
    print("HEADLINE NUMBERS")
    print("=" * 60)
    for label, sql in HEADLINES:
        val = con.execute(sql).fetchone()[0]
        print(f"{label}: {val}")
    con.close()


if __name__ == "__main__":
    main()
