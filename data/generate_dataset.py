"""Seed Market's operational stores with realistic data.

Each domain is written through its own service role, the same way the services
will: customers/orders via orders_svc, warehouses/stock via inventory_svc,
products via MongoDB. product_id is the only link between stores.

    python data/generate_dataset.py --customers 500 --products 120 --orders 3000
"""
import argparse
import os
import random
import uuid
from datetime import datetime, timedelta, timezone

import psycopg
from faker import Faker
from pymongo import MongoClient

fake = Faker("fr_FR")

# Category -> (price range in cents, attribute generator). Attributes differ per
# category on purpose: that is the reason the catalog lives in MongoDB (ADR-002).
CATEGORIES = {
    "Audio": ((2_000, 35_000), lambda: {
        "autonomie_h": random.choice([20, 30, 40]),
        "couleur": random.sample(["noir", "blanc", "bleu"], 2)}),
    "Chaussures": ((4_000, 18_000), lambda: {
        "pointure": list(range(38, 46)),
        "couleur": random.sample(["noir", "blanc", "rouge", "beige"], 2)}),
    "Accessoires": ((900, 9_000), lambda: {
        "puissance_w": random.choice([20, 45, 65, 100])}),
    "Maison": ((1_500, 60_000), lambda: {
        "dimensions_cm": [random.randint(20, 200) for _ in range(3)]}),
}

WAREHOUSES = [("Lyon-Nord", 50_000), ("Paris-Est", 80_000), ("Lille", 30_000)]
ORDER_STATUSES = ["paid", "preparing", "delivered", "payment_failed"]
ORDER_STATUS_WEIGHTS = [0.35, 0.25, 0.32, 0.08]


def hourly_weight(hour: int) -> float:
    """Relative share of the day's orders placed during `hour` (0-23).

    Drives the "commandes heure par heure" chart and gives the streaming job a
    baseline to detect "pic de commandes" against.
    """
    # TODO(you): return a weight for each hour of the day.
    raise NotImplementedError


def pg(role: str, password_env: str) -> psycopg.Connection:
    return psycopg.connect(
        host=os.getenv("PGHOST", "localhost"), dbname=os.environ["POSTGRES_DB"],
        user=role, password=os.environ[password_env], autocommit=False)


def seed_catalog(n_products: int) -> list[dict]:
    products = []
    for pid in range(1, n_products + 1):
        category = random.choice(list(CATEGORIES))
        (lo, hi), attrs = CATEGORIES[category]
        products.append({
            "product_id": pid,
            "name": f"{fake.word().capitalize()} {category[:-1] if category.endswith('s') else category} {pid}",
            "category": category,
            "price_cents": random.randint(lo, hi),
            "status": "active" if random.random() > 0.05 else "inactive",
            "tags": fake.words(nb=3),
            "description": fake.sentence(nb_words=12),
            "attributes": attrs(),
            "indexed_at": datetime.now(timezone.utc),
        })
    mongo = MongoClient(
        os.getenv("MONGO_HOST", "localhost"), 27017,
        username=os.environ["MONGO_INITDB_ROOT_USERNAME"],
        password=os.environ["MONGO_INITDB_ROOT_PASSWORD"])
    col = mongo.market.catalog
    col.delete_many({})
    col.insert_many(products)
    return products


def seed_inventory(products: list[dict]) -> None:
    with pg("inventory_svc", "INVENTORY_DB_PASSWORD") as conn, conn.cursor() as cur:
        cur.execute("TRUNCATE inventory.reservations, inventory.stock, inventory.warehouses RESTART IDENTITY CASCADE")
        cur.executemany(
            "INSERT INTO inventory.warehouses (name, capacity_units) VALUES (%s, %s)", WAREHOUSES)
        rows = []
        for p in products:
            for wid in random.sample(range(1, len(WAREHOUSES) + 1), k=random.randint(1, 3)):
                # ~10% of lines start low so "rupture proche" alerts have something to fire on.
                qty = random.randint(0, 8) if random.random() < 0.10 else random.randint(20, 400)
                rows.append((p["product_id"], wid, qty))
        cur.executemany(
            "INSERT INTO inventory.stock (product_id, warehouse_id, quantity) VALUES (%s, %s, %s)", rows)


def seed_orders(products: list[dict], n_customers: int, n_orders: int, days: int) -> None:
    prices = {p["product_id"]: p["price_cents"] for p in products if p["status"] == "active"}
    hours, weights = list(range(24)), [hourly_weight(h) for h in range(24)]
    today = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)

    with pg("orders_svc", "ORDERS_DB_PASSWORD") as conn, conn.cursor() as cur:
        cur.execute("TRUNCATE orders.order_items, orders.orders, orders.customers RESTART IDENTITY CASCADE")
        cur.executemany(
            "INSERT INTO orders.customers (name, email) VALUES (%s, %s)",
            [(fake.name(), fake.unique.email()) for _ in range(n_customers)])

        for _ in range(n_orders):
            day = today - timedelta(days=random.randrange(days))
            ts = day + timedelta(hours=random.choices(hours, weights)[0],
                                 minutes=random.randrange(60), seconds=random.randrange(60))
            if ts > datetime.now(timezone.utc):
                continue
            lines = [(pid, random.randint(1, 3), prices[pid])
                     for pid in random.sample(list(prices), k=random.randint(1, 4))]
            total = sum(q * p for _, q, p in lines)
            status = random.choices(ORDER_STATUSES, ORDER_STATUS_WEIGHTS)[0]
            cur.execute(
                """INSERT INTO orders.orders (customer_id, status, total_cents, idempotency_key, created_at)
                   VALUES (%s, %s, %s, %s, %s) RETURNING id""",
                (random.randint(1, n_customers), status, total, str(uuid.uuid4()), ts))
            order_id = cur.fetchone()[0]
            cur.executemany(
                """INSERT INTO orders.order_items
                   (order_id, order_created_at, product_id, quantity, unit_price_cents)
                   VALUES (%s, %s, %s, %s, %s)""",
                [(order_id, ts, pid, q, p) for pid, q, p in lines])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--customers", type=int, default=500)
    ap.add_argument("--products", type=int, default=120)
    ap.add_argument("--orders", type=int, default=3000)
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()
    random.seed(args.seed)
    Faker.seed(args.seed)

    products = seed_catalog(args.products)
    seed_inventory(products)
    seed_orders(products, args.customers, args.orders, args.days)
    print(f"seeded {args.products} products, {args.customers} customers, ~{args.orders} orders")


if __name__ == "__main__":
    main()
