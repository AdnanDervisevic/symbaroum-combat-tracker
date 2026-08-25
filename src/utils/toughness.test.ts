import { describe, expect, it } from 'vitest'
import {
  applyDelta,
  exceedsPainThreshold,
  formatToughness,
  isDown,
  makeToughness,
  setCurrent,
  setMax,
} from './toughness'

describe('makeToughness', () => {
  it('treats a lone number as full health', () => {
    expect(makeToughness(10)).toEqual({ current: 10, max: 10 })
  })

  it('never lets current exceed max', () => {
    expect(makeToughness(99, 10)).toEqual({ current: 10, max: 10 })
  })

  it('floors max at 1, because a combatant with no maximum is not a combatant', () => {
    expect(makeToughness(0, 0).max).toBe(1)
  })

  it('rejects nonsense rather than propagating NaN', () => {
    expect(makeToughness(Number.NaN, 8)).toEqual({ current: 8, max: 8 })
  })
})

describe('setMax', () => {
  it('leaves current alone when raised', () => {
    expect(setMax({ current: 4, max: 10 }, 16)).toEqual({ current: 4, max: 16 })
  })

  it('drags current down when lowered past it', () => {
    expect(setMax({ current: 9, max: 10 }, 5)).toEqual({ current: 5, max: 5 })
  })
})

describe('applyDelta', () => {
  it('reports the damage that landed, not the damage that was aimed', () => {
    // The bug this exists to prevent: a combatant on 2 hit for 20 takes 2.
    const { next, dealt } = applyDelta({ current: 2, max: 8 }, -20)
    expect(next).toEqual({ current: 0, max: 8 })
    expect(dealt).toBe(2)
  })

  it('does not heal past the maximum', () => {
    const { next, healed } = applyDelta({ current: 8, max: 10 }, 20)
    expect(next.current).toBe(10)
    expect(healed).toBe(2)
  })

  it('is a no-op on the dead', () => {
    expect(applyDelta({ current: 0, max: 5 }, -3).dealt).toBe(0)
  })
})

describe('exceedsPainThreshold', () => {
  it('null means this creature never goes prone', () => {
    expect(exceedsPainThreshold(null, 999)).toBe(false)
  })

  it('zero means every hit that lands prones it', () => {
    expect(exceedsPainThreshold(0, 1)).toBe(true)
  })

  it('zero still needs a hit to land', () => {
    expect(exceedsPainThreshold(0, 0)).toBe(false)
  })

  it('n needs n', () => {
    expect(exceedsPainThreshold(5, 4)).toBe(false)
    expect(exceedsPainThreshold(5, 5)).toBe(true)
  })
})

describe('reading it back', () => {
  it('shows current out of maximum', () => {
    expect(formatToughness({ current: 6, max: 10 })).toBe('6 / 10')
  })

  it('knows when someone is out of the fight', () => {
    expect(isDown({ current: 0, max: 10 })).toBe(true)
    expect(isDown(setCurrent({ current: 0, max: 10 }, 1))).toBe(false)
  })
})
