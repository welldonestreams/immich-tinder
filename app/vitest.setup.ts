// Vitest setup — in-memory localStorage that mirrors the real Storage
// interface (keys as own enumerable properties, so Object.keys() works),
// since jsdom's storage can be undefined in some version combos.
class MemoryStorage {
  [key: string]: unknown

  get length(): number {
    return Object.keys(this).length
  }

  clear(): void {
    for (const k of Object.keys(this)) delete this[k]
  }

  getItem(key: string): string | null {
    return Object.prototype.hasOwnProperty.call(this, key) ? (this[key] as string) : null
  }

  key(index: number): string | null {
    return Object.keys(this)[index] ?? null
  }

  removeItem(key: string): void {
    delete this[key]
  }

  setItem(key: string, value: string): void {
    this[key] = String(value)
  }
}

if (!globalThis.localStorage) {
  Object.defineProperty(globalThis, 'localStorage', {
    value: new MemoryStorage(),
    configurable: true,
  })
}

// jsdom lacks matchMedia — uiStore's dark-mode detection needs it
if (!globalThis.matchMedia) {
  Object.defineProperty(globalThis, 'matchMedia', {
    value: (query: string) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: () => {},
      removeListener: () => {},
      addEventListener: () => {},
      removeEventListener: () => {},
      dispatchEvent: () => false,
    }),
    configurable: true,
  })
}
