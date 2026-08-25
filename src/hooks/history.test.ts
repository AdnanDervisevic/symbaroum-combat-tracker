import { describe, expect, it } from 'vitest'
import { MAX_HISTORY, canRedo, canUndo, initialHistory, record, redo, undo } from './history'

const start = (present = { note: '' }) => initialHistory(present)

describe('record', () => {
  it('pushes the old present onto the past', () => {
    const state = record(start(), { note: 'a' }, null)
    expect(state.present).toEqual({ note: 'a' })
    expect(state.past).toEqual([{ note: '' }])
  })

  it('costs nothing when nothing changed', () => {
    // The original check was reference equality against a fresh object literal,
    // so it never once fired and every no-op edit burned a slot.
    const state = start()
    expect(record(state, { note: '' }, null)).toBe(state)
  })

  it('clears the redo stack', () => {
    const undone = undo(record(start(), { note: 'a' }, null))
    expect(canRedo(undone)).toBe(true)
    expect(canRedo(record(undone, { note: 'b' }, null))).toBe(false)
  })
})

describe('coalescing', () => {
  it('collapses a run of edits to the same field into one entry', () => {
    // Typing a sentence into a note used to cost one entry per keystroke, so a
    // single sentence evaporated all fifty.
    let state = start()
    const text = 'bleeding badly'
    for (let i = 1; i <= text.length; i++) {
      state = record(state, { note: text.slice(0, i) }, 'note:cmb_1')
    }
    expect(state.present).toEqual({ note: text })
    expect(state.past).toHaveLength(1)
    expect(undo(state).present).toEqual({ note: '' })
  })

  it('starts a new entry when the field changes', () => {
    let state = record(start(), { note: 'a' }, 'note:cmb_1')
    state = record(state, { note: 'ab' }, 'note:cmb_1')
    state = record(state, { note: 'abc' }, 'note:cmb_2')
    expect(state.past).toHaveLength(2)
  })

  it('does not merge across an undo', () => {
    let state = record(start(), { note: 'a' }, 'note:cmb_1')
    state = undo(state)
    state = record(state, { note: 'z' }, 'note:cmb_1')
    expect(state.past).toHaveLength(1)
  })

  it('gives an unkeyed change its own entry', () => {
    let state = record(start(), { note: 'a' }, null)
    state = record(state, { note: 'b' }, null)
    expect(state.past).toHaveLength(2)
  })
})

describe('undo and redo', () => {
  it('round-trip to where they started', () => {
    const state = record(start(), { note: 'a' }, null)
    expect(redo(undo(state))).toEqual(state)
  })

  it('do nothing at the ends', () => {
    const empty = start()
    expect(undo(empty)).toBe(empty)
    expect(redo(empty)).toBe(empty)
    expect(canUndo(empty)).toBe(false)
  })

  it('respect capacity under ping-pong', () => {
    // `redo` used to rebuild `past` without the trim that `record` applies, so
    // alternating undo and redo grew it without bound.
    let state = start()
    for (let i = 0; i < MAX_HISTORY + 20; i++) {
      state = record(state, { note: `edit ${i}` }, null)
    }
    expect(state.past).toHaveLength(MAX_HISTORY)

    for (let i = 0; i < 200; i++) {
      state = i % 2 === 0 ? undo(state) : redo(state)
    }
    expect(state.past.length).toBeLessThanOrEqual(MAX_HISTORY)
  })

  it('keep the oldest entries falling off the front', () => {
    let state = start({ note: 'oldest' })
    for (let i = 0; i < MAX_HISTORY + 5; i++) {
      state = record(state, { note: `edit ${i}` }, null)
    }
    expect(state.past[0]).not.toEqual({ note: 'oldest' })
    expect(state.past).toHaveLength(MAX_HISTORY)
  })
})
