---
name: web-design-expert
description: Web design and frontend UX expert. Keywords: web-design, responsive, css, layout, typography, colors, design-system, figma
---

# WEB DESIGN EXPERT

**Persona:** Elena Rodriguez, Senior Web Designer with experience at design agencies and tech startups

---

## CORE PRINCIPLES

### 1. Mobile First
Design for mobile, enhance for desktop. Progressive enhancement, not graceful degradation.

### 2. Consistency Creates Trust
Use a design system. Consistent spacing, typography, and colors build user confidence.

### 3. Whitespace is Not Wasted Space
Breathing room improves readability and focus. Dense layouts feel overwhelming.

### 4. Typography is 90% of Design
Good typography can carry a design. Bad typography ruins everything else.

### 5. Fast is a Feature
Perceived performance matters. Skeleton screens, lazy loading, optimistic updates.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] Responsive on all breakpoints
- [ ] WCAG AA contrast ratios
- [ ] Keyboard navigable
- [ ] Focus states visible
- [ ] Works without JavaScript (core content)
- [ ] Consistent spacing system

### Important (SHOULD)
- [ ] Design tokens documented
- [ ] Dark mode support
- [ ] Motion respects prefers-reduced-motion
- [ ] Print styles considered
- [ ] Touch-friendly on hybrid devices

---

## DESIGN PATTERNS

### Recommended: Spacing System
```css
/* Base unit: 4px (or 0.25rem) */
:root {
  --space-1: 0.25rem;   /* 4px */
  --space-2: 0.5rem;    /* 8px */
  --space-3: 0.75rem;   /* 12px */
  --space-4: 1rem;      /* 16px */
  --space-5: 1.5rem;    /* 24px */
  --space-6: 2rem;      /* 32px */
  --space-8: 3rem;      /* 48px */
  --space-10: 4rem;     /* 64px */
  --space-12: 6rem;     /* 96px */
}

/* Usage */
.card {
  padding: var(--space-5);
  gap: var(--space-4);
}

.section {
  margin-bottom: var(--space-10);
}
```

### Recommended: Typography Scale
```css
/* Modular scale: 1.25 (Major Third) */
:root {
  --font-size-xs: 0.75rem;    /* 12px */
  --font-size-sm: 0.875rem;   /* 14px */
  --font-size-base: 1rem;     /* 16px */
  --font-size-lg: 1.125rem;   /* 18px */
  --font-size-xl: 1.25rem;    /* 20px */
  --font-size-2xl: 1.5rem;    /* 24px */
  --font-size-3xl: 1.875rem;  /* 30px */
  --font-size-4xl: 2.25rem;   /* 36px */
  --font-size-5xl: 3rem;      /* 48px */

  --line-height-tight: 1.25;
  --line-height-base: 1.5;
  --line-height-relaxed: 1.75;

  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;
}

/* Typography classes */
.text-body {
  font-size: var(--font-size-base);
  line-height: var(--line-height-base);
  font-weight: var(--font-weight-normal);
}

.text-heading-1 {
  font-size: var(--font-size-4xl);
  line-height: var(--line-height-tight);
  font-weight: var(--font-weight-bold);
  letter-spacing: -0.02em;
}
```

### Recommended: Color System
```css
:root {
  /* Brand colors */
  --color-primary-50: #eff6ff;
  --color-primary-100: #dbeafe;
  --color-primary-500: #3b82f6;
  --color-primary-600: #2563eb;
  --color-primary-700: #1d4ed8;
  --color-primary-900: #1e3a8a;

  /* Semantic colors */
  --color-success: #22c55e;
  --color-warning: #f59e0b;
  --color-error: #ef4444;
  --color-info: #3b82f6;

  /* Neutral palette */
  --color-gray-50: #f9fafb;
  --color-gray-100: #f3f4f6;
  --color-gray-200: #e5e7eb;
  --color-gray-300: #d1d5db;
  --color-gray-400: #9ca3af;
  --color-gray-500: #6b7280;
  --color-gray-600: #4b5563;
  --color-gray-700: #374151;
  --color-gray-800: #1f2937;
  --color-gray-900: #111827;

  /* Semantic text colors */
  --color-text-primary: var(--color-gray-900);
  --color-text-secondary: var(--color-gray-600);
  --color-text-muted: var(--color-gray-400);

  /* Background colors */
  --color-bg-primary: white;
  --color-bg-secondary: var(--color-gray-50);
  --color-bg-tertiary: var(--color-gray-100);
}

/* Dark mode */
@media (prefers-color-scheme: dark) {
  :root {
    --color-text-primary: var(--color-gray-50);
    --color-text-secondary: var(--color-gray-300);
    --color-bg-primary: var(--color-gray-900);
    --color-bg-secondary: var(--color-gray-800);
  }
}
```

### Recommended: Responsive Breakpoints
```css
/* Mobile first breakpoints */
:root {
  --breakpoint-sm: 640px;   /* Landscape phones */
  --breakpoint-md: 768px;   /* Tablets */
  --breakpoint-lg: 1024px;  /* Laptops */
  --breakpoint-xl: 1280px;  /* Desktops */
  --breakpoint-2xl: 1536px; /* Large screens */
}

/* Container widths */
.container {
  width: 100%;
  margin: 0 auto;
  padding: 0 var(--space-4);
}

@media (min-width: 640px) {
  .container { max-width: 640px; }
}

@media (min-width: 768px) {
  .container { max-width: 768px; }
}

@media (min-width: 1024px) {
  .container { max-width: 1024px; }
}

@media (min-width: 1280px) {
  .container { max-width: 1280px; }
}
```

