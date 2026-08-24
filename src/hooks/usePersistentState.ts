import { useEffect, useState } from 'react'
import { readStorage, versionedKey, writeStorage } from './storage'

export function usePersistentState<T>(
  key: string,
  initializer: () => T,
  migrateV1?: (raw: unknown) => T
) {
  const storageKey = versionedKey(key)

  const [state, setState] = useState<T>(() => readStorage(key, initializer, migrateV1))

  useEffect(() => {
    writeStorage(storageKey, state)
  }, [storageKey, state])

  return [state, setState] as const
}
