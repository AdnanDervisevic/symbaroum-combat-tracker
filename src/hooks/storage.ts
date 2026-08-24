const STORAGE_VERSION = 2

export const versionedKey = (key: string, version = STORAGE_VERSION): string =>
  key.startsWith('sct.') ? `sct.v${version}.${key.slice(4)}` : key

/**
 * Somewhere to send a localStorage failure that is not the console.
 *
 * A `QuotaExceededError` used to be swallowed by a `console.warn`, so a session
 * silently stopped persisting and you found out by reloading. The app registers
 * a handler and tells you the first time it happens.
 */
export type StorageErrorHandler = (key: string, err: unknown) => void

let handler: StorageErrorHandler | null = null

export function onStorageError(next: StorageErrorHandler | null) {
  handler = next
}

export function reportStorageError(key: string, err: unknown) {
  if (handler) handler(key, err)
  else console.warn('Failed to write localStorage key ' + key, err)
}

export function writeStorage(key: string, value: unknown): boolean {
  try {
    window.localStorage.setItem(key, JSON.stringify(value))
    return true
  } catch (err) {
    reportStorageError(key, err)
    return false
  }
}

/**
 * Load `key`, newest format first.
 *
 * Version 1 data is migrated but **not deleted** — it stays where it is as a
 * backup, because this runs against data somebody is using at a table.
 */
export function readStorage<T>(key: string, fallback: () => T, migrateV1?: (raw: unknown) => T): T {
  if (typeof window === 'undefined') return fallback()
  const current = versionedKey(key)
  try {
    const raw = window.localStorage.getItem(current)
    if (raw) return JSON.parse(raw) as T

    // v1, then the unversioned keys that predate versioning at all.
    const older = window.localStorage.getItem(versionedKey(key, 1)) ?? window.localStorage.getItem(key)
    if (older && migrateV1) {
      const migrated = migrateV1(JSON.parse(older))
      writeStorage(current, migrated)
      return migrated
    }
    return fallback()
  } catch (err) {
    console.warn('Failed to read localStorage key ' + current, err)
    return fallback()
  }
}
