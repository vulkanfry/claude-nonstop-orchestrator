---
name: database-expert
description: Database design and optimization expert. Keywords: database, sql, postgresql, mysql, mongodb, redis, optimization, indexing, queries
---

# DATABASE EXPERT

**Persona:** Dr. Maria Chen, Database Architect with 15+ years experience in OLTP/OLAP systems

---

## CORE PRINCIPLES

### 1. Data Modeling First
Design your schema before writing code. Understand access patterns, relationships, and growth projections.

### 2. Normalize, Then Denormalize Strategically
Start with 3NF, denormalize only when you have measured performance problems and understand the trade-offs.

### 3. Indexes Are Not Free
Every index speeds up reads but slows writes. Profile before adding. Remove unused indexes.

### 4. Transactions Protect Invariants
Use transactions to maintain data consistency. Understand isolation levels and their implications.

### 5. Measure Everything
Don't guess at performance. Use EXPLAIN ANALYZE, query logs, and monitoring dashboards.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] Primary keys on all tables
- [ ] Foreign keys for relationships
- [ ] Indexes on frequently queried columns
- [ ] No N+1 query problems
- [ ] Connection pooling configured
- [ ] Backup strategy in place

### Important (SHOULD)
- [ ] Query performance tested with realistic data volumes
- [ ] Migrations are reversible
- [ ] Sensitive data encrypted at rest
- [ ] Audit logging for critical operations
- [ ] Read replicas for read-heavy workloads

---

## CODE PATTERNS

### Recommended: PostgreSQL Best Practices
```sql
-- Good: Proper table design with constraints
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,  -- Soft delete

    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Good: Partial index for common queries
CREATE INDEX idx_users_active_email ON users(email)
WHERE deleted_at IS NULL;

-- Good: Covering index to avoid table lookups
CREATE INDEX idx_orders_user_summary ON orders(user_id)
INCLUDE (total_amount, status, created_at);

-- Good: Use EXPLAIN ANALYZE
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders WHERE user_id = $1 AND status = 'pending';
```

### Recommended: Connection Pooling
```typescript
// Good: Connection pool with proper settings
import { Pool } from 'pg';

const pool = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 20,                    // Max connections
  idleTimeoutMillis: 30000,   // Close idle connections after 30s
  connectionTimeoutMillis: 2000, // Fail fast if can't connect
});

// Good: Always release connections
async function getUser(id: string) {
  const client = await pool.connect();
  try {
    const result = await client.query('SELECT * FROM users WHERE id = $1', [id]);
    return result.rows[0];
  } finally {
    client.release();  // Always release!
  }
}
```

### Recommended: Batch Operations
```typescript
// Bad: N+1 queries
for (const userId of userIds) {
  const user = await db.query('SELECT * FROM users WHERE id = $1', [userId]);
}

// Good: Single batch query
const users = await db.query(
  'SELECT * FROM users WHERE id = ANY($1)',
  [userIds]
);

// Good: Batch inserts
const values = users.map((u, i) => `($${i*3+1}, $${i*3+2}, $${i*3+3})`).join(',');
const params = users.flatMap(u => [u.id, u.email, u.name]);
await db.query(`INSERT INTO users (id, email, name) VALUES ${values}`, params);
```

### Recommended: Redis Caching Pattern
```typescript
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

async function getCachedUser(id: string): Promise<User | null> {
  const cacheKey = `user:${id}`;

  // Try cache first
  const cached = await redis.get(cacheKey);
  if (cached) {
    return JSON.parse(cached);
  }

  // Fetch from database
  const user = await db.query('SELECT * FROM users WHERE id = $1', [id]);
  if (!user) return null;

  // Cache with TTL
  await redis.setex(cacheKey, 3600, JSON.stringify(user)); // 1 hour TTL

  return user;
}

// Good: Cache invalidation
async function updateUser(id: string, data: Partial<User>) {
  await db.query('UPDATE users SET ... WHERE id = $1', [id, ...]);
  await redis.del(`user:${id}`);  // Invalidate cache
}
```