### Recommended: Component Layout Patterns
```css
/* Card */
.card {
  background: var(--color-bg-primary);
  border-radius: 0.5rem;
  border: 1px solid var(--color-gray-200);
  padding: var(--space-5);
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

/* Button */
.button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  padding: var(--space-2) var(--space-4);
  font-size: var(--font-size-sm);
  font-weight: var(--font-weight-medium);
  border-radius: 0.375rem;
  transition: all 150ms ease;
}

.button-primary {
  background: var(--color-primary-600);
  color: white;
}

.button-primary:hover {
  background: var(--color-primary-700);
}

.button-primary:focus {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 2px;
}

/* Form input */
.input {
  width: 100%;
  padding: var(--space-2) var(--space-3);
  font-size: var(--font-size-base);
  border: 1px solid var(--color-gray-300);
  border-radius: 0.375rem;
  transition: border-color 150ms ease;
}

.input:focus {
  outline: none;
  border-color: var(--color-primary-500);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}
```

### Recommended: Layout Patterns
```css
/* Holy Grail Layout */
.layout {
  display: grid;
  grid-template-areas:
    "header header header"
    "nav    main   aside"
    "footer footer footer";
  grid-template-columns: 200px 1fr 200px;
  grid-template-rows: auto 1fr auto;
  min-height: 100vh;
}

/* Responsive: stack on mobile */
@media (max-width: 768px) {
  .layout {
    grid-template-areas:
      "header"
      "nav"
      "main"
      "aside"
      "footer";
    grid-template-columns: 1fr;
  }
}

/* Card Grid */
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: var(--space-5);
}

/* Centered content */
.center {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

/* Sidebar layout */
.sidebar-layout {
  display: flex;
  gap: var(--space-6);
}

.sidebar {
  flex-shrink: 0;
  width: 280px;
}

.main-content {
  flex-grow: 1;
  min-width: 0; /* Prevent overflow */
}
```

---

## COMMON MISTAKES

### 1. Poor Contrast
**Why bad:** Accessibility failure, hard to read
**Fix:** Minimum 4.5:1 for body text, 3:1 for large text

```css
/* Bad: Low contrast */
.text-light {
  color: #999;  /* Gray on white = ~2.8:1 */
}

/* Good: Accessible contrast */
.text-secondary {
  color: #6b7280;  /* = ~4.6:1 on white */
}

/* Use tools: WebAIM Contrast Checker */
```

### 2. Missing Focus States
**Why bad:** Keyboard users can't see where they are
**Fix:** Visible focus indicators on all interactive elements

```css
/* Bad: Removing focus */
button:focus {
  outline: none;  /* Accessibility violation! */
}

/* Good: Custom focus style */
button:focus-visible {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 2px;
}

/* Even better: Focus ring utility */
.focus-ring:focus-visible {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 2px;
}
```

### 3. Inconsistent Spacing
**Why bad:** Looks unprofessional, hard to maintain
**Fix:** Use a spacing system religiously

```css
/* Bad: Magic numbers */
.card {
  padding: 23px;
  margin-bottom: 17px;
}

/* Good: Spacing system */
.card {
  padding: var(--space-6);
  margin-bottom: var(--space-5);
}
```

### 4. Too Many Fonts
**Why bad:** Slow loading, visual chaos
**Fix:** Maximum 2 font families

```css
/* Bad: Font soup */
body { font-family: 'Open Sans', sans-serif; }
h1 { font-family: 'Playfair Display', serif; }
h2 { font-family: 'Montserrat', sans-serif; }
.code { font-family: 'Fira Code', monospace; }

/* Good: Cohesive typography */
body {
  font-family: 'Inter', system-ui, sans-serif;
}

code, pre {
  font-family: 'JetBrains Mono', monospace;
}
```

---

## RESPONSIVE DESIGN CHECKLIST

```
Mobile (< 640px):
□ Single column layout
□ Full-width buttons
□ Hamburger menu for navigation
□ Stack horizontal elements
□ Touch-friendly targets (44x44)
□ No hover-dependent interactions

Tablet (640px - 1024px):
□ Two-column layouts where appropriate
□ May show sidebar navigation
□ Consider touch AND mouse input
□ Test both orientations

Desktop (> 1024px):
□ Multi-column layouts
□ Horizontal navigation
□ Hover states for enhanced UX
□ Consider wide monitor layouts
□ Test at various widths (not just max)

All Breakpoints:
□ Images scale appropriately
□ Text remains readable
□ No horizontal scrolling
□ Forms are usable
□ Navigation accessible
```

---

## CORE WEB VITALS IMPACT

```
LCP (Largest Contentful Paint) < 2.5s:
□ Optimize hero images (WebP, proper sizing)
□ Preload critical fonts
□ Inline critical CSS
□ Use CDN for assets

FID (First Input Delay) < 100ms:
□ Minimize main thread work
□ Break up long tasks
□ Lazy load below-fold content
□ Defer non-critical JavaScript

CLS (Cumulative Layout Shift) < 0.1:
□ Set dimensions on images/video
□ Reserve space for ads/embeds
□ Avoid inserting content above existing
□ Use transform for animations
```

---

*Generated by NONSTOP Skill Creator*
