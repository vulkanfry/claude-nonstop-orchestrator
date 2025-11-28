---
name: mobile-design-expert
description: Mobile app design and UX expert. Keywords: mobile, ios, android, app-design, touch, gestures, navigation, mobile-ux, responsive
---

# MOBILE DESIGN EXPERT

**Persona:** Yuki Tanaka, Lead Mobile Designer at a top-10 app company with 500M+ downloads

---

## CORE PRINCIPLES

### 1. Thumb-First Design
Design for one-handed use. Critical actions must be reachable by thumb.

### 2. Content is King
Every pixel is precious on mobile. Prioritize content, minimize chrome.

### 3. Touch Targets Matter
44pt minimum touch targets. Spacing prevents mis-taps.

### 4. Performance is UX
Slow apps feel broken. 60fps animations, instant feedback, fast load times.

### 5. Context Awareness
Mobile is used everywhere - bright sunlight, moving vehicles, one-handed. Design for distraction.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] Touch targets minimum 44x44pt
- [ ] Works in portrait AND landscape
- [ ] Supports dark mode
- [ ] Accessible (screen reader tested)
- [ ] Works offline (graceful degradation)
- [ ] Fast launch (<2 seconds)

### Important (SHOULD)
- [ ] Follows platform conventions (iOS/Android)
- [ ] Haptic feedback for key actions
- [ ] Pull-to-refresh where appropriate
- [ ] Keyboard doesn't cover inputs
- [ ] Safe area insets respected

---

## DESIGN PATTERNS

### Recommended: Navigation Patterns

```
Bottom Navigation (Tab Bar)
├── Best for: 3-5 top-level destinations
├── Use when: User switches between sections frequently
├── Platform: Works on iOS and Android
└── Example: Instagram, Spotify

Navigation Drawer (Hamburger Menu)
├── Best for: 5+ destinations, infrequent switching
├── Use when: Screen real estate is critical
├── Platform: Android native, iOS less common
└── Example: Gmail, Google Maps

Top Tabs
├── Best for: 2-4 related views
├── Use when: Content can be swiped between
├── Platform: Both, more common on Android
└── Example: Twitter profile (Tweets/Replies/Media)

Hierarchical (Push)
├── Best for: Drill-down navigation
├── Use when: Content has parent-child relationships
├── Platform: iOS native, Android with toolbar
└── Example: Settings app
```

### Recommended: Thumb Zone Design
```
╔═══════════════════════════════════════╗
║                                       ║
║           Hard to Reach               ║  Status bar
║             (Avoid)                   ║
║                                       ║
╠═══════════════════════════════════════╣
║                                       ║
║         OK - Secondary Actions        ║  Content area
║                                       ║
║                                       ║
╠═══════════════════════════════════════╣
║                                       ║
║         EASY - Primary Actions        ║  Thumb zone
║                                       ║
║    [Tab] [Tab] [Main] [Tab] [Tab]    ║  Bottom nav
╚═══════════════════════════════════════╝

Rules:
- Primary actions in bottom 1/3
- Destructive actions NOT in thumb zone
- FAB (Floating Action Button) in bottom-right
- Avoid top-right for critical actions
```

### Recommended: Touch Targets
```
Minimum sizes:
┌─────────────────────────────────────────────┐
│ iOS Human Interface Guidelines: 44x44 pt    │
│ Android Material Design: 48x48 dp           │
│ WCAG 2.1 AAA: 44x44 CSS pixels             │
└─────────────────────────────────────────────┘

Spacing between targets:
┌─────────────────────────────────────────────┐
│ Minimum: 8pt between targets                │
│ Recommended: 16pt for critical actions      │
└─────────────────────────────────────────────┘

Examples:

// Bad: Too small
<TouchableOpacity style={{ padding: 4 }}>
  <Icon size={16} />
</TouchableOpacity>

// Good: Proper touch target
<TouchableOpacity
  style={{ padding: 12, minWidth: 44, minHeight: 44 }}
  hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
>
  <Icon size={24} />
</TouchableOpacity>
```

### Recommended: Form Design
```
Input Field Best Practices:
─────────────────────────────────────────────
✓ Large input fields (48pt+ height)
✓ Clear labels ABOVE inputs (not placeholder only)
✓ Show/hide password toggle
✓ Appropriate keyboard type (email, number, phone)
✓ Auto-capitalization settings
✓ Next/Done button in keyboard toolbar
✓ Auto-focus first field
✓ Inline validation with clear errors
✓ Progress indicator for multi-step forms

// React Native example
<TextInput
  style={{ height: 48, fontSize: 16 }}
  placeholder="Email"
  keyboardType="email-address"
  autoCapitalize="none"
  autoCorrect={false}
  returnKeyType="next"
  onSubmitEditing={() => passwordRef.current?.focus()}
/>
```

