import { useCallback, useState } from 'react'

/**
 * The per-combatant state that belongs to a row rather than to the fight: is
 * this card in edit mode, and what is in its damage box.
 *
 * They are here together because they share one rule that used to be applied to
 * only one of them: **both must be forgotten when the combatant is removed.**
 * `damageInputs` was pruned nowhere, so it grew an entry for every combatant
 * that had ever existed and kept it until the tab was closed.
 */

const without = <T,>(map: Record<string, T>, id: string): Record<string, T> => {
  if (!(id in map)) return map
  const next = { ...map }
  delete next[id]
  return next
}

export type RowState = ReturnType<typeof useRowState>

export function useRowState() {
  const [editingIds, setEditingIds] = useState<Record<string, boolean>>({})
  const [damageInputs, setDamageInputs] = useState<Record<string, number>>({})

  const toggleEditing = useCallback((id: string) => {
    setEditingIds((prev) => ({ ...prev, [id]: !prev[id] }))
  }, [])

  const setDamageInput = useCallback((id: string, value: number) => {
    setDamageInputs((prev) => ({ ...prev, [id]: value }))
  }, [])

  const forget = useCallback((id: string) => {
    setEditingIds((prev) => without(prev, id))
    setDamageInputs((prev) => without(prev, id))
  }, [])

  const clear = useCallback(() => {
    setEditingIds({})
    setDamageInputs({})
  }, [])

  return { editingIds, damageInputs, toggleEditing, setDamageInput, forget, clear }
}
