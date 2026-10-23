# Planification — plateforme data Market

Référence : `Projet_final_Market.docx`. Chaque étape se termine par une preuve démontrable au jury.

## Étape 0 — Socle (fait)
- [x] `docker-compose.yml` : PostgreSQL, MongoDB, Kafka (KRaft), MinIO, Prometheus, Grafana
- [x] `.env.example` / `.gitignore` : aucun secret dans le dépôt
- [ ] README : démarrage en une commande

## Étape 1 — Stockage SQL & NoSQL (volet 1)
- [x] Un schéma + un rôle PostgreSQL par service (`db/postgres/00..04`) — isolation vérifiée (`permission denied for schema orders`)
- [x] `orders` partitionnée par mois, CHECK sur montants/quantités, FK intra-schéma
- [x] `inventory.reservations` + `idempotency_key UNIQUE` (Saga, idempotence)
- [x] Collection `catalog` avec validateur + index texte / category / product_id
- [ ] `data/generate_dataset.py` — jeu de données (reste : `hourly_weight`)
- [ ] `db/explain/` : requêtes EXPLAIN ANALYZE avant/après index
- [ ] Sauvegarde `pg_dump` + `mongodump` et restauration testée (script)
- [ ] ADR-001 PostgreSQL, ADR-002 MongoDB

## Étape 2 — Microservices & API (volet 3)
- [ ] Service Auth : login, JWT 15 min, refresh, bcrypt, RBAC `@require_role`
- [ ] Services Stock, Paiement (refus > 200 €), Commandes (orchestrateur Saga)
- [ ] Catalogue en GraphQL (Strawberry), contrôle de rôle par résolveur
- [ ] Contrats d'abord : `contracts/openapi/*.yaml`, `contracts/graphql/catalog.graphql`, versions `/v1`
- [ ] Gateway (Traefik ou Kong) : vérification JWT + rate limiting
- [ ] Résilience : timeout, retry, circuit breaker (démo d'ouverture), bulkhead
- [ ] Observabilité : métriques Prometheus, dashboard Grafana, traces OpenTelemetry, logs JSON (401/403 tracés)
- [ ] ADR-003 découpage microservices / gateway

## Étape 3 — Temps réel (volet 4)
- [ ] Producteur d'événements (clics, commandes, stock, livraisons) vers Kafka
- [ ] Spark Structured Streaming : fenêtres, watermark, état, checkpoint
- [ ] Cas d'usage principal : rupture de stock proche (logistique, adéquation forte) ; secondaires : échec de paiement, pic de commandes, panier abandonné (fenêtre de session 30 min)
- [ ] Exactly-once : sink idempotent / Delta + checkpoint ; démo d'arrêt et de reprise en direct
- [ ] Suivi du lag (kafka-exporter), débit, erreurs dans Grafana
- [ ] ADR-004 niveau de garantie et choix des fenêtres

## Étape 4 — Data Lake & Lakehouse (volet 2)
- [x] Buckets MinIO raw / staging / curated / consumption
- [ ] Ingestion batch (Postgres/Mongo → raw) et streaming (Kafka → raw)
- [ ] Spark + Delta : staging (email pseudonymisé), curated (contrôles qualité, quarantaine), consumption (taux de remplissage entrepôts, alerte > 90 %)
- [ ] Time travel Delta démontré
- [ ] Catalogue de données (origine, responsable, date de mise à jour) + rapport qualité
- [ ] ADR-005 Delta vs Iceberg

## Étape 5 — Front, CI, livrables
- [ ] Les 5 onglets branchés sur les API (aucun chiffre en dur)
- [ ] Tests unitaires / API / bout en bout + CI GitHub Actions
- [ ] Dossier technique (15–25 p.), schémas d'architecture, répétition de la soutenance (scénarios 401/403/200, panne, reprise)
