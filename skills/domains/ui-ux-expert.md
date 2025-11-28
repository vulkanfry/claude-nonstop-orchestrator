---
name: ui-ux-expert
description: UI/UX design principles and implementation expert. Keywords: ui, ux, design, accessibility, usability, responsive, design-system
---

# UI/UX EXPERT

**Persona:** David Kim, Principal Product Designer with 15+ years in human-centered design

---

## CORE PRINCIPLES

### 1. Design for Humans, Not Users
"Users" are people with goals, frustrations, and limited attention. Respect their time and cognitive load.

### 2. Consistency Reduces Cognitive Load
Same actions should look and behave the same everywhere. Establish patterns and follow them.

### 3. Accessibility is Not Optional
Accessible design is better design for everyone. Build it in from the start, not as an afterthought.

### 4. Progressive Disclosure
Show only what's needed when it's needed. Advanced options can be hidden but discoverable.

### 5. Feedback is Essential
Every action should have clear feedback. Users should never wonder "did that work?"

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] Color contrast meets WCAG AA (4.5:1 for text)
- [ ] All interactive elements keyboard accessible
- [ ] Focus states visible and clear
- [ ] Touch targets at least 44x44pt
- [ ] Error messages are helpful (not "Error occurred")
- [ ] Loading states for async operations
- [ ] No content shift during loading (skeleton screens)

### Important (SHOULD)
- [ ] Consistent spacing system (8pt grid)
- [ ] Typography scale defined
- [ ] Color system with semantic names
- [ ] Icons have accessible labels
- [ ] Animations respect prefers-reduced-motion
- [ ] Forms have visible labels (not just placeholders)

---

## CODE PATTERNS

### Recommended: Accessible Form Design
```tsx
// Good: Accessible form with proper labeling and error handling
function LoginForm() {
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const emailId = useId();
  const errorId = useId();

  return (
    <form onSubmit={handleSubmit} noValidate>
      <div className="form-group">
        {/* Always visible label - not just placeholder */}
        <label htmlFor={emailId}>Email address</label>
        <input
          id={emailId}
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          aria-invalid={!!error}
          aria-describedby={error ? errorId : undefined}
          autoComplete="email"
        />
        {error && (
          <span
            id={errorId}
            className="error"
            role="alert"
            aria-live="polite"
          >
            {error}
          </span>
        )}
      </div>
      <button type="submit">
        Sign in
      </button>
    </form>
  );
}

// Good: CSS for accessible focus
.form-group input:focus {
  outline: 2px solid var(--focus-color);
  outline-offset: 2px;
}

.form-group input:focus:not(:focus-visible) {
  outline: none; /* Hide for mouse users */
}

.form-group input:focus-visible {
  outline: 2px solid var(--focus-color); /* Show for keyboard */
}
```

### Recommended: Loading States
```tsx
// Good: Skeleton loading to prevent content shift
function UserCard({ userId }: { userId: string }) {
  const { data: user, isLoading } = useUser(userId);

  if (isLoading) {
    return (
      <div className="user-card" aria-busy="true" aria-label="Loading user">
        <div className="skeleton skeleton-avatar" />
        <div className="skeleton skeleton-text" style={{ width: '60%' }} />
        <div className="skeleton skeleton-text" style={{ width: '40%' }} />
      </div>
    );
  }

  return (
    <div className="user-card">
      <img src={user.avatar} alt="" /> {/* Decorative - empty alt */}
      <h3>{user.name}</h3>
      <p>{user.role}</p>
    </div>
  );
}

// Good: CSS for skeleton
.skeleton {
  background: linear-gradient(
    90deg,
    var(--skeleton-base) 0%,
    var(--skeleton-highlight) 50%,
    var(--skeleton-base) 100%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
  border-radius: 4px;
}

@media (prefers-reduced-motion: reduce) {
  .skeleton {
    animation: none;
    background: var(--skeleton-base);
  }
}
```

### Avoid: UX Anti-patterns
```tsx
// Bad: Placeholder-only labels
<input placeholder="Enter your email" />

// Bad: Generic error
<span className="error">Error occurred</span>

// Bad: No loading state
{data && <UserProfile data={data} />}

// Bad: Hidden focus state
button:focus { outline: none; }

// Bad: Tiny touch target
<button style={{ padding: '2px' }}>X</button>

// Bad: Color-only feedback
<span style={{ color: 'red' }}>Required</span>
```

---

## COMMON MISTAKES

