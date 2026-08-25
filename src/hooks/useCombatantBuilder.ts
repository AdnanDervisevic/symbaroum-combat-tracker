import { useCallback, useState } from 'react'
import type { FormEvent } from 'react'
import type { BestiaryEntry, NpcDraft } from '../types'
import type { MonsterPreset } from '../data/defaultMonsters'
import {
  bestiaryEntryFromDraft,
  draftFromBestiaryEntry,
  draftFromPreset,
  emptyDraft,
} from '../utils/draft'
import { addNpcs, addPlayerCharacters } from '../utils/encounter'
import { uid } from '../utils/core'
import type { StoredSession } from './useStoredSession'

/**
 * The Manage Combatants dialog: which player characters are ticked, what the NPC
 * form holds, and what happens when it is submitted.
 *
 * Everything that decides *what a draft becomes* is in `utils/draft.ts` and
 * `utils/encounter.ts`; this is the state that only exists while the dialog is
 * open.
 */
export function useCombatantBuilder({
  characters,
  encounter,
  setEncounter,
  setBestiary,
}: StoredSession) {
  const [isOpen, setOpen] = useState(false)
  const [selectedPcIds, setSelectedPcIds] = useState<string[]>([])
  const [draft, setDraft] = useState<NpcDraft>(emptyDraft)

  const open = useCallback(() => {
    // Pre-tick everyone who is not already in the fight.
    setSelectedPcIds(
      characters
        .filter((pc) => !encounter.members.some((m) => m.refId === pc.id))
        .map((pc) => pc.id)
    )
    setOpen(true)
  }, [characters, encounter.members])

  const close = useCallback(() => setOpen(false), [])

  const togglePc = useCallback((id: string) => {
    setSelectedPcIds((prev) =>
      prev.includes(id) ? prev.filter((pcId) => pcId !== id) : [...prev, id]
    )
  }, [])

  const addSelectedPcs = useCallback(() => {
    if (!selectedPcIds.length) return
    const chosen = characters.filter((pc) => selectedPcIds.includes(pc.id))
    setEncounter((prev) => addPlayerCharacters(prev, chosen))
    setSelectedPcIds([])
  }, [characters, selectedPcIds, setEncounter])

  const changeDraft = useCallback(<K extends keyof NpcDraft>(field: K, value: NpcDraft[K]) => {
    setDraft((prev) => ({ ...prev, [field]: value }))
  }, [])

  const loadPreset = useCallback((preset: MonsterPreset) => setDraft(draftFromPreset(preset)), [])

  const loadBestiaryEntry = useCallback(
    (entry: BestiaryEntry) => setDraft(draftFromBestiaryEntry(entry)),
    []
  )

  const deleteBestiaryEntry = useCallback(
    (id: string) => setBestiary((prev) => prev.filter((e) => e.id !== id)),
    [setBestiary]
  )

  const submit = useCallback(
    (ev: FormEvent<HTMLFormElement>) => {
      ev.preventDefault()
      setEncounter((prev) => addNpcs(prev, draft))

      // Remember the statblock under its monster type, so the next one of these
      // does not have to be typed again.
      const monsterType = draft.monsterType.trim()
      if (monsterType) {
        setBestiary((prev) => {
          const existing = prev.find((e) => e.monsterType === monsterType)
          const entry = bestiaryEntryFromDraft(draft, {
            id: existing ? existing.id : uid('bst'),
            now: Date.now(),
          })
          return existing ? prev.map((e) => (e.id === existing.id ? entry : e)) : [...prev, entry]
        })
      }

      setDraft(emptyDraft())
    },
    [draft, setBestiary, setEncounter]
  )

  return {
    isOpen,
    open,
    close,
    selectedPcIds,
    togglePc,
    addSelectedPcs,
    draft,
    changeDraft,
    loadPreset,
    loadBestiaryEntry,
    deleteBestiaryEntry,
    submit,
  }
}
