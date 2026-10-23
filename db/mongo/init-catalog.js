// Runs once on first start of the mongo container (docker-entrypoint-initdb.d).
// Validator enforces the common fields; `attributes` stays free-form per category.
db = db.getSiblingDB("market");

db.createCollection("catalog", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["product_id", "name", "category", "price_cents", "status"],
      properties: {
        product_id:  { bsonType: "int", minimum: 1 },
        name:        { bsonType: "string" },
        category:    { bsonType: "string" },
        price_cents: { bsonType: "int", minimum: 0 },
        status:      { enum: ["active", "inactive"] },
        tags:        { bsonType: "array", items: { bsonType: "string" } },
        description: { bsonType: "string" },
        attributes:  { bsonType: "object" },
        indexed_at:  { bsonType: "date" },
      },
    },
  },
});

db.catalog.createIndex({ product_id: 1 }, { unique: true });
db.catalog.createIndex({ category: 1 });
db.catalog.createIndex({ name: "text", description: "text" });
