import { useCallback, useEffect } from 'react'
import type { AttributeKey, Character, CharacterAttributes } from '../types'
import { buildNewCharacter, normalizeAttributes } from '../utils/character'
import { removeMembersOfCharacter, syncFromRoster } from '../utils/encounter'
import type { StoredSession } from './useStoredSession'

/** Editing the roster, and the two places that have to reach into the fight. */
export function useRoster({ characters, setCharacters, setEncounter }: StoredSession) {
  // Mirror sheet edits into the combatants that came from them.
  //
  // This writes through the history-recording setter, so without a coalescing
  // key it is the per-keystroke undo bug by a side door: renaming a character
  // who is in the fight would push one encounter entry per letter. A shared key
  // collapses a run of roster edits into one, which is the right grain anyway --
  // these are consequences of an edit rather than edits.
  useEffect(() => {
    setEncounter((prev) => syncFromRoster(prev, characters), { coalesce: 'roster-sync' })
  }, [characters, setEncounter])

  const update = useCallback(
    (id: string, patch: Partial<Character>) => {
      setCharacters((prev) => prev.map((c) => (c.id === id ? { ...c, ...patch } : c)))
    },
    [setCharacters]
  )

  const add = useCallback(() => {
    setCharacters((prev) => [...prev, buildNewCharacter()])
  }, [setCharacters])

  const remove = useCallback(
    (id: string) => {
      if (!window.confirm('Delete this character?')) return
      setCharacters((prev) => prev.filter((c) => c.id !== id))
      // Pruning the encounter without repairing the turn cursor is what left the
      // highlight on a different combatant, or off the end of the array.
      setEncounter((prev) => removeMembersOfCharacter(prev, id))
    },
    [setCharacters, setEncounter]
  )

  const changeAttribute = useCallback(
    (id: string, key: AttributeKey, value: string) => {
      const numeric = value.trim() === '' ? null : Number(value)
      setCharacters((prev) =>
        prev.map((character) => {
          if (character.id !== id) return character
          const next: CharacterAttributes = { ...(character.attributes ?? {}) }
          if (numeric === null || Number.isNaN(numeric)) delete next[key]
          else next[key] = numeric
          return { ...character, attributes: normalizeAttributes(next) }
        })
      )
    },
    [setCharacters]
  )

  return { update, add, remove, changeAttribute }
}
