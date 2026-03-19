---
title: "From Monolith to Microservices: A Practical Migration Guide"
description: "A battle-tested, step-by-step guide to decomposing a monolith into microservices — covering the Strangler Fig pattern, data decomposition, and the mistakes that derail most migrations."
date: 2026-03-12
tags: ["Architecture"]
readTime: "14 min read"
---

Most monolith-to-microservices migrations fail. Not because the target architecture is wrong, but because teams try to do it all at once. This guide covers the incremental approach that actually works in production — using the Strangler Fig pattern, domain-driven decomposition, and data migration strategies that don't require downtime.

## Should You Even Migrate?

Before writing a single line of code, answer these questions honestly:

<div class="diagram-box">
MIGRATION DECISION TREE

Is your monolith blocking team velocity?
├─ NO ──► Don't migrate. Invest in the monolith.
│         A well-structured monolith is fine.
│
└─ YES: Why?
   ├─ Deployment coupling (one team blocks others)
   │   └─► Microservices might help.
   │
   ├─ Scaling (one hot path needs 10x resources)
   │   └─► Extract just that service.
   │
   ├─ Technology mismatch (need ML in Python, app is C#)
   │   └─► Extract the boundary where tech changes.
   │
   └─ "Everyone else is doing it"
       └─► DON'T migrate. This is not a reason.
</div>

> **Rule of thumb:** If you can't articulate which specific bounded context you'd extract first and why, you're not ready to migrate.

## Phase 1: Understand Your Monolith

### Map the Domain Boundaries

Before decomposing, you need to understand what you're decomposing. Use Event Storming or a simpler approach — map every major feature to its data dependencies.

```
Feature → Tables Accessed → External APIs Called

User Registration → users, profiles, email_verification → SendGrid
Order Placement → orders, order_items, inventory, payments → Stripe
Product Search → products, categories, reviews → Elasticsearch
Shipping → orders, shipments, addresses → FedEx API
Reporting → orders, users, products, shipments → (none)
```

### Identify Bounded Contexts

Group features that share data and change together:

<div class="diagram-box">
BOUNDED CONTEXTS (identified from data dependencies)

┌──────────────────┐  ┌──────────────────┐
│   IDENTITY       │  │   CATALOG        │
│                  │  │                  │
│  users           │  │  products        │
│  profiles        │  │  categories      │
│  email_verify    │  │  reviews         │
│  auth_tokens     │  │  search_index    │
│                  │  │                  │
│  Registration    │  │  Product CRUD    │
│  Login/Logout    │  │  Search          │
│  Profile mgmt   │  │  Review system   │
└──────────────────┘  └──────────────────┘

┌──────────────────┐  ┌──────────────────┐
│   ORDERING       │  │   SHIPPING       │
│                  │  │                  │
│  orders          │  │  shipments       │
│  order_items     │  │  addresses       │
│  payments        │  │  tracking        │
│  inventory       │  │                  │
│                  │  │  Label creation  │
│  Cart            │  │  Tracking        │
│  Checkout        │  │  Delivery notify │
│  Payment         │  │                  │
└──────────────────┘  └──────────────────┘
</div>

### Measure Coupling

Find the cross-boundary queries. These are the painful parts of migration:

```sql
-- This query spans Ordering + Catalog + Identity
SELECT o.id, u.name, p.title, o.total
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
WHERE o.created_at > '2026-01-01';
```

Every cross-boundary join becomes an API call after migration. Count them. Prioritize decomposing contexts with the **fewest** cross-boundary dependencies first.

## Phase 2: The Strangler Fig Pattern

Don't rewrite the monolith. Strangle it — gradually routing traffic from the monolith to new services until the monolith is empty.

<div class="diagram-box">
STRANGLER FIG PATTERN (over time)

STEP 1: Route through a facade
┌──────────┐     ┌──────────┐     ┌──────────────┐
│  Client  │────►│  Facade  │────►│  Monolith    │
│          │     │ (Gateway) │     │  (all code)  │
└──────────┘     └──────────┘     └──────────────┘

STEP 2: Extract first service
┌──────────┐     ┌──────────┐     ┌──────────────┐
│  Client  │────►│  Facade  │──┬─►│  Monolith    │
│          │     │ (Gateway) │  │  │  (minus      │
└──────────┘     └──────────┘  │  │   catalog)   │
                               │  └──────────────┘
                               │  ┌──────────────┐
                               └─►│  Catalog     │
                                  │  Service     │
                                  └──────────────┘

STEP 3: Extract more services
┌──────────┐     ┌──────────┐     ┌──────────────┐
│  Client  │────►│  Facade  │──┬─►│  Monolith    │
│          │     │ (Gateway) │  │  │  (shrinking) │
└──────────┘     └──────────┘  │  └──────────────┘
                               ├─►│ Catalog Svc  │
                               ├─►│ Identity Svc │
                               └─►│ Shipping Svc │

STEP 4: Monolith is gone
┌──────────┐     ┌──────────┐
│  Client  │────►│  Gateway  │──┬─► Catalog
│          │     │           │  ├─► Identity
└──────────┘     └──────────┘  ├─► Ordering
                               └─► Shipping
</div>

### Implementing the Facade

Use an API gateway (NGINX, Kong, or a cloud-native option) as the strangler facade:

```yaml
# nginx.conf - route by path
upstream monolith {
  server monolith:8080;
}

upstream catalog_service {
  server catalog:8080;
}

server {
  listen 80;

  # New service handles catalog
  location /api/products {
    proxy_pass http://catalog_service;
  }

  location /api/categories {
    proxy_pass http://catalog_service;
  }

  # Everything else goes to monolith
  location / {
    proxy_pass http://monolith;
  }
}
```

## Phase 3: Extract Your First Service

Choose the bounded context with:
1. **Fewest dependencies** on other contexts
2. **Clearest data ownership** (tables belong only to this context)
3. **Highest business value** for being independently deployable

Often this is the **Catalog** or **Identity** context.

### Step 1: Create the New Service

```typescript
// catalog-service/src/index.ts
import express from 'express';
import { Pool } from 'pg';

const app = express();
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Replicate the monolith's API contract exactly
app.get('/api/products', async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM products ORDER BY created_at DESC LIMIT $1',
    [req.query.limit || 50]
  );
  res.json(rows);
});

app.get('/api/products/:id', async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM products WHERE id = $1',
    [req.params.id]
  );
  if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
  res.json(rows[0]);
});

app.listen(8080);
```

### Step 2: Run Both in Parallel

The **parallel run** pattern validates the new service before cutting over:

```typescript
// In the API gateway or facade
app.get('/api/products/:id', async (req, res) => {
  // Primary: monolith (still serving traffic)
  const monolithResponse = await fetch(
    `http://monolith:8080/api/products/${req.params.id}`
  );

  // Shadow: new service (results compared, not returned)
  const newServiceResponse = await fetch(
    `http://catalog:8080/api/products/${req.params.id}`
  ).catch(err => ({ error: err.message }));

  // Compare responses
  if (JSON.stringify(monolithResponse) !== JSON.stringify(newServiceResponse)) {
    metrics.increment('catalog.migration.mismatch');
    logger.warn('Response mismatch', {
      monolith: monolithResponse,
      newService: newServiceResponse,
    });
  }

  // Still return the monolith response
  res.json(await monolithResponse.json());
});
```

### Step 3: Cut Over

Once the mismatch rate is zero, switch the gateway to route to the new service.

## Phase 4: Data Decomposition

This is where most migrations stall. The monolith's database has cross-context foreign keys, shared tables, and reporting queries that span everything.

### Strategy 1: Shared Database (Temporary)

Start by letting the new service read from the monolith's database:

```
┌──────────────┐     ┌──────────────┐
│   Monolith   │     │  Catalog Svc │
│              │     │              │
└──────┬───────┘     └──────┬───────┘
       │                    │
       └────────┬───────────┘
                │
       ┌────────┴────────┐
       │  Shared Database │  ← Temporary!
       │  (monolith DB)   │
       └─────────────────┘
