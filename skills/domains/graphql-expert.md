---
name: graphql-expert
description: GraphQL API design and implementation expert. Keywords: graphql, apollo, relay, schema, resolvers, mutations, subscriptions, federation
---

# GRAPHQL EXPERT

**Persona:** Sophie Martinez, API Architect specializing in GraphQL at scale

---

## CORE PRINCIPLES

### 1. Schema First
Design your schema before implementation. The schema IS your API contract.

### 2. Think in Graphs
Model relationships, not endpoints. Let clients ask for exactly what they need.

### 3. Single Source of Truth
One graph, one schema. Use federation for microservices, not multiple GraphQL servers.

### 4. Performance by Design
N+1 is the enemy. Use DataLoader from day one. Monitor query complexity.

### 5. Evolution Over Versioning
Deprecate fields, don't version the API. Add new fields freely, remove carefully.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] DataLoader for all database/API calls
- [ ] Query complexity limits
- [ ] Query depth limits
- [ ] Authentication on all mutations
- [ ] Input validation on all arguments
- [ ] Error handling returns useful messages

### Important (SHOULD)
- [ ] Pagination on all list fields (Relay-style)
- [ ] @deprecated on fields being removed
- [ ] Schema documentation (descriptions)
- [ ] Persisted queries in production
- [ ] Query logging and tracing

---

## CODE PATTERNS

### Recommended: Schema Design
```graphql
# Good: Clear types with descriptions
"""
A user in the system
"""
type User {
  id: ID!
  email: String!
  name: String!
  """
  User's avatar URL. Returns null if no avatar set.
  """
  avatarUrl: String

  """
  Orders placed by this user.
  Uses cursor-based pagination.
  """
  orders(
    first: Int
    after: String
    filter: OrderFilter
  ): OrderConnection!

  createdAt: DateTime!
  updatedAt: DateTime!
}

# Good: Relay-style pagination
type OrderConnection {
  edges: [OrderEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type OrderEdge {
  node: Order!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

# Good: Input types for mutations
input CreateUserInput {
  email: String!
  name: String!
  password: String!
}

# Good: Mutation payloads with errors
type CreateUserPayload {
  user: User
  errors: [UserError!]!
}

type UserError {
  field: String
  message: String!
  code: ErrorCode!
}
```

### Recommended: DataLoader Pattern
```typescript
import DataLoader from 'dataloader';

// Good: Batch loading to prevent N+1
function createLoaders(db: Database) {
  return {
    userLoader: new DataLoader<string, User>(async (ids) => {
      const users = await db.users.findMany({
        where: { id: { in: ids as string[] } },
      });
      // Must return in same order as input ids
      const userMap = new Map(users.map(u => [u.id, u]));
      return ids.map(id => userMap.get(id) || null);
    }),

    ordersByUserLoader: new DataLoader<string, Order[]>(async (userIds) => {
      const orders = await db.orders.findMany({
        where: { userId: { in: userIds as string[] } },
      });
      // Group by userId
      const orderMap = new Map<string, Order[]>();
      orders.forEach(o => {
        const list = orderMap.get(o.userId) || [];
        list.push(o);
        orderMap.set(o.userId, list);
      });
      return userIds.map(id => orderMap.get(id) || []);
    }),
  };
}

// Usage in resolvers
const resolvers = {
  Query: {
    user: (_, { id }, { loaders }) => loaders.userLoader.load(id),
  },
  User: {
    orders: (user, _, { loaders }) => loaders.ordersByUserLoader.load(user.id),
  },
};
```

### Recommended: Query Complexity Limiting
```typescript
import { createComplexityLimitRule } from 'graphql-validation-complexity';

const complexityRule = createComplexityLimitRule(1000, {
  scalarCost: 1,
  objectCost: 10,
  listFactor: 10,
  onCost: (cost) => {
    console.log(`Query cost: ${cost}`);
  },
});

const server = new ApolloServer({
  schema,
  validationRules: [complexityRule],
  plugins: [
    {
      requestDidStart: () => ({
        didResolveOperation({ request, document }) {
          // Log query for debugging
          console.log('Query:', request.query);
        },
      }),
    },
  ],
});
```

### Recommended: Error Handling
```typescript
import { GraphQLError } from 'graphql';

// Good: Structured errors
class NotFoundError extends GraphQLError {
  constructor(resource: string, id: string) {
    super(`${resource} not found: ${id}`, {
      extensions: {
        code: 'NOT_FOUND',
        resource,
        id,
      },
    });
  }
}

class ValidationError extends GraphQLError {
  constructor(field: string, message: string) {
    super(message, {
      extensions: {
        code: 'VALIDATION_ERROR',
        field,
      },
    });
  }
}

// Good: Mutation with user-friendly errors
const resolvers = {
  Mutation: {
    createUser: async (_, { input }, { db }) => {
      const errors: UserError[] = [];

      // Validation
      if (!isValidEmail(input.email)) {
        errors.push({ field: 'email', message: 'Invalid email format', code: 'INVALID_FORMAT' });
      }

      const existing = await db.users.findByEmail(input.email);
      if (existing) {
        errors.push({ field: 'email', message: 'Email already registered', code: 'DUPLICATE' });
      }

      if (errors.length > 0) {
        return { user: null, errors };
      }

      const user = await db.users.create(input);
      return { user, errors: [] };
    },
  },
};
```

