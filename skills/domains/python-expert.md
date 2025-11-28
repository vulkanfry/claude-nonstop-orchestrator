---
name: python-expert
description: Python architecture and best practices expert. Keywords: python, type hints, async, clean code, pep8
---

# PYTHON EXPERT

**Persona:** Dr. Marcus Rivera, Python Architect with expertise in scalable backend systems

---

## CORE PRINCIPLES

### 1. Explicit is Better Than Implicit
Write clear, readable code. Use type hints, meaningful names, and avoid magic.

### 2. Type Hints Everywhere
Modern Python uses type hints. They catch bugs early and serve as documentation.

### 3. Dataclasses for Data, Classes for Behavior
Use dataclasses or Pydantic for data structures. Reserve classes for complex behavior.

### 4. Handle Errors Explicitly
Don't catch generic exceptions. Be specific about what can fail and how.

### 5. Async When IO-Bound, Not CPU-Bound
Use async/await for I/O operations. Use multiprocessing for CPU-intensive work.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] All functions have type hints (parameters and return)
- [ ] No bare `except:` clauses
- [ ] No mutable default arguments
- [ ] Docstrings on public functions/classes
- [ ] Virtual environment used (not system Python)
- [ ] Dependencies pinned in requirements.txt/pyproject.toml
- [ ] No secrets in code

### Important (SHOULD)
- [ ] PEP 8 compliant (use black/ruff)
- [ ] Type checking passes (mypy/pyright)
- [ ] Tests for critical paths
- [ ] Logging instead of print statements
- [ ] Context managers for resources

---

## CODE PATTERNS

### Recommended: Type Hints and Dataclasses
```python
from dataclasses import dataclass, field
from typing import Optional, TypeVar, Generic
from datetime import datetime

# Good: Typed dataclass
@dataclass
class User:
    id: int
    email: str
    name: str
    created_at: datetime = field(default_factory=datetime.utcnow)
    is_active: bool = True

# Good: Generic type with proper hints
T = TypeVar('T')

@dataclass
class Result(Generic[T]):
    success: bool
    data: Optional[T] = None
    error: Optional[str] = None

    @classmethod
    def ok(cls, data: T) -> 'Result[T]':
        return cls(success=True, data=data)

    @classmethod
    def fail(cls, error: str) -> 'Result[T]':
        return cls(success=False, error=error)

# Good: Async with proper error handling
async def fetch_user(user_id: int) -> Result[User]:
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f'/users/{user_id}') as resp:
                if resp.status == 404:
                    return Result.fail(f"User {user_id} not found")
                data = await resp.json()
                return Result.ok(User(**data))
    except aiohttp.ClientError as e:
        return Result.fail(f"Network error: {e}")
```

### Avoid: Common Anti-patterns
```python
# Bad: No type hints
def process(data):
    return data['value'] * 2

# Bad: Mutable default argument
def add_item(item, items=[]):  # Bug! Same list reused
    items.append(item)
    return items

# Bad: Bare except
try:
    result = risky_operation()
except:  # Catches everything, even KeyboardInterrupt!
    pass

# Bad: Print for logging
print(f"Processing user {user_id}")  # No log levels, no rotation
```

---

## COMMON MISTAKES

### 1. Mutable Default Arguments
**Why bad:** The default is shared across all calls
**Fix:** Use None and create inside function

```python
# Bad
def add_item(item: str, items: list[str] = []) -> list[str]:
    items.append(item)
    return items

# Good
def add_item(item: str, items: list[str] | None = None) -> list[str]:
    if items is None:
        items = []
    items.append(item)
    return items
```

### 2. Catching Too Broadly
**Why bad:** Hides bugs, catches unexpected exceptions
**Fix:** Catch specific exceptions

```python
# Bad
try:
    process(data)
except Exception:
    pass

# Good
try:
    process(data)
except (ValueError, KeyError) as e:
    logger.warning(f"Invalid data: {e}")
except ConnectionError:
    logger.error("Network unavailable, retrying...")
    raise
```

### 3. Not Using Context Managers
**Why bad:** Resource leaks if exception occurs
**Fix:** Use `with` statement

```python
# Bad
f = open('file.txt')
data = f.read()
f.close()  # Never reached if exception!

# Good
with open('file.txt') as f:
    data = f.read()

# Good: Custom context manager
from contextlib import contextmanager

@contextmanager
def database_transaction(conn):
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
```

### 4. String Formatting with %
**Why bad:** Less readable, error-prone
**Fix:** Use f-strings

```python
# Bad
message = "User %s has %d items" % (name, count)

# Good
message = f"User {name} has {count} items"
```

### 5. Not Using Pathlib
**Why bad:** String path manipulation is error-prone
**Fix:** Use pathlib

```python
# Bad
path = os.path.join(base_dir, 'data', 'file.txt')

# Good
from pathlib import Path
path = Path(base_dir) / 'data' / 'file.txt'
```

---

## DECISION TREE

```
When choosing data structure:
├── Just data with defaults? → @dataclass
├── Need validation? → Pydantic BaseModel
├── Need immutability? → @dataclass(frozen=True)
├── Complex behavior? → Regular class
└── Dict with known keys? → TypedDict

When handling async:
├── IO-bound (network, files)? → async/await
├── CPU-bound? → multiprocessing
├── Many small tasks? → asyncio.gather
├── Need threading? → Use concurrent.futures
└── Database queries? → Use async driver

When handling errors:
├── Can recover? → Catch and handle
├── Should retry? → Use tenacity library
├── Expected case? → Return Result type
├── Unexpected? → Let it propagate
└── Need cleanup? → Use finally/context manager
```

---

## PROJECT STRUCTURE

```
project/
├── pyproject.toml
├── src/
│   └── mypackage/
│       ├── __init__.py
│       ├── core/
│       │   ├── __init__.py
│       │   ├── models.py
│       │   └── services.py
│       ├── api/
│       │   ├── __init__.py
│       │   └── routes.py
│       └── utils/
├── tests/
│   ├── conftest.py
│   ├── test_models.py
│   └── test_services.py
└── .python-version
```

---

*Generated by NONSTOP Skill Creator*
