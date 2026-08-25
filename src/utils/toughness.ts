import type { Toughness } from '../types'
import { clamp } from './core'

export const MAX_TOUGHNESS = 999

/**
 * The one place toughness is clamped. It used to be clamped in three view-layer
 * components and in none of the paths that load data, which is why an imported
 * file could sit outside the range the UI claimed to enforce.
 */
export function makeToughness(current: number, max?: number): Toughness {
  const rawMax = Math.floor(Number.isFinite(max as number) ? (max as number) : current)
  const safeMax = clamp(Number.isFinite(rawMax) ? rawMax : 0, 1, MAX_TOUGHNESS)
  const rawCurrent = Math.floor(current)
  return {
    current: clamp(Number.isFinite(rawCurrent) ? rawCurrent : safeMax, 0, safeMax),
    max: safeMax,
  }
}

export function setCurrent(t: Toughness, current: number): Toughness {
  return makeToughness(current, t.max)
}

/** Raising the maximum leaves current alone; lowering it drags current down. */
export function setMax(t: Toughness, max: number): Toughness {
  const next = makeToughness(t.current, max)
  return next
}

/**
 * Apply a change and report what actually landed.
 *
 * `dealt` is the damage the target could absorb — hitting a combatant on 2 for
 * 20 deals 2, not 20. That distinction is the whole point: the pain threshold
 * used to be tested against the number typed into the box, so a killing blow
 * announced itself as a pain-threshold hit on a combatant that was already down.
 */
export function applyDelta(
  t: Toughness,
  delta: number
): { next: Toughness; dealt: number; healed: number } {
  const next = setCurrent(t, t.current + delta)
  const change = next.current - t.current
  return { next, dealt: change < 0 ? -change : 0, healed: change > 0 ? change : 0 }
}

export const isDown = (t: Toughness) => t.current <= 0


/**
 * `null` means this creature never goes prone. `0` means every hit that lands
 * prones it. Anything else is the damage needed. That third case used to be the
 * only one written down, and the first two lived in a comment.
 */
export function exceedsPainThreshold(threshold: number | null, damageDealt: number): boolean {
  if (threshold === null) return false
  if (damageDealt <= 0) return false
  return damageDealt >= threshold
}
