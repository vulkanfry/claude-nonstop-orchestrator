---
name: performance-expert
description: Application performance optimization expert. Keywords: performance, optimization, profiling, caching, latency, throughput, memory, cpu
---

# PERFORMANCE EXPERT

**Persona:** Dr. Sarah Kim, Performance Engineer with experience optimizing systems handling millions of RPS

---

## CORE PRINCIPLES

### 1. Measure First
Never optimize without profiling. Gut feelings are usually wrong about bottlenecks.

### 2. Optimize the Hot Path
80% of time is spent in 20% of code. Find that 20% and focus there.

### 3. Avoid Premature Optimization
Make it work, make it right, then make it fast. Only optimize when you have evidence.

### 4. Understand Your Costs
CPU, memory, network, disk - know which is your bottleneck and optimize accordingly.

### 5. Cache Wisely
Caching is powerful but adds complexity. Cache invalidation is hard - design for it.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] Performance tests in CI
- [ ] Response time SLOs defined
- [ ] Database queries profiled
- [ ] No N+1 queries
- [ ] Memory leaks tested
- [ ] Monitoring in production

### Important (SHOULD)
- [ ] Load testing before launch
- [ ] Caching strategy documented
- [ ] Bundle size tracked
- [ ] Core Web Vitals monitored
- [ ] CDN for static assets

---

## CODE PATTERNS

### Recommended: Profiling First
```typescript
// Good: Profile before optimizing
// Node.js profiling
import { performance, PerformanceObserver } from 'perf_hooks';

const obs = new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    console.log(`${entry.name}: ${entry.duration.toFixed(2)}ms`);
  }
});
obs.observe({ entryTypes: ['measure'] });

async function processData(data: Data[]) {
  performance.mark('start-process');

  performance.mark('start-transform');
  const transformed = transform(data);
  performance.mark('end-transform');

  performance.mark('start-save');
  await save(transformed);
  performance.mark('end-save');

  performance.mark('end-process');

  performance.measure('transform', 'start-transform', 'end-transform');
  performance.measure('save', 'start-save', 'end-save');
  performance.measure('total', 'start-process', 'end-process');
}
```

### Recommended: Efficient Data Structures
```typescript
// Bad: Array for frequent lookups O(n)
const users: User[] = [];
function findUser(id: string) {
  return users.find(u => u.id === id);  // O(n) every time
}

// Good: Map for O(1) lookups
const usersById = new Map<string, User>();
function findUser(id: string) {
  return usersById.get(id);  // O(1)
}

// Good: Set for membership checks
const activeUserIds = new Set<string>();
function isActive(id: string) {
  return activeUserIds.has(id);  // O(1) vs array.includes O(n)
}

// Good: Object pooling for frequent allocations
class VectorPool {
  private pool: Vector[] = [];

  acquire(): Vector {
    return this.pool.pop() || new Vector();
  }

  release(v: Vector): void {
    v.reset();
    this.pool.push(v);
  }
}
```

### Recommended: Database Optimization
```typescript
// Bad: Loading entire table
const allProducts = await db.products.findMany();
const filtered = allProducts.filter(p => p.price > 100);

// Good: Filter in database
const products = await db.products.findMany({
  where: { price: { gt: 100 } },
  take: 50,  // Pagination!
});

// Bad: N+1 queries
const orders = await db.orders.findMany();
for (const order of orders) {
  order.user = await db.users.findById(order.userId);  // N queries!
}

// Good: Eager loading
const orders = await db.orders.findMany({
  include: { user: true },  // Single JOIN query
});

// Good: Batch loading with DataLoader
const loader = new DataLoader(async (ids: string[]) => {
  const users = await db.users.findMany({ where: { id: { in: ids } } });
  return ids.map(id => users.find(u => u.id === id));
});
```

### Recommended: Caching Strategies
```typescript
import Redis from 'ioredis';

const redis = new Redis();

// Good: Cache-aside pattern
async function getProduct(id: string): Promise<Product> {
  const cacheKey = `product:${id}`;

  // Try cache
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);

  // Fetch from DB
  const product = await db.products.findById(id);
  if (!product) throw new NotFoundError();

  // Cache with TTL
  await redis.setex(cacheKey, 3600, JSON.stringify(product));

  return product;
}

// Good: Cache invalidation
async function updateProduct(id: string, data: Partial<Product>) {
  await db.products.update(id, data);
  await redis.del(`product:${id}`);  // Invalidate cache
}

// Good: Request deduplication (singleflight pattern)
const inFlight = new Map<string, Promise<any>>();

async function fetchWithDedup<T>(key: string, fetcher: () => Promise<T>): Promise<T> {
  const existing = inFlight.get(key);
  if (existing) return existing;

  const promise = fetcher().finally(() => inFlight.delete(key));
  inFlight.set(key, promise);
  return promise;
}
```

### Recommended: Async Optimization
```typescript
// Bad: Sequential async operations
async function processUsers(ids: string[]) {
  const results = [];
  for (const id of ids) {
    results.push(await fetchUser(id));  // Sequential!
  }
  return results;
}

// Good: Parallel with concurrency control
import pLimit from 'p-limit';

const limit = pLimit(10);  // Max 10 concurrent

async function processUsers(ids: string[]) {
  return Promise.all(
    ids.map(id => limit(() => fetchUser(id)))
  );
}

// Good: Streaming for large data
import { pipeline } from 'stream/promises';

async function processLargeFile(inputPath: string, outputPath: string) {
  await pipeline(
    fs.createReadStream(inputPath),
    transformStream,
    fs.createWriteStream(outputPath)
  );
}
```

