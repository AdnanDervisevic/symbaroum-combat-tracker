/**
 * Undo/redo as data.
 *
 * Kept apart from the hook that owns it so the interesting part — what a push
 * does to the stack, when a change coalesces, what the capacity trim applies to
 * — is a set of pure functions that a test can call directly. The hook below it
 * is wiring.
 */

export const MAX_HISTORY = 50

export type HistoryState<T> = {
  past: T[]
  present: T
  future: T[]
  /**
   * The coalescing key of the entry on top. A change carrying the same key
   * replaces `present` instead of pushing, so typing a sentence into a note is
   * one undo rather than fifty.
   */
  lastKey: string | null
}

export const initialHistory = <T,>(present: T): HistoryState<T> => ({
  past: [],
  present,
  future: [],
  lastKey: null,
})

/**
 * The only constructor of a history record.
 *
 * Everything routes through here so the capacity trim cannot be forgotten by one
 * writer out of three — which is exactly what happened to `redo`, whose `past`
 * grew without bound under undo/redo ping-pong.
 */
function build<T>(past: T[], present: T, future: T[], lastKey: string | null): HistoryState<T> {
  return { past: past.length > MAX_HISTORY ? past.slice(-MAX_HISTORY) : past, present, future, lastKey }
}

/**
 * Structural, not reference, equality.
 *
 * The original check was `next === state.present`, and every caller builds a
 * fresh object literal, so it never fired once. One encounter is small enough
 * that stringifying it per edit is not worth optimising away.
 */
function sameState<T>(a: T, b: T): boolean {
  if (a === b) return true
  try {
    return JSON.stringify(a) === JSON.stringify(b)
  } catch {
    return false
  }
}

/** Record a new present. A no-op change costs nothing. */
export function record<T>(state: HistoryState<T>, next: T, coalesce: string | null): HistoryState<T> {
  if (sameState(next, state.present)) return state
  if (coalesce !== null && coalesce === state.lastKey) {
    return build(state.past, next, [], coalesce)
  }
  return build([...state.past, state.present], next, [], coalesce)
}

export function undo<T>(state: HistoryState<T>): HistoryState<T> {
  if (state.past.length === 0) return state
  const past = [...state.past]
  const present = past.pop() as T
  // A fresh key, so the next edit starts its own entry rather than merging into
  // whatever was on top before the undo.
  return build(past, present, [state.present, ...state.future], null)
}

export function redo<T>(state: HistoryState<T>): HistoryState<T> {
  if (state.future.length === 0) return state
  const future = [...state.future]
  const present = future.shift() as T
  return build([...state.past, state.present], present, future, null)
}

export const canUndo = <T,>(state: HistoryState<T>) => state.past.length > 0
export const canRedo = <T,>(state: HistoryState<T>) => state.future.length > 0
