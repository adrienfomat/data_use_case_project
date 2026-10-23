# Market — plateforme data e-commerce

Projet final Bloc 1 (Mastère Data & GenAI Engineering). Sujet complet : `Projet_final_Market.docx`.
Feuille de route et avancement : [`planification.md`](planification.md).

## Prérequis

- Docker + docker-compose (`docker compose` ou `docker-compose` selon l'installation)
- Python 3.11+ (pour le générateur de données et, plus tard, les jobs Spark)
- ~6 Go de RAM libres pour Docker

## Démarrage (première fois)

```bash
git clone https://github.com/adrienfomat/data_use_case_project.git
cd data_use_case_project

# 1. Secrets locaux — .env n'est JAMAIS commité ; changez les valeurs
cp .env.example .env

# 2. Toute l'infra en une commande
docker-compose up -d

# 3. Dépendances Python
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 4. Jeu de données (catalogue Mongo, entrepôts/stock, clients/commandes)
set -a; . ./.env; set +a
python data/generate_dataset.py
```

Au premier démarrage, Postgres exécute `db/postgres/*` (schémas, rôles, tables) et Mongo
exécute `db/mongo/init-catalog.js`. Ces scripts ne tournent **que si le volume est vide** :
après une modification du schéma, repartir de zéro avec `docker-compose down -v && docker-compose up -d`.

## Ce qui tourne

| Service    | Accès                              | Identifiants (.env)                         |
|------------|------------------------------------|---------------------------------------------|
| PostgreSQL | `localhost:5432`, base `market`    | `POSTGRES_USER` / un rôle par service       |
| MongoDB    | `localhost:27017`, base `market`   | `MONGO_INITDB_ROOT_USERNAME` / `..._PASSWORD` |
| Kafka      | `localhost:9094` (hôte), `kafka:9092` (conteneurs) | — |
| MinIO      | API `localhost:9000`, console http://localhost:9001 | `MINIO_ROOT_USER` / `..._PASSWORD` |
| Prometheus | http://localhost:9090              | —                                           |
| Grafana    | http://localhost:3000              | `admin` / `GF_SECURITY_ADMIN_PASSWORD`      |

Topics Kafka créés par `kafka-init` : `clicks`, `orders`, `payments`, `stock`, `deliveries`, `alerts`.
Buckets MinIO créés au démarrage (`MINIO_DEFAULT_BUCKETS`) : `raw`, `staging`, `curated`, `consumption`.

## Organisation du code

```
db/postgres/      00_roles.sh (rôles par service) + 01..04 un fichier par schéma
db/mongo/         collection catalog (validateur + index)
data/             générateur de données
observability/    configuration Prometheus
```

Règle d'architecture : un service ne lit **que son schéma** (orders, inventory, payments, auth).
Les liens entre services (`product_id`, `order_id`) passent par les API, jamais par des jointures.

## Vérifications rapides

```bash
set -a; . ./.env; set +a
# Isolation : doit répondre "permission denied for schema orders"
docker-compose exec -T postgres env PGPASSWORD=$INVENTORY_DB_PASSWORD \
  psql -h localhost -U inventory_svc -d market -c "select * from orders.orders limit 1"

# Topics Kafka
docker-compose exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list
```

## Travailler à deux

- Nous utilisons tous les deux Claude Code : `CLAUDE.md` contient les règles du projet qu'il
  charge automatiquement. Le mettre à jour quand une convention change.
- Une branche par tâche (`feat/auth-service`, `feat/streaming-stock`…), puis pull request vers `main`.
- Cocher l'avancement dans `planification.md` dans la même PR.
- Ne jamais commiter `.env` ; toute nouvelle variable va dans `.env.example`.

## En cours

`hourly_weight()` dans `data/generate_dataset.py` est encore un TODO : tant qu'elle n'est pas écrite,
le générateur s'arrête avec `NotImplementedError`.
