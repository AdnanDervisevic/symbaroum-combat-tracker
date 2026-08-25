import { describe, expect, it } from 'vitest'
import { readBestiary, readCharacters, readEncounter } from './migrate'
import { rebuildNameCounter } from './encounter'
import type { Combatant } from '../types'

/**
 * Reading version 1 — the shape the app shipped with — and repairing what is out
 * of range. Two rules, both learned the hard way: repair rather than reject, and
 * say what was repaired, because a silent repair and a silent acceptance look
 * identical from the outside.
 */

const v1Character = {
  id: 'pc_default_a',
  name: 'Aria',
  role: 'Bard',
  initiative: 3,
  toughness: 12,
  defense: 8,
  armor: 'Light (d4)',
  painThreshold: null,
  note: '',
}

describe('characters', () => {
  it('reads a bare v1 number as the maximum, not as a wound', () => {
    // Getting this backwards silently rewrote people's sheets: a character with
    // 14 toughness came back with 10.
    expect(readCharacters([{ ...v1Character, toughness: 14 }])[0].toughness).toBe(14)
  })

  it('recovers isBuiltin from the id prefix exactly once', () => {
    const [builtin, custom] = readCharacters([
      v1Character,
      { ...v1Character, id: 'pc_custom_1', name: 'Brakk' },
    ])
    expect(builtin.isBuiltin).toBe(true)
    expect(custom.isBuiltin).toBe(false)
  })

  it('prefers a stored flag over the prefix', () => {
    expect(readCharacters([{ ...v1Character, isBuiltin: false }])[0].isBuiltin).toBe(false)
  })

  it('survives junk without throwing', () => {
    expect(() => readCharacters([null, 7, 'nope', {}])).not.toThrow()
    expect(readCharacters('not an array')).toEqual([])
  })
})

describe('combatants', () => {
  const encounterWith = (members: unknown[], rest: Record<string, unknown> = {}) => ({
    members,
    turnIndex: 0,
    round: 1,
    ...rest,
  })

  it('recovers a maximum the v1 format never stored', () => {
    const { encounter } = readEncounter(
      encounterWith([
        { id: 'c1', source: 'pc', refId: 'pc_default_a', name: 'Aria', toughness: 5 },
      ]),
      { characters: readCharacters([v1Character]) }
    )
    expect(encounter.members[0].toughness).toEqual({ current: 5, max: 12 })
  })

  it('recovers an NPC maximum from the bestiary template', () => {
    const bestiary = readBestiary([{ id: 'b1', monsterType: 'Goblin', toughness: 8 }])
    const { encounter } = readEncounter(
      encounterWith([{ id: 'c1', source: 'npc', monsterType: 'Goblin', name: 'Goblin 1', toughness: 3 }]),
      { bestiary }
    )
    expect(encounter.members[0].toughness).toEqual({ current: 3, max: 8 })
  })

  it('falls back to the current value when there is nothing to recover from', () => {
    const { encounter } = readEncounter(
      encounterWith([{ id: 'c1', source: 'npc', name: 'Stranger', toughness: 4 }])
    )
    expect(encounter.members[0].toughness).toEqual({ current: 4, max: 4 })
  })

  it('never lowers a maximum below the wound it is carrying', () => {
    const characters = readCharacters([{ ...v1Character, toughness: 6 }])
    const { encounter } = readEncounter(
      encounterWith([
        { id: 'c1', source: 'pc', refId: 'pc_default_a', name: 'Aria', toughness: 11 },
      ]),
      { characters }
    )
    expect(encounter.members[0].toughness).toEqual({ current: 11, max: 11 })
  })

  it('demotes a player character with no roster entry, and says so', () => {
    const { encounter, corrections } = readEncounter(
      encounterWith([{ id: 'c1', source: 'pc', name: 'Ghost', toughness: 5 }])
    )
    expect(encounter.members[0].source).toBe('npc')
    expect(corrections.some((c) => /no roster entry/.test(c))).toBe(true)
  })

  it('renumbers a duplicate id rather than dropping the combatant', () => {
    const member = { id: 'same', source: 'npc', name: 'Goblin 1', toughness: 5 }
    const { encounter, corrections } = readEncounter(encounterWith([member, { ...member }]))
    expect(encounter.members).toHaveLength(2)
    expect(encounter.members[0].id).not.toBe(encounter.members[1].id)
    expect(corrections.some((c) => /shared the id/.test(c))).toBe(true)
  })
})

describe('the turn cursor and the round', () => {
  it('clamps a marker pointing past the end', () => {
    // `{members: [], turnIndex: 5, round: 0}` used to import cleanly into a
    // state the UI cannot otherwise produce.
    const { encounter, corrections } = readEncounter({
      members: [{ id: 'c1', source: 'npc', name: 'A', toughness: 5 }],
      turnIndex: 9,
      round: 1,
    })
    expect(encounter.turnIndex).toBe(0)
    expect(corrections.some((c) => /turn marker/.test(c))).toBe(true)
  })

  it('puts the marker at zero when there is nobody to point at', () => {
    expect(readEncounter({ members: [], turnIndex: 5, round: 1 }).encounter.turnIndex).toBe(0)
  })

  it('floors the round at one', () => {
    const { encounter, corrections } = readEncounter({ members: [], turnIndex: 0, round: 0 })
    expect(encounter.round).toBe(1)
    expect(corrections.some((c) => /not a round/.test(c))).toBe(true)
  })

  it('leaves a legal encounter completely alone', () => {
    const clean = readEncounter({
      members: [{ id: 'c1', source: 'npc', name: 'A', toughness: { current: 3, max: 5 } }],
      turnIndex: 0,
      round: 4,
      nameCounter: { Goblin: 2 },
    })
    expect(clean.corrections).toEqual([])
    expect(clean.encounter.round).toBe(4)
  })
})

describe('the name counter', () => {
  it('is rebuilt from the largest suffix in use', () => {
    // v1 has no counter, and a fight holding Goblin 1 and Goblin 3 must not hand
    // out Goblin 3 again.
    const { encounter, corrections } = readEncounter({
      members: [
        { id: 'a', source: 'npc', monsterType: 'Goblin', name: 'Goblin 1', toughness: 5 },
        { id: 'b', source: 'npc', monsterType: 'Goblin', name: 'Goblin 3', toughness: 5 },
      ],
      turnIndex: 0,
      round: 1,
    })
    expect(encounter.nameCounter).toEqual({ Goblin: 3 })
    expect(corrections.some((c) => /name counter/.test(c))).toBe(true)
  })

  it('tells an empty counter apart from a missing one', () => {
    // An encounter whose NPCs were all named by hand legitimately has `{}`, and
    // rebuilding that reported a correction which had not been made.
    const { encounter, corrections } = readEncounter({
      members: [{ id: 'a', source: 'npc', monsterType: 'Goblin', name: 'Grishnak', toughness: 5 }],
      turnIndex: 0,
      round: 1,
      nameCounter: {},
    })
    expect(encounter.nameCounter).toEqual({})
    expect(corrections).toEqual([])
  })

  it('ignores names that are not of the numbered form', () => {
    const members = [
      { name: 'Goblin', monsterType: 'Goblin' },
      { name: 'Goblin the Third', monsterType: 'Goblin' },
    ] as Combatant[]
    expect(rebuildNameCounter(members)).toEqual({})
  })

  it('is not fooled by a monster type containing regex characters', () => {
    const members = [{ name: 'Wolf (dire) 4', monsterType: 'Wolf (dire)' }] as Combatant[]
    expect(rebuildNameCounter(members)).toEqual({ 'Wolf (dire)': 4 })
  })
})