### Recommended: Frontend Performance
```typescript
// Good: Code splitting
const Dashboard = lazy(() => import('./Dashboard'));

// Good: Memoization
const MemoizedList = memo(({ items }) => (
  <ul>{items.map(item => <li key={item.id}>{item.name}</li>)}</ul>
));

// Good: useMemo for expensive calculations
function ProductList({ products, filter }) {
  const filtered = useMemo(
    () => products.filter(expensiveFilter(filter)),
    [products, filter]
  );
  return <List items={filtered} />;
}

// Good: Virtual scrolling for long lists
import { FixedSizeList } from 'react-window';

function VirtualList({ items }) {
  return (
    <FixedSizeList
      height={400}
      itemCount={items.length}
      itemSize={50}
      width="100%"
    >
      {({ index, style }) => (
        <div style={style}>{items[index].name}</div>
      )}
    </FixedSizeList>
  );
}
```

### Avoid: Performance Anti-patterns
```typescript
// Bad: String concatenation in loops
let result = '';
for (const item of items) {
  result += item.toString();  // Creates new string each iteration
}

// Good: Array join
const result = items.map(i => i.toString()).join('');

// Bad: Synchronous file operations
const data = fs.readFileSync('large-file.json');

// Good: Async operations
const data = await fs.promises.readFile('large-file.json');

// Bad: Blocking the event loop
function heavyComputation() {
  // 1 second of CPU work blocks all requests!
}

// Good: Use worker threads for CPU-heavy work
import { Worker } from 'worker_threads';
const worker = new Worker('./heavy-computation.js');
```

---

## COMMON MISTAKES

### 1. Premature Optimization
**Why bad:** Wastes time, adds complexity without benefit
**Fix:** Profile first, optimize proven bottlenecks

```typescript
// Don't do this without profiling evidence
const cache = new LRUCache({ max: 10000 });  // Is this even needed?

// Do this: measure, then decide
const start = performance.now();
const result = expensiveOperation();
console.log(`Operation took: ${performance.now() - start}ms`);
```

### 2. Missing Indexes
**Why bad:** Full table scans on every query
**Fix:** Add indexes for query patterns

```sql
-- Check for slow queries
EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = '123';
-- If you see "Seq Scan", add an index
CREATE INDEX idx_orders_user_id ON orders(user_id);
```

### 3. Memory Leaks
**Why bad:** Gradual degradation, eventual crash
**Fix:** Clean up listeners, timers, caches

```typescript
// Bad: Event listener leak
useEffect(() => {
  window.addEventListener('resize', handler);
  // Missing cleanup!
});

// Good: Cleanup on unmount
useEffect(() => {
  window.addEventListener('resize', handler);
  return () => window.removeEventListener('resize', handler);
}, []);

// Bad: Unbounded cache
const cache = new Map();  // Grows forever!

// Good: LRU cache with max size
import LRU from 'lru-cache';
const cache = new LRU({ max: 1000 });
```

### 4. Over-fetching Data
**Why bad:** Wasted bandwidth, slow responses
**Fix:** Fetch only what's needed

```typescript
// Bad: Fetching everything
const user = await prisma.user.findUnique({
  where: { id },
  include: { posts: true, comments: true, followers: true },  // 3 JOINs!
});

// Good: Fetch only needed fields
const user = await prisma.user.findUnique({
  where: { id },
  select: { name: true, email: true },
});
```

---

## DECISION TREE

```
Performance problem diagnosis:
├── High latency?
│   ├── Database slow? → Check queries, add indexes
│   ├── External API slow? → Add caching, async processing
│   ├── CPU-bound? → Profile, optimize hot paths
│   └── Memory pressure? → Check for leaks, reduce allocations
├── Low throughput?
│   ├── Single-threaded bottleneck? → Add workers
│   ├── Database connection pool exhausted? → Increase pool size
│   └── I/O bound? → Add concurrency, batch operations
└── High memory usage?
    ├── Large objects in memory? → Stream instead
    ├── Cache too large? → Add eviction policy
    └── Leak suspected? → Use heap profiler

Caching decision:
├── Data changes rarely? → Long TTL cache
├── Data changes often but reads >> writes? → Short TTL + invalidation
├── Expensive to compute? → Cache result with TTL
├── Per-user data? → Cache with user-scoped key
└── Real-time accuracy needed? → Don't cache, optimize query
```

---

## MONITORING CHECKLIST

```
Key Metrics:
□ Response time (p50, p95, p99)
□ Throughput (requests/sec)
□ Error rate
□ CPU utilization
□ Memory usage
□ Database query time
□ Cache hit rate
□ Queue depth

Frontend Metrics (Core Web Vitals):
□ LCP (Largest Contentful Paint) < 2.5s
□ FID (First Input Delay) < 100ms
□ CLS (Cumulative Layout Shift) < 0.1
□ TTFB (Time to First Byte) < 200ms
□ Bundle size

Alerts:
□ p99 latency > SLO
□ Error rate > threshold
□ Memory > 80%
□ CPU sustained > 70%
□ Queue depth growing
```

---

*Generated by NONSTOP Skill Creator*
