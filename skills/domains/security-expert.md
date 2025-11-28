---
name: security-expert
description: Application security and secure coding expert. Keywords: security, owasp, authentication, authorization, encryption, xss, sql-injection, csrf
---

# SECURITY EXPERT

**Persona:** Marcus Black, Security Architect and former penetration tester with OSCP/OSCE certifications

---

## CORE PRINCIPLES

### 1. Defense in Depth
Never rely on a single security control. Layer your defenses.

### 2. Least Privilege
Grant minimum permissions needed. Default to deny.

### 3. Trust No Input
All external input is potentially malicious. Validate and sanitize everything.

### 4. Fail Securely
When things go wrong, fail closed, not open. Don't expose sensitive info in errors.

### 5. Security is Not Obscurity
Don't rely on secrets being secret. Assume attackers know your code.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] No hardcoded secrets in code
- [ ] Input validation on all user data
- [ ] Parameterized queries (no string concatenation)
- [ ] HTTPS everywhere
- [ ] Authentication on sensitive endpoints
- [ ] Password hashing with bcrypt/argon2

### Important (SHOULD)
- [ ] Rate limiting on auth endpoints
- [ ] CSRF protection on state-changing operations
- [ ] Security headers configured
- [ ] Dependency vulnerabilities scanned
- [ ] Audit logging for security events
- [ ] Content Security Policy (CSP) headers

---

## CODE PATTERNS

### Recommended: Input Validation
```typescript
import { z } from 'zod';

// Good: Strict schema validation
const UserInputSchema = z.object({
  email: z.string().email().max(255),
  password: z.string().min(8).max(128),
  name: z.string().min(1).max(100).regex(/^[a-zA-Z\s'-]+$/),
  age: z.number().int().min(13).max(150).optional(),
});

function createUser(input: unknown) {
  // Throws if invalid - never trust raw input
  const validated = UserInputSchema.parse(input);
  return db.users.create(validated);
}

// Good: Sanitize for display
import DOMPurify from 'dompurify';

function renderUserContent(html: string): string {
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p'],
    ALLOWED_ATTR: ['href'],
  });
}
```

### Recommended: SQL Injection Prevention
```typescript
// BAD: String concatenation (SQL Injection!)
const query = `SELECT * FROM users WHERE email = '${email}'`;

// GOOD: Parameterized queries
const result = await db.query(
  'SELECT * FROM users WHERE email = $1',
  [email]
);

// GOOD: ORM with parameterization
const user = await prisma.user.findUnique({
  where: { email },  // Automatically parameterized
});

// GOOD: Query builder
const users = await knex('users')
  .where('email', email)
  .andWhere('status', 'active');
```

### Recommended: Authentication
```typescript
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';

const SALT_ROUNDS = 12;
const JWT_SECRET = process.env.JWT_SECRET!;  // Never hardcode!

// Good: Password hashing
async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

// Good: JWT with expiration
function generateToken(userId: string): string {
  return jwt.sign(
    { sub: userId, type: 'access' },
    JWT_SECRET,
    { expiresIn: '15m' }  // Short-lived access tokens
  );
}

function generateRefreshToken(userId: string): string {
  return jwt.sign(
    { sub: userId, type: 'refresh' },
    JWT_SECRET,
    { expiresIn: '7d' }
  );
}

// Good: Token verification with type checking
function verifyToken(token: string, expectedType: 'access' | 'refresh') {
  try {
    const payload = jwt.verify(token, JWT_SECRET) as { sub: string; type: string };
    if (payload.type !== expectedType) {
      throw new Error('Invalid token type');
    }
    return payload;
  } catch {
    throw new AuthenticationError('Invalid token');
  }
}
```

### Recommended: Authorization
```typescript
// Good: Role-based access control (RBAC)
type Permission = 'read:users' | 'write:users' | 'delete:users' | 'admin';

const rolePermissions: Record<string, Permission[]> = {
  user: ['read:users'],
  editor: ['read:users', 'write:users'],
  admin: ['read:users', 'write:users', 'delete:users', 'admin'],
};

function hasPermission(user: User, permission: Permission): boolean {
  const permissions = rolePermissions[user.role] || [];
  return permissions.includes(permission);
}

// Good: Resource-based authorization
async function canEditPost(user: User, postId: string): Promise<boolean> {
  const post = await db.posts.findById(postId);
  if (!post) return false;

  // Owner can always edit
  if (post.authorId === user.id) return true;

  // Admin can edit anything
  if (hasPermission(user, 'admin')) return true;

  return false;
}

// Good: Middleware pattern
function requirePermission(permission: Permission) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    if (!hasPermission(req.user, permission)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
}

app.delete('/users/:id', requirePermission('delete:users'), deleteUserHandler);
```

### Recommended: Security Headers
```typescript
import helmet from 'helmet';

app.use(helmet());  // Adds many security headers

// Or configure individually
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'", "'unsafe-inline'"],  // Avoid unsafe-inline if possible
    styleSrc: ["'self'", "'unsafe-inline'"],
    imgSrc: ["'self'", "data:", "https:"],
    connectSrc: ["'self'", "https://api.example.com"],
    frameSrc: ["'none'"],
    objectSrc: ["'none'"],
  },
}));

app.use(helmet.hsts({
  maxAge: 31536000,
  includeSubDomains: true,
  preload: true,
}));
```

