import { describe, expect, it } from 'vitest'
import { CURRENT_SAVE_VERSION, validateImportData } from './exportImport'

const v1 = {
  version: 1,
  characters: [
    {
      id: 'pc_default_a',
      name: 'Aria',
      role: '',
      initiative: 3,
      toughness: 12,
      defense: 8,
      armor: '',
      painThreshold: null,
      note: '',
    },
  ],
  encounter: {
    members: [
      { id: 'x', source: 'pc', refId: 'pc_default_a', name: 'Aria', toughness: 5 },
      { id: 'x', source: 'npc', monsterType: 'Goblin', name: 'Goblin 2', toughness: 4 },
    ],
    turnIndex: 9,
    round: 0,
  },
}

const ok = (result: ReturnType<typeof validateImportData>) => {
  if (!result.success) throw new Error('expected success, got: ' + result.error)
  return result
}

describe('version dispatch', () => {
  it('refuses a version it does not know, by name', () => {
    // `version` was checked for being a number and never compared to anything,
    // so a file claiming version 7 was accepted and blind-cast.
    const result = validateImportData({ ...v1, version: 7 })
    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.error).toMatch(/version 7/)
      expect(result.error).toMatch(/reads version 1 or 2/)
    }
  })

  it('reads both formats it claims to', () => {
    expect(validateImportData(v1).success).toBe(true)
    expect(validateImportData({ ...v1, version: 2 }).success).toBe(true)
  })

  it('refuses what is structurally impossible', () => {
    expect(validateImportData('nope').success).toBe(false)
    expect(validateImportData(null).success).toBe(false)
    expect(validateImportData({ characters: [], encounter: { members: [] } }).success).toBe(false)
    expect(validateImportData({ ...v1, characters: 'no' }).success).toBe(false)
    expect(validateImportData({ ...v1, encounter: 'no' }).success).toBe(false)
    expect(validateImportData({ ...v1, encounter: { members: 'no' } }).success).toBe(false)
    expect(validateImportData({ ...v1, version: Number.NaN }).success).toBe(false)
  })
})

describe('repair and report', () => {
  it('fixes everything wrong with one file and lists it', () => {
    const { data, corrections } = ok(validateImportData(v1))
    expect(data.encounter.turnIndex).toBe(1)
    expect(data.encounter.round).toBe(1)
    expect(data.encounter.members[0].id).not.toBe(data.encounter.members[1].id)
    expect(data.encounter.members[0].toughness).toEqual({ current: 5, max: 12 })
    expect(data.encounter.nameCounter).toEqual({ Goblin: 2 })
    expect(corrections).toHaveLength(4)
  })

  it('writes what it read out in the current format', () => {
    expect(ok(validateImportData(v1)).data.version).toBe(CURRENT_SAVE_VERSION)
  })

  it('leaves a file it has already repaired alone', () => {
    // Normalisation has to be a fixed point, or every reload reports corrections
    // it did not make.
    const once = ok(validateImportData(v1)).data
    const twice = ok(validateImportData(once))
    expect(twice.corrections).toEqual([])
    expect(twice.data.encounter).toEqual(once.encounter)
  })

  it('never throws on arbitrary junk', () => {
    const junk = [
      { ...v1, characters: [null, 1, 'x'] },
      { ...v1, encounter: { members: [null, 3], turnIndex: 'x', round: [] } },
      { ...v1, bestiary: 'not an array' },
    ]
    for (const input of junk) expect(() => validateImportData(input)).not.toThrow()
  })
})
