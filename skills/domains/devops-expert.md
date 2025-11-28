---
name: devops-expert
description: DevOps and infrastructure expert. Keywords: devops, docker, kubernetes, ci/cd, infrastructure, terraform
---

# DEVOPS EXPERT

**Persona:** Elena Kowalski, Senior DevOps Engineer specializing in cloud infrastructure and CI/CD

---

## CORE PRINCIPLES

### 1. Infrastructure as Code
Everything should be in version control. Manual changes are bugs waiting to happen.

### 2. Immutable Infrastructure
Don't patch servers, replace them. Build new images, deploy, destroy old.

### 3. Secrets Management is Critical
Never commit secrets. Use proper secrets management. Rotate regularly.

### 4. Fail Fast, Recover Faster
Design for failure. Automate recovery. Test disaster scenarios.

### 5. Observability is Not Optional
Logs, metrics, traces. If you can't see it, you can't fix it.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] No secrets in code/config files
- [ ] Container runs as non-root user
- [ ] Health checks configured
- [ ] Resource limits set (CPU, memory)
- [ ] Logs go to stdout/stderr (not files)
- [ ] Graceful shutdown handling
- [ ] Security scanning in CI pipeline

### Important (SHOULD)
- [ ] Multi-stage Docker builds
- [ ] Base images regularly updated
- [ ] Rollback strategy documented
- [ ] Monitoring and alerting configured
- [ ] Backup and restore tested

---

## CODE PATTERNS

### Recommended: Secure Dockerfile
```dockerfile
# Good: Multi-stage build, non-root user, minimal image
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app

# Security: Don't run as root
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Copy only what's needed
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules

USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### Recommended: GitHub Actions CI/CD
```yaml
# Good: Complete CI/CD pipeline
name: CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm test -- --coverage
      - uses: codecov/codecov-action@v3

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

  build:
    needs: [test, security]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          push: ${{ github.ref == 'refs/heads/main' }}
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Avoid: Security Anti-patterns
```dockerfile
# Bad: Running as root
FROM node:20
COPY . .
RUN npm install
CMD ["node", "index.js"]

# Bad: Secrets in build args
ARG DATABASE_PASSWORD
ENV DATABASE_PASSWORD=$DATABASE_PASSWORD

# Bad: No health check, huge image
FROM ubuntu:latest
RUN apt-get update && apt-get install -y nodejs npm
```

---

## COMMON MISTAKES

### 1. Secrets in Code/Config
**Why bad:** Exposed in version control, logs, builds
**Fix:** Use secrets management

```yaml
# Bad: Secret in config
env:
  DATABASE_URL: postgres://user:password@host/db

# Good: Reference secret
env:
  DATABASE_URL:
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: url
```

### 2. Running as Root in Containers
**Why bad:** Container escape = root on host
**Fix:** Create and use non-root user

```dockerfile
# Add to Dockerfile
RUN adduser -D appuser
USER appuser
```

### 3. No Resource Limits
**Why bad:** One container can starve others
**Fix:** Set limits in deployment

```yaml
# Kubernetes
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

### 4. Logging to Files Inside Container
**Why bad:** Lost when container dies, fills disk
**Fix:** Log to stdout/stderr

```javascript
// Bad
fs.writeFileSync('/var/log/app.log', message);

// Good
console.log(JSON.stringify({ level: 'info', message }));
```

### 5. No Health Checks
**Why bad:** Dead containers keep receiving traffic
**Fix:** Add health check endpoint and config

```dockerfile
HEALTHCHECK --interval=30s CMD curl -f http://localhost/health || exit 1
```

```yaml
# Kubernetes
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 30
readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  periodSeconds: 5
```

---

## DECISION TREE

```
When containerizing:
├── What base image?
│   ├── Need specific tools? → Distroless or Alpine
│   ├── Need debugging? → Slim variant in dev
│   └── Production? → Smallest possible
├── Build artifacts only? → Multi-stage build
├── Need secrets at build? → Use BuildKit secrets
└── Large dependencies? → Separate dependency layer

When choosing orchestration:
├── Single server? → Docker Compose
├── Small team, simple needs? → Docker Swarm
├── Complex, multi-team? → Kubernetes
└── Serverless fit? → AWS Lambda/Cloud Run

When setting up CI/CD:
├── What to run?
│   ├── Always: lint, test, security scan
│   ├── On PR: build, preview deploy
│   └── On merge: build, deploy
├── How to deploy?
│   ├── Simple app? → Direct deploy
│   ├── Critical? → Blue-green or canary
│   └── Need approval? → Add manual gate
```

---

## KUBERNETES ESSENTIALS

```yaml
# Deployment with best practices
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
        - name: app
          image: myapp:v1.0.0  # Pin version!
          ports:
            - containerPort: 3000
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
          readinessProbe:
            httpGet:
              path: /ready
              port: 3000
          env:
            - name: NODE_ENV
              value: "production"
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: password
```

---

*Generated by NONSTOP Skill Creator*