### Recommended: CSRF Protection
```typescript
import csrf from 'csurf';

// Good: CSRF token in cookies + header validation
const csrfProtection = csrf({
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
  },
});

app.use(csrfProtection);

// Include token in responses
app.get('/api/csrf-token', (req, res) => {
  res.json({ token: req.csrfToken() });
});

// Client must send token in header
// X-CSRF-Token: <token>
```

### Recommended: Rate Limiting
```typescript
import rateLimit from 'express-rate-limit';

// General rate limit
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 100,
  message: 'Too many requests, please try again later',
});

// Strict limit for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,  // 5 attempts per 15 minutes
  message: 'Too many login attempts',
  skipSuccessfulRequests: true,
});

app.use('/api', generalLimiter);
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
```

### Avoid: Common Vulnerabilities
```typescript
// BAD: Exposing stack traces
app.use((err, req, res, next) => {
  res.status(500).json({ error: err.stack });  // Exposes internals!
});

// GOOD: Generic error in production
app.use((err, req, res, next) => {
  logger.error(err);  // Log full error
  res.status(500).json({
    error: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message,
  });
});

// BAD: User enumeration
app.post('/login', async (req, res) => {
  const user = await db.users.findByEmail(req.body.email);
  if (!user) return res.status(401).json({ error: 'User not found' });  // Reveals user exists!
  // ...
});

// GOOD: Generic message
app.post('/login', async (req, res) => {
  const user = await db.users.findByEmail(req.body.email);
  const valid = user && await verifyPassword(req.body.password, user.passwordHash);
  if (!valid) return res.status(401).json({ error: 'Invalid credentials' });
  // ...
});

// BAD: Timing attacks on comparison
if (providedToken === storedToken) { ... }  // Variable time!

// GOOD: Constant-time comparison
import { timingSafeEqual } from 'crypto';
const a = Buffer.from(providedToken);
const b = Buffer.from(storedToken);
if (a.length === b.length && timingSafeEqual(a, b)) { ... }
```

---

## COMMON MISTAKES

### 1. Hardcoded Secrets
**Why bad:** Secrets in code end up in version control
**Fix:** Environment variables + secrets management

```typescript
// Bad
const API_KEY = 'sk_live_abc123';

// Good
const API_KEY = process.env.API_KEY;
if (!API_KEY) throw new Error('API_KEY not configured');
```

### 2. Missing HTTPS Redirect
**Why bad:** Initial request can be intercepted
**Fix:** Force HTTPS everywhere

```typescript
app.use((req, res, next) => {
  if (req.header('x-forwarded-proto') !== 'https' && process.env.NODE_ENV === 'production') {
    return res.redirect(`https://${req.header('host')}${req.url}`);
  }
  next();
});
```

### 3. Insecure Session Configuration
**Why bad:** Session hijacking
**Fix:** Secure cookie settings

```typescript
app.use(session({
  secret: process.env.SESSION_SECRET,
  cookie: {
    httpOnly: true,   // No JavaScript access
    secure: true,     // HTTPS only
    sameSite: 'strict',
    maxAge: 3600000,  // 1 hour
  },
  resave: false,
  saveUninitialized: false,
}));
```

### 4. Directory Traversal
**Why bad:** Access to arbitrary files
**Fix:** Validate and sanitize paths

```typescript
import path from 'path';

// Bad
app.get('/files/:name', (req, res) => {
  res.sendFile(`/uploads/${req.params.name}`);  // ../../../etc/passwd
});

// Good
app.get('/files/:name', (req, res) => {
  const safeName = path.basename(req.params.name);  // Remove path components
  const filePath = path.join('/uploads', safeName);

  // Verify still in allowed directory
  if (!filePath.startsWith('/uploads/')) {
    return res.status(400).json({ error: 'Invalid path' });
  }
  res.sendFile(filePath);
});
```

---

## OWASP TOP 10 CHECKLIST

```
A01: Broken Access Control
□ Deny by default
□ Verify ownership for all resources
□ Disable directory listing
□ Rate limit API access

A02: Cryptographic Failures
□ TLS 1.2+ only
□ Strong password hashing (bcrypt/argon2)
□ No sensitive data in URLs
□ Proper key management

A03: Injection
□ Parameterized queries
□ Input validation
□ Output encoding
□ No dynamic code execution

A04: Insecure Design
□ Threat modeling done
□ Secure development lifecycle
□ Unit tests for security controls

A05: Security Misconfiguration
□ Hardening applied
□ Default credentials changed
□ Error messages don't leak info
□ Security headers configured

A06: Vulnerable Components
□ Dependencies up to date
□ npm audit / pip audit clean
□ SBOM maintained
□ Automated scanning in CI

A07: Auth Failures
□ Multi-factor authentication
□ Weak password prevention
□ Brute force protection
□ Secure session management

A08: Data Integrity Failures
□ Signed updates/downloads
□ CI/CD pipeline secured
□ Deserialization safe

A09: Logging Failures
□ Security events logged
□ Logs protected from tampering
□ Alerting on suspicious activity

A10: SSRF
□ URL validation
□ Allowlist for external calls
□ No raw URL forwarding
```

---

*Generated by NONSTOP Skill Creator*
