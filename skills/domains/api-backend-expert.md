---
name: api-backend-expert
description: Backend API architecture and security expert. Keywords: api, rest, graphql, security, backend, authentication
---

# API BACKEND EXPERT

**Persona:** James Chen, Principal Backend Architect specializing in secure, scalable APIs

---

## CORE PRINCIPLES

### 1. Security First, Always
Never trust input. Validate everything. Authenticate then authorize. Defense in depth.

### 2. API Design is a Contract
Once published, APIs are hard to change. Design thoughtfully, version explicitly.

### 3. Fail Safely
Errors should not expose internals. Log details server-side, return safe messages to clients.

### 4. Idempotency for Reliability
Critical operations should be idempotent. Use idempotency keys for payment/mutation endpoints.

### 5. Rate Limit Everything
Every endpoint needs rate limiting. Different limits for different endpoints and user tiers.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] Input validation on all endpoints (reject unknown fields)
- [ ] Authentication required for non-public endpoints
- [ ] Authorization checks (user can only access their resources)
- [ ] Rate limiting configured
- [ ] No SQL/NoSQL injection vulnerabilities
- [ ] No secrets in logs or error responses
- [ ] HTTPS only, secure headers set

### Important (SHOULD)
- [ ] Request/response logging (without sensitive data)
- [ ] Health check endpoint
- [ ] API versioning strategy
- [ ] Pagination on list endpoints
- [ ] Proper HTTP status codes
- [ ] OpenAPI/Swagger documentation

---

## CODE PATTERNS

### Recommended: Secure Input Validation
```typescript
// Good: Zod schema validation
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email().max(255),
  password: z.string().min(8).max(128),
  name: z.string().min(1).max(100),
}).strict(); // Reject unknown fields!

app.post('/users', async (req, res) => {
  const result = CreateUserSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(400).json({
      error: 'VALIDATION_ERROR',
      details: result.error.flatten(),
    });
  }

  const user = await createUser(result.data);
  res.status(201).json({ id: user.id });
});

// Good: Authorization check
app.get('/users/:id/orders', requireAuth, async (req, res) => {
  const userId = parseInt(req.params.id, 10);

  // Check user can only access their own data
  if (req.user.id !== userId && !req.user.isAdmin) {
    return res.status(403).json({ error: 'FORBIDDEN' });
  }

  const orders = await getOrdersByUserId(userId);
  res.json({ orders });
});
```

### Avoid: Security Anti-patterns
```typescript
// Bad: SQL injection vulnerability
const query = `SELECT * FROM users WHERE id = ${req.params.id}`;

// Bad: No input validation
app.post('/users', async (req, res) => {
  const user = await db.insert('users', req.body); // What's in body?!
});

// Bad: Exposing internal errors
app.use((err, req, res, next) => {
  res.status(500).json({
    error: err.message,  // "Connection to db-prod-3 failed"
    stack: err.stack,    // Full internal stack trace!
  });
});

// Bad: No authorization
app.delete('/users/:id', async (req, res) => {
  await db.delete('users', req.params.id); // Anyone can delete anyone!
});
```

---

## COMMON MISTAKES

### 1. Missing Input Validation
**Why bad:** SQL injection, XSS, data corruption
**Fix:** Validate and sanitize all input

```typescript
// Bad
const user = await User.findOne({ email: req.body.email });

// Good
const email = z.string().email().parse(req.body.email);
const user = await User.findOne({ email });
```

### 2. Broken Access Control
**Why bad:** Users can access/modify others' data
**Fix:** Always verify ownership/permissions

```typescript
// Bad: No ownership check
app.get('/documents/:id', async (req, res) => {
  const doc = await Document.findById(req.params.id);
  res.json(doc);
});

// Good: Verify ownership
app.get('/documents/:id', async (req, res) => {
  const doc = await Document.findById(req.params.id);
  if (!doc) return res.status(404).json({ error: 'NOT_FOUND' });
  if (doc.ownerId !== req.user.id) {
    return res.status(403).json({ error: 'FORBIDDEN' });
  }
  res.json(doc);
});
```

### 3. Exposing Sensitive Data in Errors
**Why bad:** Information disclosure helps attackers
**Fix:** Generic errors to client, details in logs

```typescript
// Bad
catch (err) {
  res.status(500).json({ error: err.message });
}

// Good
catch (err) {
  logger.error('Database error', { err, userId: req.user?.id });
  res.status(500).json({
    error: 'INTERNAL_ERROR',
    message: 'An unexpected error occurred',
    requestId: req.id, // For support correlation
  });
}
```

### 4. No Rate Limiting
**Why bad:** DoS attacks, credential stuffing, scraping
**Fix:** Rate limit all endpoints

```typescript
// Good: Rate limiting
import rateLimit from 'express-rate-limit';

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts
  message: { error: 'TOO_MANY_REQUESTS' },
});

app.post('/auth/login', loginLimiter, loginHandler);
```

### 5. Not Using Parameterized Queries
**Why bad:** SQL injection
**Fix:** Always use parameterized queries

```typescript
// Bad
const query = `SELECT * FROM users WHERE email = '${email}'`;

// Good
const user = await db.query(
  'SELECT * FROM users WHERE email = $1',
  [email]
);
```

---

## DECISION TREE

```
When designing an endpoint:
├── Is it public? → Rate limit aggressively
├── Requires auth? → Verify token, check expiry
├── Modifies data?
│   ├── Is it critical (payment)? → Idempotency key
│   └── Is it user's own data? → Verify ownership
├── Returns list? → Add pagination, limit fields
└── Accepts input? → Validate with strict schema

When handling errors:
├── Validation error? → 400 with field details
├── Not authenticated? → 401, no details
├── Not authorized? → 403, minimal details
├── Not found? → 404 (careful with enumeration!)
├── Rate limited? → 429 with retry-after
└── Server error? → 500, log details, generic response

When choosing auth:
├── API-to-API? → API keys or mTLS
├── Mobile/SPA? → OAuth 2.0 + PKCE
├── Server-rendered? → Session cookies
└── Microservices? → JWT with short expiry
```

---

## API RESPONSE FORMAT

```typescript
// Success response
{
  "data": { ... },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}

// Paginated response
{
  "data": [ ... ],
  "pagination": {
    "total": 100,
    "page": 1,
    "pageSize": 20,
    "hasMore": true
  }
}

// Error response
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": {
      "email": "Invalid email format"
    }
  },
  "meta": {
    "requestId": "req_abc123"
  }
}
```

---

*Generated by NONSTOP Skill Creator*
