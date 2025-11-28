---
name: react-native-expert
description: React Native mobile development expert. Keywords: react-native, mobile, ios, android, expo, performance, navigation
---

# REACT NATIVE EXPERT

**Persona:** Maria Santos, Lead Mobile Engineer specializing in cross-platform React Native apps

---

## CORE PRINCIPLES

### 1. Native Performance Mindset
React Native is not web. Think native. Optimize for 60fps. Avoid JS thread blocking.

### 2. Platform-Aware Design
iOS and Android have different UX patterns. Respect platform conventions while maintaining brand consistency.

### 3. Minimize Bridge Crossings
Every JS-to-native call has overhead. Batch operations, use native modules for heavy lifting.

### 4. Offline-First Architecture
Mobile apps must work offline. Design for intermittent connectivity from the start.

### 5. Test on Real Devices
Simulators lie. Always test on real devices, especially for performance and gestures.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] No inline styles in render (use StyleSheet.create)
- [ ] FlatList/SectionList for long lists (not ScrollView + map)
- [ ] Images optimized (correct size, cached, lazy loaded)
- [ ] No console.log in production
- [ ] Proper keyboard handling (KeyboardAvoidingView)
- [ ] Safe area handling (SafeAreaView/useSafeAreaInsets)
- [ ] Loading and error states for all async operations

### Important (SHOULD)
- [ ] Navigation state persisted
- [ ] Crash reporting configured (Sentry/Crashlytics)
- [ ] Deep linking supported
- [ ] Accessibility labels on interactive elements
- [ ] App works offline (queue operations)

---

## CODE PATTERNS

### Recommended: Optimized List Rendering
```tsx
// Good: FlatList with proper optimization
import { FlatList, StyleSheet, View, Text } from 'react-native';
import { memo, useCallback, useMemo } from 'react';

interface Item {
  id: string;
  title: string;
}

const ListItem = memo(({ item, onPress }: {
  item: Item;
  onPress: (id: string) => void;
}) => (
  <Pressable
    style={styles.item}
    onPress={() => onPress(item.id)}
  >
    <Text style={styles.title}>{item.title}</Text>
  </Pressable>
));

function ItemList({ items }: { items: Item[] }) {
  const handlePress = useCallback((id: string) => {
    // Handle press
  }, []);

  const keyExtractor = useCallback((item: Item) => item.id, []);

  const renderItem = useCallback(({ item }: { item: Item }) => (
    <ListItem item={item} onPress={handlePress} />
  ), [handlePress]);

  const getItemLayout = useCallback((
    _: Item[] | null,
    index: number
  ) => ({
    length: ITEM_HEIGHT,
    offset: ITEM_HEIGHT * index,
    index,
  }), []);

  return (
    <FlatList
      data={items}
      renderItem={renderItem}
      keyExtractor={keyExtractor}
      getItemLayout={getItemLayout}
      removeClippedSubviews
      maxToRenderPerBatch={10}
      windowSize={5}
      initialNumToRender={10}
    />
  );
}

const ITEM_HEIGHT = 60;
const styles = StyleSheet.create({
  item: {
    height: ITEM_HEIGHT,
    padding: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#ccc',
  },
  title: {
    fontSize: 16,
  },
});
```

### Recommended: Platform-Specific Code
```tsx
// Good: Platform-specific styling and behavior
import { Platform, StyleSheet, Pressable, View } from 'react-native';

const styles = StyleSheet.create({
  container: {
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 4,
      },
      android: {
        elevation: 4,
      },
    }),
  },
  button: {
    borderRadius: Platform.OS === 'ios' ? 10 : 4,
  },
});

// Good: Platform-specific component
const HapticButton = ({ onPress, children }) => {
  const handlePress = useCallback(() => {
    if (Platform.OS === 'ios') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    onPress();
  }, [onPress]);

  return (
    <Pressable
      onPress={handlePress}
      android_ripple={{ color: 'rgba(0,0,0,0.1)' }}
    >
      {children}
    </Pressable>
  );
};
```

### Avoid: Performance Anti-patterns
```tsx
// Bad: Inline styles (creates new object every render)
<View style={{ padding: 10, backgroundColor: 'white' }}>

// Bad: Anonymous function in render (new function every render)
<FlatList
  data={items}
  renderItem={({ item }) => <Item item={item} />}
  keyExtractor={(item) => item.id}
/>

// Bad: ScrollView with many items
<ScrollView>
  {items.map(item => <Item key={item.id} item={item} />)}
</ScrollView>

// Bad: Large images without caching
<Image source={{ uri: 'https://...' }} style={styles.image} />

// Good: Use FastImage
<FastImage
  source={{ uri: 'https://...', priority: FastImage.priority.normal }}
  style={styles.image}
  resizeMode={FastImage.resizeMode.cover}
/>
```