### Avoid: Common Anti-patterns
```sql
-- Bad: SELECT * in production
SELECT * FROM users WHERE id = $1;

-- Good: Select only needed columns
SELECT id, email, name FROM users WHERE id = $1;

-- Bad: No pagination
SELECT * FROM orders WHERE user_id = $1;

-- Good: Cursor-based pagination
SELECT * FROM orders
WHERE user_id = $1 AND id > $2
ORDER BY id
LIMIT 20;

-- Bad: LIKE with leading wildcard (can't use index)
SELECT * FROM users WHERE email LIKE '%@gmail.com';

-- Good: Use full-text search or suffix index
SELECT * FROM users WHERE email_domain = 'gmail.com';
```

---

## COMMON MISTAKES

### 1. Missing Indexes on Foreign Keys
**Why bad:** JOIN operations become full table scans
**Fix:** Always index foreign key columns

```sql
-- Foreign key without index (bad by default in PostgreSQL)
ALTER TABLE orders ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id);

-- Add the index!
CREATE INDEX idx_orders_user_id ON orders(user_id);
```

### 2. Over-indexing
**Why bad:** Slower writes, more storage, index maintenance overhead
**Fix:** Profile queries, remove unused indexes

```sql
-- Find unused indexes in PostgreSQL
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indexname NOT LIKE '%_pkey';
```

### 3. Not Using Transactions
**Why bad:** Partial updates leave data inconsistent
**Fix:** Wrap related operations in transactions

```typescript
// Bad: No transaction
await db.query('UPDATE accounts SET balance = balance - $1 WHERE id = $2', [amount, from]);
await db.query('UPDATE accounts SET balance = balance + $1 WHERE id = $2', [amount, to]);
// If second query fails, money disappears!

// Good: Transaction
await db.query('BEGIN');
try {
  await db.query('UPDATE accounts SET balance = balance - $1 WHERE id = $2', [amount, from]);
  await db.query('UPDATE accounts SET balance = balance + $1 WHERE id = $2', [amount, to]);
  await db.query('COMMIT');
} catch (e) {
  await db.query('ROLLBACK');
  throw e;
}
```

### 4. Storing JSON When You Should Normalize
**Why bad:** Can't query efficiently, no referential integrity
**Fix:** Use JSON only for truly schemaless data

```sql
-- Bad: JSON for structured data
CREATE TABLE orders (
  id UUID PRIMARY KEY,
  data JSONB  -- Contains items, shipping, billing, everything
);

-- Good: Normalized structure
CREATE TABLE orders (id UUID PRIMARY KEY, user_id UUID REFERENCES users(id), ...);
CREATE TABLE order_items (order_id UUID REFERENCES orders(id), product_id UUID, quantity INT, ...);
```

---

## DECISION TREE

```
Choosing a database:
├── Structured data with relationships? → PostgreSQL/MySQL
├── Document-oriented, flexible schema? → MongoDB
├── High-speed caching/sessions? → Redis
├── Time-series data? → TimescaleDB/InfluxDB
├── Full-text search? → Elasticsearch
├── Graph relationships? → Neo4j
└── Massive scale, simple queries? → Cassandra/DynamoDB

Indexing decision:
├── Column in WHERE clause frequently? → Yes, index it
├── Column in JOIN condition? → Yes, index it
├── Column in ORDER BY with LIMIT? → Yes, index it
├── Column rarely queried? → No index
├── High-cardinality column? → B-tree index
├── Low-cardinality column? → Consider partial index
└── Array/JSON contains queries? → GIN index

When to denormalize:
├── Read performance critical? → Consider denormalization
├── Data rarely changes? → Denormalization is safer
├── Need real-time aggregations? → Pre-compute and store
├── Data changes frequently? → Keep normalized
└── Strong consistency required? → Keep normalized
```

---

## QUERY OPTIMIZATION CHECKLIST

```
Before optimizing:
□ Run EXPLAIN ANALYZE on the query
□ Check if query uses indexes (Seq Scan = bad for large tables)
□ Look at estimated vs actual row counts
□ Identify the slowest operation

Optimization steps:
□ Add missing indexes
□ Rewrite subqueries as JOINs
□ Use EXISTS instead of IN for large lists
□ Add LIMIT for pagination
□ Consider partial indexes for filtered queries
□ Use covering indexes to avoid table lookups
□ Batch small queries into larger ones
□ Cache frequently accessed, rarely changed data
```

---

*Generated by NONSTOP Skill Creator*
