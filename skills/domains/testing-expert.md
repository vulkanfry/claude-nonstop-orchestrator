---
name: testing-expert
description: Software testing and quality assurance expert. Keywords: testing, tdd, unit-tests, integration-tests, e2e, jest, pytest, playwright
---

# TESTING EXPERT

**Persona:** Jordan Lee, QA Architect with expertise in test automation and TDD

---

## CORE PRINCIPLES

### 1. Test Behavior, Not Implementation
Tests should verify what code does, not how it does it. Implementation changes shouldn't break tests.

### 2. Test Pyramid
Many unit tests, fewer integration tests, fewest E2E tests. Fast feedback at the base.

### 3. Tests as Documentation
Well-written tests explain expected behavior. New developers should understand the system from tests.

### 4. Deterministic and Isolated
Tests must produce same results every run. No shared state, no time dependencies, no network flakiness.

### 5. Fast Feedback Loop
Tests should run in seconds, not minutes. Slow tests don't get run.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] Unit tests for business logic
- [ ] Tests are deterministic (no flakiness)
- [ ] Tests don't depend on each other
- [ ] CI runs tests on every commit
- [ ] No tests that always pass
- [ ] Test data doesn't leak between tests

### Important (SHOULD)
- [ ] Integration tests for API endpoints
- [ ] E2E tests for critical user flows
- [ ] Tests for error cases, not just happy path
- [ ] Meaningful test names (describe behavior)
- [ ] Test coverage tracked (not worshipped)

---

## CODE PATTERNS

### Recommended: Arrange-Act-Assert (AAA)
```typescript
// Good: Clear structure
describe('UserService', () => {
  describe('createUser', () => {
    it('should create user with hashed password', async () => {
      // Arrange
      const userData = {
        email: 'test@example.com',
        password: 'plaintext123',
      };
      const mockHashedPassword = 'hashed_abc123';
      jest.spyOn(bcrypt, 'hash').mockResolvedValue(mockHashedPassword);

      // Act
      const result = await userService.createUser(userData);

      // Assert
      expect(result.email).toBe('test@example.com');
      expect(result.password).toBe(mockHashedPassword);
      expect(bcrypt.hash).toHaveBeenCalledWith('plaintext123', 10);
    });

    it('should throw if email already exists', async () => {
      // Arrange
      const userData = { email: 'existing@example.com', password: 'test' };
      mockUserRepo.findByEmail.mockResolvedValue({ id: 1 });

      // Act & Assert
      await expect(userService.createUser(userData))
        .rejects
        .toThrow('Email already registered');
    });
  });
});
```

### Recommended: Test Fixtures and Factories
```typescript
// factories/user.factory.ts
export const createTestUser = (overrides?: Partial<User>): User => ({
  id: faker.string.uuid(),
  email: faker.internet.email(),
  name: faker.person.fullName(),
  createdAt: new Date(),
  ...overrides,
});

// In tests
it('should update user name', async () => {
  const user = createTestUser({ name: 'Old Name' });
  const result = await userService.updateName(user.id, 'New Name');
  expect(result.name).toBe('New Name');
});
```

### Recommended: Testing Async Code
```typescript
// Good: Proper async testing
it('should fetch user data', async () => {
  const user = await userService.getUser('123');
  expect(user).toBeDefined();
});

// Good: Testing promises that should reject
it('should reject when user not found', async () => {
  await expect(userService.getUser('nonexistent'))
    .rejects
    .toThrow(UserNotFoundError);
});

// Good: Testing with fake timers
it('should retry after delay', async () => {
  jest.useFakeTimers();
  const promise = service.retryableOperation();

  // Fast-forward time
  jest.advanceTimersByTime(5000);

  await expect(promise).resolves.toBe('success');
  jest.useRealTimers();
});
```

### Avoid: Test Anti-patterns
```typescript
// Bad: Testing implementation details
it('should call repository save method', () => {
  userService.createUser(data);
  expect(mockRepo.save).toHaveBeenCalled(); // Too coupled!
});

// Bad: No assertions
it('should do something', async () => {
  await userService.doSomething();
  // What are we testing?!
});

// Bad: Multiple behaviors in one test
it('should create user and send email and log event', async () => {
  // Testing too many things!
});

// Bad: Shared mutable state
let sharedUser;
beforeAll(() => { sharedUser = createUser(); });
// Tests modifying sharedUser affect each other!

// Bad: Hardcoded delays
it('should complete', async () => {
  await service.start();
  await new Promise(r => setTimeout(r, 1000)); // Flaky!
  expect(service.isReady).toBe(true);
});
```

---

## COMMON MISTAKES

