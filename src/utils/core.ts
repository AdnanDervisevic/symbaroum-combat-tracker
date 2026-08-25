/**
 * The two helpers everything else builds on.
 *
 * These used to live in `src/utils.ts`, a file sitting beside the `src/utils/`
 * directory — so `import { clamp } from '../utils'` written inside `utils/`
 * resolved to the file and `'./utils'` written outside it resolved to the
 * directory. Both worked, neither was obviously which.
 */

/** A short unique-enough id. Collision odds are irrelevant at table scale. */
export function uid(prefix: string): string {
  return prefix + '_' + Math.random().toString(36).slice(2, 10)
}

export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value))
}
