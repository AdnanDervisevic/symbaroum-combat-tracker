import { useCallback, useEffect, useRef, useState } from 'react'
import { toast } from 'react-toastify'
import type { EncounterState } from '../types'
import { onStorageError } from './storage'
import { isDown } from '../utils/toughness'
import { uid } from '../utils/core'

/** The three things the app says on its own, without being clicked. */

const BOTTOM_RIGHT = { position: 'bottom-right' } as const

/**
 * A failed localStorage write used to be a `console.warn`, so a full quota meant
 * the session quietly stopped saving and you found out by reloading. Say it
 * once, out loud, and then stop -- repeating it on every keystroke would be its
 * own kind of useless.
 */
export function useStorageAlert() {
  const warned = useRef(false)

  useEffect(() => {
    onStorageError((key, err) => {
      console.warn('Failed to write localStorage key ' + key, err)
      if (warned.current) return
      warned.current = true
      toast.error(
        'Browser storage is full — changes are no longer being saved. Export your data.',
        { ...BOTTOM_RIGHT, autoClose: false }
      )
    })
    return () => onStorageError(null)
  }, [])
}

/** How the round that just ended went. */
export function useRoundRecap(encounter: EncounterState) {
  const previousRound = useRef(encounter.round)

  useEffect(() => {
    const before = previousRound.current
    previousRound.current = encounter.round
    if (encounter.round <= before || encounter.members.length === 0) return

    const standing = encounter.members.filter((m) => !isDown(m.toughness)).length
    const down = encounter.members.length - standing
    toast.info(
      down > 0
        ? `Round ${before} complete — ${standing} standing, ${down} down`
        : `Round ${before} complete — All ${standing} combatants standing`,
      { ...BOTTOM_RIGHT, autoClose: 3000 }
    )
  }, [encounter.round, encounter.members])
}

export type PainFlash = { name: string; amount: number; id: string }

/** The full-screen flash when somebody takes a hit past their pain threshold. */
export function usePainFlash() {
  const [painFlash, setPainFlash] = useState<PainFlash | null>(null)

  useEffect(() => {
    if (!painFlash) return
    const timer = window.setTimeout(() => setPainFlash(null), 1600)
    return () => window.clearTimeout(timer)
  }, [painFlash])

  const flash = useCallback((name: string, amount: number) => {
    setPainFlash({ name, amount, id: uid('flash') })
  }, [])

  return { painFlash, flash }
}