```

**This is not the end state.** It's a stepping stone. The service works, but you haven't achieved data independence.

### Strategy 2: Database per Service (Target)

Migrate the service's tables to its own database:

```
┌──────────────┐     ┌──────────────┐
│   Monolith   │     │  Catalog Svc │
│              │     │              │
└──────┬───────┘     └──────┬───────┘
       │                    │
┌──────┴───────┐    ┌──────┴───────┐
│ Monolith DB  │    │ Catalog DB   │
│ (minus       │    │ products     │
│  products)   │    │ categories   │
└──────────────┘    │ reviews      │
                    └──────────────┘
```

### Data Migration Script

```python
# migrate_catalog_data.py
import psycopg2
from datetime import datetime

source = psycopg2.connect(SOURCE_DB_URL)
target = psycopg2.connect(TARGET_DB_URL)

# Phase 1: Copy historical data
with source.cursor() as src, target.cursor() as tgt:
    src.execute("SELECT * FROM products")
    for row in src:
        tgt.execute(
            "INSERT INTO products VALUES (%s, %s, %s, %s, %s) "
            "ON CONFLICT (id) DO NOTHING",
            row
        )
    target.commit()

# Phase 2: Set up CDC (Change Data Capture) for ongoing sync
# Use Debezium, AWS DMS, or a custom trigger
```

### Handling Cross-Service Queries

The reporting query that joined `orders`, `users`, and `products` now spans three services. Options:

1. **API Composition** — the gateway calls each service and joins in memory
2. **CQRS Read Model** — a denormalized read database updated by events
3. **Data Lake** — services publish events, analytics queries run against the lake

```typescript
// API Composition pattern
app.get('/api/reports/orders', async (req, res) => {
  const orders = await orderService.getOrders(req.query);
  
  // Enrich with data from other services
  const userIds = [...new Set(orders.map(o => o.userId))];
  const productIds = [...new Set(orders.flatMap(o => o.items.map(i => i.productId)))];

  const [users, products] = await Promise.all([
    identityService.getUsersByIds(userIds),
    catalogService.getProductsByIds(productIds),
  ]);

  const enriched = orders.map(order => ({
    ...order,
    user: users.find(u => u.id === order.userId),
    items: order.items.map(item => ({
      ...item,
      product: products.find(p => p.id === item.productId),
    })),
  }));

  res.json(enriched);
});
```

## The Top 5 Migration Mistakes

### 1. Big Bang Rewrite

> "Let's rewrite the entire monolith in microservices over 6 months."

This fails because:
- Requirements change during the rewrite
- The team maintains two systems simultaneously
- Integration testing the new system is harder than expected
- Stakeholders lose patience before it's done

**Fix:** Strangler Fig. Extract one service at a time, validate it works, then move to the next.

### 2. Starting with the Wrong Service

Teams often extract the most complex, most coupled service first because "that's where the pain is." This maximizes risk.

**Fix:** Start with a low-coupling, low-risk context. Get the infrastructure (CI/CD, service mesh, monitoring) right on something simple.

### 3. Distributed Monolith

Services that can't be deployed independently, that share a database, and that require coordinated releases — you've built a distributed monolith. All the complexity of microservices, none of the benefits.

**Fix:** Each service must own its data and be independently deployable. If two services always deploy together, merge them.

### 4. Ignoring Data Consistency

In a monolith, database transactions guarantee consistency. In microservices, you need eventual consistency patterns:

```typescript
// Saga pattern for cross-service transactions
class OrderSaga {
  async execute(order: Order) {
    try {
      await inventoryService.reserve(order.items);
      await paymentService.charge(order.total);
      await orderService.confirm(order.id);
    } catch (error) {
      // Compensating transactions
      await inventoryService.release(order.items);
      await paymentService.refund(order.total);
      await orderService.cancel(order.id);
      throw error;
    }
  }
}
```

### 5. No Observability

You can't debug a distributed system with `console.log`. Before extracting the first service:
- Set up distributed tracing (OpenTelemetry)
- Centralize logs with correlation IDs
- Create dashboards for latency, error rates, and throughput per service

## Migration Timeline (Realistic)

For a medium-sized monolith (50K-200K lines of code):

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Domain analysis | 2-4 weeks | Bounded context map, dependency graph |
| Infrastructure | 4-6 weeks | CI/CD, gateway, monitoring, service mesh |
| First service | 4-8 weeks | One service extracted, validated, in production |
| Second service | 3-6 weeks | Second extraction (faster due to patterns) |
| Remaining services | 3-4 weeks each | Incremental extraction |
| Data decomposition | Ongoing | Parallel with service extraction |
| Decommission monolith | 2-4 weeks | Final cleanup, remove monolith |

**Total: 6-18 months** depending on monolith size and team experience.

## Checklist Before You Start

- [ ] Can you articulate why microservices (not "everyone does it")
- [ ] Have you mapped bounded contexts and data dependencies
- [ ] Do you have a CI/CD pipeline that can deploy services independently
- [ ] Is distributed tracing and centralized logging set up
- [ ] Have you chosen your first service to extract (low coupling)
- [ ] Do stakeholders understand this is a 6-18 month journey
- [ ] Is the team trained on eventual consistency and distributed systems patterns

If you can't check every box, invest in those items before starting the migration. The infrastructure and organizational readiness matter more than the code.

*Published by the TechAI Explained Team.*
