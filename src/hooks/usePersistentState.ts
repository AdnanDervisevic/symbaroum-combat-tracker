import { useEffect, useState } from 'react'

export function usePersistentState<T>(key: string, initializer: () => T) {
  const [state, setState] = useState<T>(() => {
    if (typeof window === 'undefined') return initializer()
    try {
      const raw = window.localStorage.getItem(key)
      if (!raw) return initializer()
      return JSON.parse(raw) as T
    } catch (err) {
      console.warn('Failed to parse localStorage key ' + key, err)
      return initializer()
    }
  })

  useEffect(() => {
    try {
      window.localStorage.setItem(key, JSON.stringify(state))
    } catch (err) {
      console.warn('Failed to save localStorage key ' + key, err)
    }
  }, [key, state])

  return [state, setState] as const
}