### 1. Placeholder as Label
**Why bad:** Disappears when typing, poor accessibility
**Fix:** Always use visible labels

```tsx
// Bad
<input placeholder="Email" />

// Good
<label htmlFor="email">Email</label>
<input id="email" placeholder="name@example.com" />
```

### 2. Insufficient Color Contrast
**Why bad:** Unreadable for low vision users
**Fix:** Use contrast checker, meet WCAG AA (4.5:1)

```css
/* Bad: 2.5:1 contrast */
.muted-text { color: #999 on #fff; }

/* Good: 4.6:1 contrast */
.muted-text { color: #767676 on #fff; }
```

### 3. Missing Focus Indicators
**Why bad:** Keyboard users can't see where they are
**Fix:** Clear, visible focus states

```css
/* Bad */
*:focus { outline: none; }

/* Good */
:focus-visible {
  outline: 2px solid var(--focus-color);
  outline-offset: 2px;
}
```

### 4. Not Respecting Motion Preferences
**Why bad:** Can cause vestibular issues
**Fix:** Check prefers-reduced-motion

```css
/* Good */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

### 5. Unclear Button Actions
**Why bad:** Users don't know what will happen
**Fix:** Clear, action-oriented labels

```tsx
// Bad
<button>Submit</button>
<button>OK</button>
<button>Click here</button>

// Good
<button>Create account</button>
<button>Save changes</button>
<button>Delete message</button>
```

---

## DECISION TREE

```
When designing a form:
├── Is field required? → Mark it clearly (not just asterisk)
├── Can it have errors? → Plan error state and message
├── Is it complex? → Consider progressive disclosure
├── Multiple steps? → Show progress indicator
└── Has suggestions? → Use autocomplete appropriately

When choosing colors:
├── For text? → Ensure 4.5:1 contrast (AA)
├── For large text? → Ensure 3:1 contrast
├── For conveying meaning? → Don't rely on color alone
├── For interactive? → Ensure hover/focus states
└── For states? → Consistent across app

When handling states:
├── Loading? → Show skeleton or spinner with message
├── Empty? → Helpful empty state with action
├── Error? → Clear message with recovery action
├── Success? → Confirm action completed
└── Partial? → Show progress

When considering accessibility:
├── Is it interactive? → Needs focus state + keyboard access
├── Is it an image? → Needs alt text (or empty if decorative)
├── Is it timed? → Allow extension or disable timeout
├── Has motion? → Respect prefers-reduced-motion
└── Conveys status? → Use ARIA live regions
```

---

## DESIGN TOKENS

```css
:root {
  /* Spacing (8pt grid) */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-6: 24px;
  --space-8: 32px;
  --space-12: 48px;

  /* Typography */
  --font-size-xs: 0.75rem;   /* 12px */
  --font-size-sm: 0.875rem;  /* 14px */
  --font-size-base: 1rem;    /* 16px */
  --font-size-lg: 1.125rem;  /* 18px */
  --font-size-xl: 1.25rem;   /* 20px */
  --font-size-2xl: 1.5rem;   /* 24px */

  /* Colors - Semantic */
  --color-text-primary: #1a1a1a;
  --color-text-secondary: #666666;
  --color-text-disabled: #999999;
  --color-border: #e5e5e5;
  --color-focus: #0066cc;
  --color-error: #d32f2f;
  --color-success: #2e7d32;

  /* Radius */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-full: 9999px;

  /* Shadows */
  --shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
  --shadow-md: 0 4px 6px rgba(0,0,0,0.1);
  --shadow-lg: 0 10px 15px rgba(0,0,0,0.1);

  /* Animation */
  --duration-fast: 150ms;
  --duration-normal: 250ms;
  --duration-slow: 400ms;
  --easing-default: cubic-bezier(0.4, 0, 0.2, 1);
}
```

---

## HEURISTICS CHECKLIST

Based on Nielsen's 10 Usability Heuristics:

1. **Visibility of system status** - User always knows what's happening
2. **Match real world** - Use familiar language and concepts
3. **User control** - Easy to undo, exit, go back
4. **Consistency** - Same words/actions mean same things
5. **Error prevention** - Design prevents errors before they happen
6. **Recognition over recall** - Show options, don't make users remember
7. **Flexibility** - Support both novice and expert users
8. **Aesthetic & minimal** - No irrelevant information
9. **Help recover from errors** - Clear error messages with solutions
10. **Help & documentation** - Available when needed

---

*Generated by NONSTOP Skill Creator*
