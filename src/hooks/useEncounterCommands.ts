import { useCallback } from 'react'
import { toast } from 'react-toastify'
import type { EncounterHistoryEntry, MemberPatch } from '../types'
import * as Encounter from '../utils/encounter'
import { readEncounter } from '../utils/migrate'
import { uid } from '../utils/core'
import type { StoredSession } from './useStoredSession'
import type { RowState } from './useRowState'

const ARCHIVE_LIMIT = 10
const BOTTOM_RIGHT = { position: 'bottom-right' } as const

/**
 * The verbs, bound to the encounter they act on.
 *
 * Each one is a call to a pure function in `utils/encounter.ts` wrapped in the
 * three things a component actually has to own: confirmation dialogs, toasts,
 * and the row state that has to be forgotten alongside a combatant.
 */
export function useEncounterCommands(
  session: StoredSession,
  rows: RowState,
  flashPain: (name: string, amount: number) => void
) {
  const { encounter, setEncounter, characters, bestiary, setEncounterHistory } = session

  const patch = useCallback(
    (id: string, memberPatch: MemberPatch) => {
      setEncounter((prev) => Encounter.patchMember(prev, id, memberPatch), {
        coalesce: Encounter.coalesceKeyFor(id, memberPatch),
      })
    },
    [setEncounter]
  )

  const remove = useCallback(
    (id: string) => {
      setEncounter((prev) => Encounter.removeMember(prev, id))
      rows.forget(id)
    },
    [rows, setEncounter]
  )

  const move = useCallback(
    (id: string, direction: 'up' | 'down') => {
      setEncounter((prev) => Encounter.moveMember(prev, id, direction))
    },
    [setEncounter]
  )

  const sort = useCallback(() => setEncounter(Encounter.sortByInitiative), [setEncounter])
  const next = useCallback(() => setEncounter(Encounter.nextTurn), [setEncounter])
  const previous = useCallback(() => setEncounter(Encounter.prevTurn), [setEncounter])

  const clear = useCallback(() => {
    if (!window.confirm('Clear encounter?')) return
    if (encounter.members.length > 0) {
      const entry: EncounterHistoryEntry = {
        id: uid('hist'),
        timestamp: Date.now(),
        label: Encounter.archiveLabel(encounter),
        encounter,
      }
      setEncounterHistory((prev) => [entry, ...prev].slice(0, ARCHIVE_LIMIT))
    }
    setEncounter(Encounter.emptyEncounter())
    rows.clear()
  }, [encounter, rows, setEncounter, setEncounterHistory])

  /** Returns whether it actually restored, so the caller knows to close the dialog. */
  const restore = useCallback(
    (entry: EncounterHistoryEntry): boolean => {
      if (!window.confirm('Restore this encounter? Current encounter will be cleared.')) {
        return false
      }
      // Archived encounters predate the name counter and the cursor repair, so
      // they go through the same reader an imported file does.
      setEncounter(readEncounter(entry.encounter, { characters, bestiary }).encounter)
      toast.success('Encounter restored', { ...BOTTOM_RIGHT, autoClose: 2000 })
      return true
    },
    [bestiary, characters, setEncounter]
  )

  const deleteArchived = useCallback(
    (id: string) => setEncounterHistory((prev) => prev.filter((e) => e.id !== id)),
    [setEncounterHistory]
  )

  /**
   * Apply the blow, then announce what it did.
   *
   * The update is a pure function of `prev` rather than of what this render can
   * see, so two quick clicks both land. The events are worked out separately --
   * writing to a ref from inside a state updater, which is what this used to do,
   * fires twice whenever React calls the updater twice.
   */
  const adjust = useCallback(
    (id: string, mode: Encounter.AdjustMode) => {
      const amount = rows.damageInputs[id] ?? 1
      const member = encounter.members.find((m) => m.id === id)
      if (!member) return

      const events = Encounter.adjustmentEvents(member, mode, amount)
      setEncounter((prev) => Encounter.adjust(prev, id, mode, amount))

      for (const event of events) {
        if (event.kind === 'pain') {
          flashPain(event.name, event.amount)
          toast.warning(
            `${event.name} takes ${event.amount} damage and exceeds Pain Threshold`,
            { ...BOTTOM_RIGHT, autoClose: 4000 }
          )
        } else {
          toast.error(`${event.name} is down`, { ...BOTTOM_RIGHT, autoClose: 4000 })
        }
      }
    },
    [encounter.members, flashPain, rows.damageInputs, setEncounter]
  )

  return { patch, remove, move, sort, next, previous, clear, restore, deleteArchived, adjust }
}