### Recommended: Loading States
```
Loading Best Practices:
─────────────────────────────────────────────
Skeleton screens > Spinners > Progress bars

// Good: Skeleton placeholder
┌─────────────────────────────────────┐
│  ████  █████████████████           │
│        █████████████               │
│                                     │
│  ████  █████████████████           │
│        █████████████               │
└─────────────────────────────────────┘

// Bad: Blocking spinner
┌─────────────────────────────────────┐
│                                     │
│                                     │
│            ⟳ Loading...             │
│                                     │
│                                     │
└─────────────────────────────────────┘

Rules:
- < 100ms: No loading indicator
- 100ms - 1s: Simple animation
- > 1s: Skeleton or progress
- > 10s: Progress with cancel option
```

### Recommended: Gestures
```
Standard Gestures:
─────────────────────────────────────────────
Tap          → Primary action
Long Press   → Secondary menu / Selection mode
Swipe L/R    → Navigation / Actions (delete, archive)
Swipe Down   → Refresh / Dismiss
Pinch        → Zoom
Double Tap   → Zoom / Like

Swipe Action Rules:
- Maximum 2 actions per direction
- Leading swipe: Positive actions (archive, read)
- Trailing swipe: Destructive actions (delete)
- Full swipe executes primary action
- Partial swipe shows options

// React Native Gesture Example
<Swipeable
  renderLeftActions={() => (
    <ArchiveAction />
  )}
  renderRightActions={() => (
    <DeleteAction />
  )}
>
  <ListItem />
</Swipeable>
```

### Recommended: Empty States
```
Empty State Components:
─────────────────────────────────────────────
┌─────────────────────────────────────┐
│                                     │
│           [Illustration]            │
│                                     │
│         No messages yet             │  Title
│                                     │
│   Start a conversation with your    │  Description
│   friends and family                │
│                                     │
│        [ Send Message ]             │  CTA
│                                     │
└─────────────────────────────────────┘

Rules:
✓ Friendly illustration (not error icon)
✓ Clear explanation of why empty
✓ Actionable CTA when possible
✓ Don't blame the user
✓ Match brand voice
```

---

## COMMON MISTAKES

### 1. Ignoring Safe Areas
**Why bad:** Content hidden by notches, home indicators
**Fix:** Always respect safe area insets

```typescript
// React Native
import { SafeAreaView } from 'react-native-safe-area-context';

// Good: Respects notch and home indicator
<SafeAreaView style={{ flex: 1 }}>
  <Content />
</SafeAreaView>

// For bottom sheets/modals
<View style={{ paddingBottom: insets.bottom }}>
  <ActionButtons />
</View>
```

### 2. Text Too Small
**Why bad:** Unreadable, accessibility failure
**Fix:** Minimum 16pt body text

```
Typography Scale:
─────────────────────────────────────────────
Caption:    12pt (secondary info only)
Body:       16pt (minimum for readability)
Subtitle:   18pt
Title:      20-24pt
Headline:   28-34pt

// Bad
<Text style={{ fontSize: 12 }}>
  Important information here
</Text>

// Good
<Text style={{ fontSize: 16, lineHeight: 24 }}>
  Important information here
</Text>
```

### 3. No Feedback on Touch
**Why bad:** Users don't know if tap registered
**Fix:** Immediate visual + haptic feedback

```typescript
// Good: Visual feedback
<Pressable
  onPress={handlePress}
  style={({ pressed }) => ({
    opacity: pressed ? 0.7 : 1,
    transform: [{ scale: pressed ? 0.98 : 1 }],
  })}
>
  <ButtonContent />
</Pressable>

// Good: Haptic feedback
import * as Haptics from 'expo-haptics';

const handlePress = () => {
  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  // ... action
};
```

### 4. Blocking Modals for Errors
**Why bad:** Interrupts user flow, annoying
**Fix:** Inline errors, snackbars for dismissible messages

```
Error Display Hierarchy:
─────────────────────────────────────────────
1. Inline (best) - Below the field that has error
2. Banner - Top of screen, non-blocking
3. Snackbar - Bottom, auto-dismiss
4. Modal (last resort) - Only for critical, blocking errors
```

---

## PLATFORM DIFFERENCES

```
iOS vs Android Design:
─────────────────────────────────────────────
                    iOS           Android
Navigation        Bottom tab     Bottom nav/Drawer
Back button       Top-left       System back
Primary action    Right          FAB
Selection         Checkmarks     Checkboxes
Switches          iOS style      Material style
Typography        SF Pro         Roboto
Corners           Rounded        Slightly rounded
Shadows           Subtle         Elevation system

Approach:
├── Cross-platform: Shared design language, minor adaptations
├── Platform-native: Different designs per platform
└── Hybrid: Core UX shared, platform chrome different
```

---

## ACCESSIBILITY CHECKLIST

```
Mobile A11y Must-Haves:
□ VoiceOver/TalkBack tested
□ Touch targets 44x44pt minimum
□ Color contrast 4.5:1 minimum
□ Don't rely on color alone
□ Text scalable (Dynamic Type / Font Scaling)
□ Motion can be reduced
□ Focus order logical
□ Meaningful labels for icons
□ Captions for video
□ Haptic alternatives for audio cues
```

---

*Generated by NONSTOP Skill Creator*
