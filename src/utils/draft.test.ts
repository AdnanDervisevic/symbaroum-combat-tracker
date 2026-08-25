import { describe, expect, it } from 'vitest'
import type { BestiaryEntry } from '../types'
import type { MonsterPreset } from '../data/defaultMonsters'
import {
  bestiaryEntryFromDraft,
  draftFromBestiaryEntry,
  draftFromPreset,
  emptyDraft,
  targetFromModifier,
} from './draft'

const preset = (over: Partial<MonsterPreset> = {}): MonsterPreset => ({
  name: 'Spring Elf',
  category: 'Elf',
  resistance: 'Weak',
  toughness: 10,
  defense: -3,
  armor: '0',
  painThreshold: 3,
  attributes: { acc: 10, cun: 10, dis: 15, per: 9, qui: 13, res: 7, str: 5, vig: 11 },
  ...over,
})

describe('the two spellings of defence', () => {
  it('turns a statblock modifier into the target you roll under', () => {
    // A monster table prints the modifier an attacker applies; a character sheet
    // prints the target. Storing both in one field under one label is what made
    // the Characters tab and the presets disagree about what the number meant.
    expect(targetFromModifier(-3)).toBe(13)
    expect(targetFromModifier(0)).toBe(10)
    expect(targetFromModifier(5)).toBe(5)
  })

  it('keeps the result inside the range a d20 can produce', () => {
    expect(targetFromModifier(-99)).toBe(20)
    expect(targetFromModifier(99)).toBe(1)
  })
})

describe('draftFromPreset', () => {
  it('converts the defence and takes initiative from Quick', () => {
    // Spring Elf: Quick 13, defense -3. Both readings agree on 13, which is the
    // check that the conversion is the right way round.
    const draft = draftFromPreset(preset())
    expect(draft).toMatchObject({ monsterType: 'Spring Elf', defense: 13, initiative: 13 })
  })

  it('falls back to an average defence when the preset has none', () => {
    expect(draftFromPreset(preset({ defense: null })).defense).toBe(10)
  })

  it('fills in the fields a preset leaves empty', () => {
    const draft = draftFromPreset(preset({ toughness: null, armor: null }))
    expect(draft.toughness).toBe(10)
    expect(draft.armor).toBe('')
  })

  it('carries the statblock across', () => {
    expect(draftFromPreset(preset()).attributes).toMatchObject({ acc: 10, qui: 13 })
  })

  it('starts with one of them and no name of its own', () => {
    expect(draftFromPreset(preset())).toMatchObject({ count: 1, name: '' })
  })
})

describe('draftFromBestiaryEntry', () => {
  const entry: BestiaryEntry = {
    id: 'bst_1',
    monsterType: 'Goblin',
    initiative: 11,
    toughness: 8,
    defense: 6,
    armor: '0',
    painThreshold: 4,
    note: 'sneaky',
    attributes: { acc: 12 },
    updatedAt: 0,
  }

  it('carries the defence across unchanged', () => {
    // The GM typed this one through the same form, so it is already a target.
    // Converting it again would move it every time it was reloaded.
    expect(draftFromBestiaryEntry(entry).defense).toBe(6)
  })

  it('restores the statblock, which used to be dropped', () => {
    expect(draftFromBestiaryEntry(entry).attributes).toEqual({ acc: 12 })
  })

  it('does not carry the entry name into the per-combatant name', () => {
    expect(draftFromBestiaryEntry(entry)).toMatchObject({ monsterType: 'Goblin', name: '' })
  })
})

describe('bestiaryEntryFromDraft', () => {
  it('round-trips through the draft it came from', () => {
    const original = { ...emptyDraft(), monsterType: 'Wolf', defense: 7, toughness: 12, note: 'pack' }
    const entry = bestiaryEntryFromDraft(original, { id: 'bst_1', now: 42 })
    expect(entry).toMatchObject({ id: 'bst_1', monsterType: 'Wolf', defense: 7, toughness: 12, updatedAt: 42 })
    expect(draftFromBestiaryEntry(entry)).toMatchObject({ monsterType: 'Wolf', defense: 7, toughness: 12 })
  })

  it('trims what the GM typed', () => {
    const draft = { ...emptyDraft(), monsterType: '  Wolf  ', note: '  pack  ', armor: '   ' }
    const entry = bestiaryEntryFromDraft(draft, { id: 'x', now: 0 })
    expect(entry.monsterType).toBe('Wolf')
    expect(entry.note).toBe('pack')
    expect(entry.armor).toBe('Light (d4)')
  })
})
