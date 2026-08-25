// @vitest-environment jsdom
import { act, renderHook } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { useRowState } from './useRowState'

/**
 * The rule worth pinning is the one that used to apply to only one of the two
 * maps: both are forgotten when a combatant leaves the fight. `damageInputs` was
 * pruned nowhere and grew an entry for every combatant that had ever existed.
 */
describe('useRowState', () => {
  it('forgets both maps for a removed combatant', () => {
    const { result } = renderHook(() => useRowState())

    act(() => {
      result.current.toggleEditing('cmb_1')
      result.current.setDamageInput('cmb_1', 7)
      result.current.toggleEditing('cmb_2')
      result.current.setDamageInput('cmb_2', 3)
    })
    expect(result.current.editingIds).toEqual({ cmb_1: true, cmb_2: true })
    expect(result.current.damageInputs).toEqual({ cmb_1: 7, cmb_2: 3 })

    act(() => result.current.forget('cmb_1'))
    expect(result.current.editingIds).toEqual({ cmb_2: true })
    expect(result.current.damageInputs).toEqual({ cmb_2: 3 })
  })

  it('leaves the maps alone when forgetting somebody who was never in them', () => {
    const { result } = renderHook(() => useRowState())
    act(() => result.current.setDamageInput('cmb_1', 4))
    const before = result.current.damageInputs

    act(() => result.current.forget('nobody'))
    expect(result.current.damageInputs).toBe(before)
  })

  it('toggles edit mode off again', () => {
    const { result } = renderHook(() => useRowState())
    act(() => result.current.toggleEditing('cmb_1'))
    expect(result.current.editingIds.cmb_1).toBe(true)
    act(() => result.current.toggleEditing('cmb_1'))
    expect(result.current.editingIds.cmb_1).toBe(false)
  })

  it('empties both when the encounter is cleared', () => {
    const { result } = renderHook(() => useRowState())
    act(() => {
      result.current.toggleEditing('cmb_1')
      result.current.setDamageInput('cmb_1', 9)
    })
    act(() => result.current.clear())
    expect(result.current.editingIds).toEqual({})
    expect(result.current.damageInputs).toEqual({})
  })
})
