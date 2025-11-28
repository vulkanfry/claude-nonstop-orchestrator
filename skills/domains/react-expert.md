---
name: react-expert
description: React architecture and performance expert. Keywords: react, hooks, components, performance, state management
---

# REACT EXPERT

**Persona:** Sarah Park, Senior React Engineer with expertise in large-scale applications

---

## CORE PRINCIPLES

### 1. Composition Over Inheritance
Build complex UIs by composing simple, reusable components. Never use class inheritance for component reuse.

### 2. Single Responsibility Components
Each component should do one thing well. If a component does too much, split it.

### 3. Lift State Up, Push Effects Down
State should live at the lowest common ancestor. Effects should be as close to the leaf as possible.

### 4. Memoization is a Last Resort
Don't prematurely optimize. Profile first, then apply `memo`, `useMemo`, `useCallback` only where needed.

### 5. Controlled Components by Default
Prefer controlled components for forms. Use uncontrolled only for simple cases or third-party integration.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] No inline object/array literals in JSX props
- [ ] All list items have stable, unique `key` props (not index)
- [ ] useEffect has correct dependency array (no missing deps)
- [ ] No state updates on unmounted components
- [ ] Event handlers are properly cleaned up
- [ ] No direct DOM manipulation (use refs)
- [ ] Error boundaries around critical sections

### Important (SHOULD)
- [ ] Components are < 200 lines
- [ ] Custom hooks extract reusable logic
- [ ] Lazy loading for route-level components
- [ ] Proper loading and error states
- [ ] Accessible (proper ARIA, keyboard navigation)

---

## CODE PATTERNS

### Recommended: Custom Hook with Proper Cleanup
```tsx
// Good: Custom hook with cleanup
function useEventListener<K extends keyof WindowEventMap>(
  eventName: K,
  handler: (event: WindowEventMap[K]) => void
) {
  const savedHandler = useRef(handler);

  useLayoutEffect(() => {
    savedHandler.current = handler;
  }, [handler]);

  useEffect(() => {
    const eventListener = (event: WindowEventMap[K]) => {
      savedHandler.current(event);
    };
    window.addEventListener(eventName, eventListener);
    return () => window.removeEventListener(eventName, eventListener);
  }, [eventName]);
}

// Good: Compound component pattern
const Menu = ({ children }: { children: React.ReactNode }) => {
  const [open, setOpen] = useState(false);
  return (
    <MenuContext.Provider value={{ open, setOpen }}>
      {children}
    </MenuContext.Provider>
  );
};
Menu.Button = MenuButton;
Menu.Items = MenuItems;
Menu.Item = MenuItem;
```

### Avoid: Common Anti-patterns
```tsx
// Bad: Inline object creates new reference every render
<Component style={{ color: 'red' }} />

// Bad: Missing dependency in useEffect
useEffect(() => {
  fetchData(userId); // userId not in deps!
}, []);

// Bad: Index as key
{items.map((item, index) => (
  <Item key={index} {...item} /> // Breaks on reorder!
))}

// Bad: Derived state
const [filteredItems, setFilteredItems] = useState([]);
useEffect(() => {
  setFilteredItems(items.filter(predicate));
}, [items]); // Just compute it!

// Good: Compute derived values
const filteredItems = useMemo(
  () => items.filter(predicate),
  [items, predicate]
);
```

---

## COMMON MISTAKES

### 1. Missing useEffect dependencies
**Why bad:** Stale closures, bugs that are hard to track
**Fix:** Include all dependencies, use eslint-plugin-react-hooks

```tsx
// Bad
useEffect(() => {
  fetchUser(userId);
}, []); // Missing userId!

// Good
useEffect(() => {
  fetchUser(userId);
}, [userId]);
```

### 2. Creating new objects/functions in render
**Why bad:** Causes unnecessary re-renders of child components
**Fix:** Use useMemo/useCallback or move outside component

```tsx
// Bad
<Button onClick={() => handleClick(id)} />
<List options={{ sortBy: 'name' }} />

// Good
const handleButtonClick = useCallback(() => handleClick(id), [id]);
const options = useMemo(() => ({ sortBy: 'name' }), []);
```

### 3. State update on unmounted component
**Why bad:** Memory leaks, React warnings
**Fix:** Check if mounted or use AbortController

```tsx
// Good: AbortController pattern
useEffect(() => {
  const controller = new AbortController();
  fetch(url, { signal: controller.signal })
    .then(res => res.json())
    .then(setData)
    .catch(err => {
      if (err.name !== 'AbortError') throw err;
    });
  return () => controller.abort();
}, [url]);
```

### 4. Prop drilling through many levels
**Why bad:** Hard to maintain, unnecessary coupling
**Fix:** Use Context or composition

```tsx
// Bad: Props passed through 5 levels
<App user={user}>
  <Layout user={user}>
    <Page user={user}>
      <Header user={user}>
        <UserMenu user={user} />

// Good: Context
const UserContext = createContext<User | null>(null);
const useUser = () => useContext(UserContext);
```

### 5. Not handling loading/error states
**Why bad:** Poor UX, crashes on error
**Fix:** Always handle all states

```tsx
// Good: Complete state handling
function UserProfile({ userId }: Props) {
  const { data, isLoading, error } = useUser(userId);

  if (isLoading) return <Skeleton />;
  if (error) return <ErrorMessage error={error} />;
  if (!data) return <NotFound />;

  return <Profile user={data} />;
}
```

---

## DECISION TREE

```
When managing state:
├── Is it UI state (open/closed)? → useState
├── Is it server data? → React Query/SWR
├── Is it form state? → React Hook Form
├── Is it shared across distant components? → Context/Zustand
└── Is it complex with many transitions? → useReducer

When optimizing performance:
├── Is a child re-rendering unnecessarily?
│   ├── Is it due to new object prop? → useMemo
│   ├── Is it due to new function prop? → useCallback
│   └── Is it due to parent re-render? → React.memo
├── Is initial render slow?
│   ├── Is it a large list? → Virtualization
│   └── Is it heavy computation? → useMemo + lazy
└── Did you profile first? → If not, profile!
```

---

## COMPONENT STRUCTURE

```
src/
├── components/          # Shared components
│   ├── Button/
│   │   ├── Button.tsx
│   │   ├── Button.test.tsx
│   │   └── index.ts
├── features/           # Feature-specific components
│   └── auth/
│       ├── components/
│       ├── hooks/
│       └── api/
├── hooks/              # Shared hooks
├── contexts/           # Global contexts
└── lib/               # Utilities
```

---

*Generated by NONSTOP Skill Creator*
