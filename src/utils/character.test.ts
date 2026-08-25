import { describe, expect, it } from 'vitest'
import type { Character, Combatant } from '../types'
import {
  ATTRIBUTE_FIELDS,
  buildNewCharacter,
  characterToCombatant,
  normalizeAttributes,
  syncMemberFromPc,
} from './character'

const pc = (over: Partial<Character> = {}): Character => ({
  id: 'pc_1',
  name: 'Aria',
  role: 'Bard',
  initiative: 5,
  toughness: 10,
  defense: 8,
  armor: 'Light (d4)',
  painThreshold: 4,
  attributes: null,
  note: '',
  ...over,
})

let ids = 0
const makeId = (prefix: string) => `${prefix}_${++ids}`

describe('normalizeAttributes', () => {
  it('collapses the three spellings of "no attributes" into one', () => {
    // `undefined`, `null` and `{}` all meant the same thing and all had to be
    // handled separately at every use site.
    expect(normalizeAttributes(undefined)).toBeNull()
    expect(normalizeAttributes(null)).toBeNull()
    expect(normalizeAttributes({})).toBeNull()
    expect(normalizeAttributes({ acc: null, qui: undefined })).toBeNull()
  })

  it('keeps only the keys that are real scores', () => {
    expect(normalizeAttributes({ acc: 13, qui: null, bogus: 4 })).toEqual({ acc: 13 })
  })

  it('drops values that are not finite numbers', () => {
    expect(normalizeAttributes({ acc: Number.NaN, cun: Infinity, dis: 9 })).toEqual({ dis: 9 })
  })

  it('accepts numeric strings, since that is what an input gives you', () => {
    expect(normalizeAttributes({ acc: '13' })).toEqual({ acc: 13 })
  })

  it('survives being handed something that is not an object at all', () => {
    expect(normalizeAttributes('nope')).toBeNull()
    expect(normalizeAttributes(7)).toBeNull()
  })

  it('covers every attribute the game has', () => {
    expect(ATTRIBUTE_FIELDS.map((f) => f.key)).toEqual([
      'acc', 'cun', 'dis', 'per', 'qui', 'res', 'str', 'vig',
    ])
  })
})

describe('joining a fight', () => {
  it('starts a character at full health with both ends recorded', () => {
    const member = characterToCombatant(pc({ toughness: 14 }), makeId)
    expect(member.toughness).toEqual({ current: 14, max: 14 })
    expect(member).toMatchObject({ source: 'pc', refId: 'pc_1', prone: false, flanked: false })
  })

  it('copies the attributes rather than sharing them', () => {
    const character = pc({ attributes: { acc: 11 } })
    const member = characterToCombatant(character, makeId)
    expect(member.attributes).toEqual({ acc: 11 })
    expect(member.attributes).not.toBe(character.attributes)
  })
})

describe('a new character', () => {
  it('is not one of the shipped four', () => {
    // `isBuiltin` is what hides the Delete button; a character the user just
    // created must be deletable.
    expect(buildNewCharacter().isBuiltin).toBe(false)
  })
})

describe('syncMemberFromPc', () => {
  const member = (over: Partial<Combatant> = {}): Combatant =>
    ({ ...characterToCombatant(pc(), makeId), ...over }) as Combatant

  it('returns the same object when nothing changed', () => {
    // Identity is load-bearing: the caller uses it to decide whether to record
    // an undo entry at all.
    const m = member()
    expect(syncMemberFromPc(m, pc())).toBe(m)
  })

  it('pushes sheet edits through', () => {
    const synced = syncMemberFromPc(member(), pc({ name: 'Aria the Bold', defense: 12, armor: 'Heavy (d12)' }))
    expect(synced).toMatchObject({ name: 'Aria the Bold', defense: 12, armor: 'Heavy (d12)' })
  })

  it('raises the maximum without healing the wound', () => {
    const wounded = member({ toughness: { current: 3, max: 10 } })
    expect(syncMemberFromPc(wounded, pc({ toughness: 16 })).toughness).toEqual({
      current: 3,
      max: 16,
    })
  })

  it('lowering the maximum past the wound drags it down', () => {
    const wounded = member({ toughness: { current: 9, max: 10 } })
    expect(syncMemberFromPc(wounded, pc({ toughness: 5 })).toughness).toEqual({
      current: 5,
      max: 5,
    })
  })

  it('notices an attribute change on its own', () => {
    const before = member()
    const after = syncMemberFromPc(before, pc({ attributes: { acc: 13 } }))
    expect(after).not.toBe(before)
    expect(after.attributes).toEqual({ acc: 13 })
  })

  it('treats a missing pain threshold and a null one as the same', () => {
    const m = member({ painThreshold: null })
    expect(syncMemberFromPc(m, pc({ painThreshold: null }))).toBe(m)
  })
})