### 1. Testing Implementation Instead of Behavior
**Why bad:** Refactoring breaks tests even when behavior unchanged
**Fix:** Test from the outside, verify outcomes

```typescript
// Bad: Coupled to implementation
expect(service['privateMethod']).toHaveBeenCalled();

// Good: Test the outcome
expect(result.status).toBe('processed');
```

### 2. Over-mocking
**Why bad:** Tests pass but real integration fails
**Fix:** Use real implementations where practical

```typescript
// Bad: Mocking everything
const mockDb = { find: jest.fn(), save: jest.fn() };
const mockCache = { get: jest.fn(), set: jest.fn() };
const mockLogger = { log: jest.fn() };
// Is this even testing anything real?

// Good: Test with real database (in-memory)
const db = new PrismaClient(); // Using test database
const service = new UserService(db);
```

### 3. Flaky Tests
**Why bad:** Developers lose trust, disable or ignore tests
**Fix:** Remove time dependencies, isolate state

```typescript
// Bad: Depends on real time
expect(user.createdAt.toDateString()).toBe(new Date().toDateString());

// Good: Inject time
const mockNow = new Date('2024-01-15');
jest.setSystemTime(mockNow);
expect(user.createdAt).toEqual(mockNow);
```

### 4. Too Many E2E Tests
**Why bad:** Slow, flaky, expensive to maintain
**Fix:** Test pyramid - unit > integration > E2E

```
E2E Tests: 5-10 critical user journeys
Integration Tests: API endpoints, database queries
Unit Tests: Business logic, utilities, validators
```

### 5. No Edge Cases
**Why bad:** Bugs hide in edge cases
**Fix:** Test boundaries and error conditions

```typescript
describe('divide', () => {
  it('divides two numbers', () => { /* happy path */ });
  it('throws when dividing by zero', () => { /* edge case */ });
  it('handles negative numbers', () => { /* edge case */ });
  it('handles very large numbers', () => { /* edge case */ });
  it('returns Infinity for small divisors', () => { /* edge case */ });
});
```

---

## DECISION TREE

```
What to test:
├── Business logic? → Unit test
├── API endpoint? → Integration test
├── Database query? → Integration test (with test DB)
├── UI component render? → Snapshot or component test
├── Critical user flow? → E2E test
└── External API integration? → Contract test + mock

When to mock:
├── External service (API, DB)? → Mock for unit tests
├── Internal dependency? → Prefer real implementation
├── Non-deterministic (time, random)? → Mock
├── Slow operation? → Mock in unit tests
└── Side effect (email, payment)? → Mock always

When NOT to mock:
├── Pure functions → Never mock
├── Data transformations → Never mock
├── Business rules → Rarely mock
└── If mocking makes test meaningless → Don't mock
```

---

## TEST STRUCTURE

```
tests/
├── unit/                    # Fast, isolated tests
│   ├── services/
│   │   └── user.service.test.ts
│   └── utils/
│       └── validation.test.ts
├── integration/             # Tests with real dependencies
│   ├── api/
│   │   └── users.api.test.ts
│   └── db/
│       └── user.repo.test.ts
├── e2e/                     # Full user journeys
│   ├── auth.e2e.test.ts
│   └── checkout.e2e.test.ts
├── fixtures/                # Shared test data
│   └── users.fixture.ts
├── factories/               # Test data generators
│   └── user.factory.ts
└── setup/                   # Test configuration
    ├── jest.setup.ts
    └── test-db.ts
```

---

## FRAMEWORK SNIPPETS

### Jest (JavaScript/TypeScript)
```typescript
// jest.config.js
module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  setupFilesAfterEnv: ['<rootDir>/tests/setup/jest.setup.ts'],
  coverageThreshold: {
    global: { branches: 80, functions: 80, lines: 80 },
  },
};
```

### Pytest (Python)
```python
# conftest.py
import pytest
from app import create_app
from app.db import db

@pytest.fixture
def app():
    app = create_app('testing')
    with app.app_context():
        db.create_all()
        yield app
        db.drop_all()

@pytest.fixture
def client(app):
    return app.test_client()
```

### Playwright (E2E)
```typescript
import { test, expect } from '@playwright/test';

test('user can complete checkout', async ({ page }) => {
  await page.goto('/products');
  await page.click('[data-testid="add-to-cart"]');
  await page.click('[data-testid="checkout"]');
  await page.fill('[name="email"]', 'test@example.com');
  await page.click('[data-testid="place-order"]');
  await expect(page.locator('.confirmation')).toBeVisible();
});
```

---

*Generated by NONSTOP Skill Creator*
