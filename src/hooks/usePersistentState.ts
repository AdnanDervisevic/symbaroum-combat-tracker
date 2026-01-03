import { useEffect, useState } from 'react'

const STORAGE_VERSION = 1

function getVersionedKey(key: string): string {
  // Convert sct.foo to sct.v1.foo
  if (key.startsWith('sct.')) {
    return `sct.v${STORAGE_VERSION}.${key.slice(4)}`
  }
  return key
}

function migrateFromOldKey<T>(oldKey: string, newKey: string): T | null {
  try {
    const raw = window.localStorage.getItem(oldKey)
    if (!raw) return null
    const data = JSON.parse(raw) as T
    // Migrate to new key and remove old key
    window.localStorage.setItem(newKey, raw)
    window.localStorage.removeItem(oldKey)
    console.info(`Migrated localStorage from ${oldKey} to ${newKey}`)
    return data
  } catch {
    return null
  }
}

export function usePersistentState<T>(key: string, initializer: () => T) {
  const versionedKey = getVersionedKey(key)

  const [state, setState] = useState<T>(() => {
    if (typeof window === 'undefined') return initializer()
    try {
      // Try versioned key first
      const raw = window.localStorage.getItem(versionedKey)
      if (raw) return JSON.parse(raw) as T

      // Try migrating from old unversioned key
      const migrated = migrateFromOldKey<T>(key, versionedKey)
      if (migrated !== null) return migrated

      return initializer()
    } catch (err) {
      console.warn('Failed to parse localStorage key ' + versionedKey, err)
      return initializer()
    }
  })

  useEffect(() => {
    try {
      window.localStorage.setItem(versionedKey, JSON.stringify(state))
    } catch (err) {
      console.warn('Failed to save localStorage key ' + versionedKey, err)
    }
  }, [versionedKey, state])

  return [state, setState] as const
}

export { STORAGE_VERSION }