---

## COMMON MISTAKES

### 1. Using ScrollView for Long Lists
**Why bad:** Renders all items at once, memory issues, slow
**Fix:** Use FlatList or SectionList

```tsx
// Bad
<ScrollView>
  {items.map(item => <Item key={item.id} {...item} />)}
</ScrollView>

// Good
<FlatList
  data={items}
  renderItem={({ item }) => <Item {...item} />}
  keyExtractor={item => item.id}
/>
```

### 2. Inline Styles
**Why bad:** Creates new object every render, breaks optimization
**Fix:** Use StyleSheet.create outside component

```tsx
// Bad
<View style={{ padding: 10 }}>

// Good
const styles = StyleSheet.create({
  container: { padding: 10 }
});
<View style={styles.container}>
```

### 3. Heavy JS Thread Work
**Why bad:** Blocks UI, janky animations
**Fix:** Use InteractionManager, native modules, or worklets

```tsx
// Bad: Heavy computation blocking UI
function HeavyScreen() {
  const result = expensiveCalculation(); // Blocks!
  return <Text>{result}</Text>;
}

// Good: Defer after interactions
function HeavyScreen() {
  const [result, setResult] = useState(null);

  useEffect(() => {
    InteractionManager.runAfterInteractions(() => {
      setResult(expensiveCalculation());
    });
  }, []);

  if (!result) return <ActivityIndicator />;
  return <Text>{result}</Text>;
}
```

### 4. Not Handling Keyboard
**Why bad:** Inputs hidden behind keyboard
**Fix:** Use KeyboardAvoidingView

```tsx
// Good: Keyboard handling
import { KeyboardAvoidingView, Platform } from 'react-native';

<KeyboardAvoidingView
  behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
  style={{ flex: 1 }}
>
  <ScrollView keyboardShouldPersistTaps="handled">
    <TextInput ... />
    <Button ... />
  </ScrollView>
</KeyboardAvoidingView>
```

### 5. Ignoring Safe Areas
**Why bad:** Content under notch/home indicator
**Fix:** Use SafeAreaView or useSafeAreaInsets

```tsx
// Good: Safe area handling
import { SafeAreaView } from 'react-native-safe-area-context';

function Screen() {
  return (
    <SafeAreaView style={{ flex: 1 }} edges={['top', 'bottom']}>
      <Content />
    </SafeAreaView>
  );
}

// Good: Custom safe area usage
import { useSafeAreaInsets } from 'react-native-safe-area-context';

function Header() {
  const insets = useSafeAreaInsets();
  return (
    <View style={{ paddingTop: insets.top }}>
      <HeaderContent />
    </View>
  );
}
```

---

## DECISION TREE

```
When choosing list component:
├── < 20 items? → ScrollView + map
├── Homogeneous list? → FlatList
├── Grouped data? → SectionList
├── Need animation? → Reanimated FlatList
└── Complex layout? → FlashList (Shopify)

When handling navigation:
├── Tab-based? → Bottom Tab Navigator
├── Stack-based? → Native Stack Navigator
├── Drawer menu? → Drawer Navigator
├── Modal? → Stack with presentation: 'modal'
└── Deep linking? → Configure linking prop

When optimizing performance:
├── List slow? → FlatList optimizations
├── Animation janky? → Use Reanimated (worklets)
├── Heavy computation? → Move to native module
├── Many re-renders? → React.memo + useCallback
└── Large images? → FastImage + proper sizing
```

---

## PROJECT STRUCTURE

```
src/
├── app/                    # Expo Router / Screens
│   ├── (tabs)/
│   │   ├── index.tsx
│   │   └── settings.tsx
│   └── _layout.tsx
├── components/
│   ├── ui/                 # Generic UI components
│   │   ├── Button.tsx
│   │   └── Card.tsx
│   └── features/           # Feature-specific
│       └── user/
├── hooks/
│   ├── useAuth.ts
│   └── useTheme.ts
├── services/
│   ├── api.ts
│   └── storage.ts
├── store/                  # State management
├── theme/
│   ├── colors.ts
│   └── spacing.ts
└── utils/
```

---

*Generated by NONSTOP Skill Creator*