### Recommended: Authentication & Authorization
```typescript
import { AuthenticationError, ForbiddenError } from 'apollo-server';

// Good: Context-based auth
const server = new ApolloServer({
  context: async ({ req }) => {
    const token = req.headers.authorization?.replace('Bearer ', '');
    const user = token ? await verifyToken(token) : null;
    return { user, loaders: createLoaders(db) };
  },
});

// Good: Field-level authorization
const resolvers = {
  Query: {
    me: (_, __, { user }) => {
      if (!user) throw new AuthenticationError('Must be logged in');
      return user;
    },
    adminDashboard: (_, __, { user }) => {
      if (!user) throw new AuthenticationError('Must be logged in');
      if (user.role !== 'ADMIN') throw new ForbiddenError('Admin only');
      return getDashboard();
    },
  },
  User: {
    // Hide email from other users
    email: (user, _, { user: currentUser }) => {
      if (currentUser?.id === user.id || currentUser?.role === 'ADMIN') {
        return user.email;
      }
      return null;
    },
  },
};
```

### Avoid: Anti-patterns
```graphql
# Bad: REST-like design
type Query {
  getUser(id: ID!): User          # Don't prefix with "get"
  getAllUsers: [User!]!           # Don't use "getAll"
  fetchUserOrders(userId: ID!): [Order!]!  # Don't prefix with "fetch"
}

# Good: Graph thinking
type Query {
  user(id: ID!): User
  users(filter: UserFilter, first: Int, after: String): UserConnection!
}

type User {
  orders(first: Int, after: String): OrderConnection!  # Navigate the graph
}

# Bad: No pagination
type Query {
  allProducts: [Product!]!  # Could return millions of products!
}

# Good: Always paginate lists
type Query {
  products(first: Int!, after: String, filter: ProductFilter): ProductConnection!
}
```

---

## COMMON MISTAKES

### 1. N+1 Query Problem
**Why bad:** One query per item in a list
**Fix:** Always use DataLoader

```typescript
// Bad: N+1 queries
User: {
  orders: async (user, _, { db }) => {
    return db.orders.findMany({ where: { userId: user.id } });
  }
}

// Good: Batched with DataLoader
User: {
  orders: (user, _, { loaders }) => loaders.ordersByUserLoader.load(user.id),
}
```

### 2. No Query Depth/Complexity Limits
**Why bad:** Malicious queries can DoS your server
**Fix:** Add depth and complexity limits

```typescript
// Good: Limit query depth
import depthLimit from 'graphql-depth-limit';

const server = new ApolloServer({
  validationRules: [depthLimit(10)],
});
```

### 3. Exposing Internal Errors
**Why bad:** Security risk, bad UX
**Fix:** Sanitize errors in production

```typescript
const server = new ApolloServer({
  formatError: (error) => {
    // Log full error internally
    logger.error(error);

    // Don't expose internal errors to clients
    if (error.extensions?.code === 'INTERNAL_SERVER_ERROR') {
      return new GraphQLError('Internal server error');
    }
    return error;
  },
});
```

### 4. Not Using Persisted Queries
**Why bad:** Large queries sent every request, security risk
**Fix:** Use automatic persisted queries (APQ)

```typescript
import { ApolloServerPluginCacheControl } from 'apollo-server-core';

const server = new ApolloServer({
  persistedQueries: {
    cache: new RedisCache({ host: 'redis' }),
  },
});
```

---

## DECISION TREE

```
Schema design:
├── One-to-many relationship? → Field on parent returning Connection
├── Many-to-many? → Join type or Connection on both sides
├── Computed field? → Resolver with caching
├── Sensitive field? → Check auth in resolver
└── List that could be large? → Use pagination (Connection)

Mutations:
├── Creating resource? → Return created object + errors
├── Updating resource? → Return updated object + errors
├── Deleting resource? → Return success boolean + errors
├── Bulk operation? → Return list of results + errors
└── Async operation? → Return job/task ID, use subscription for updates

Performance:
├── Same data requested multiple times? → DataLoader
├── Expensive computation? → Cache at resolver level
├── Large response? → Pagination + field selection
├── Real-time updates needed? → Subscriptions
└── Slow resolver? → @defer directive (if supported)
```

---

*Generated by NONSTOP Skill Creator*
