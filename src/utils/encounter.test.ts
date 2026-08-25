import { beforeEach, describe, expect, it } from 'vitest'
import type { Character, EncounterState, NpcDraft } from '../types'
import * as E from './encounter'
import { makeToughness } from './toughness'

/**
 * One named test per fixed bug, with the old wrong behaviour in a comment above
 * the assertion. These are the reason `utils/encounter.ts` exists as a module of
 * pure functions: every one of them used to require a browser and a mouse.
 */

let counter = 0
const makeId = (prefix: string) => `${prefix}_${++counter}`
beforeEach(() => {
  counter = 0
})

const draft = (over: Partial<NpcDraft> = {}): NpcDraft => ({
  monsterType: 'Goblin',
  name: '',
  count: 1,
  initiative: 11,
  toughness: 8,
  defense: 6,
  armor: '0',
  painThreshold: 4,
  note: '',
  attributes: null,
  ...over,
})

const pc = (id: string, over: Partial<Character> = {}): Character => ({
  id,
  name: id,
  role: '',
  initiative: 5,
  toughness: 10,
  defense: 8,
  armor: '',
  painThreshold: null,
  attributes: null,
  note: '',
  ...over,
})

const names = (state: EncounterState) => state.members.map((m) => m.name)
const activeName = (state: EncounterState) => E.activeMember(state)?.name

describe('NPC naming', () => {
  it('does not reuse a name after one is removed', () => {
    // React counted the monsters currently alive, so removing Goblin 2 and
    // adding another produced a second Goblin 3.
    let state = E.addNpcs(E.emptyEncounter(), draft({ count: 3 }), makeId)
    expect(names(state)).toEqual(['Goblin 1', 'Goblin 2', 'Goblin 3'])

    state = E.removeMember(state, state.members[1].id)
    state = E.addNpcs(state, draft(), makeId)
    expect(names(state)).toEqual(['Goblin 1', 'Goblin 3', 'Goblin 4'])
  })

  it('keeps a separate count per monster type', () => {
    let state = E.addNpcs(E.emptyEncounter(), draft({ count: 2 }), makeId)
    state = E.addNpcs(state, draft({ monsterType: 'Wolf' }), makeId)
    expect(names(state)).toEqual(['Goblin 1', 'Goblin 2', 'Wolf 1'])
  })

  it('numbers anonymous NPCs under their own counter', () => {
    const state = E.addNpcs(E.emptyEncounter(), draft({ monsterType: '', count: 2 }), makeId)
    expect(names(state)).toEqual(['NPC 1', 'NPC 2'])
  })

  it('leaves the counter alone when the GM names them', () => {
    let state = E.addNpcs(E.emptyEncounter(), draft({ name: 'Grishnak' }), makeId)
    expect(names(state)).toEqual(['Grishnak'])
    expect(state.nameCounter).toEqual({})

    state = E.addNpcs(state, draft(), makeId)
    expect(names(state)).toEqual(['Grishnak', 'Goblin 1'])
  })

  it('clamps a silly quantity instead of trusting it', () => {
    const state = E.addNpcs(E.emptyEncounter(), draft({ count: 500 }), makeId)
    expect(state.members).toHaveLength(E.NPC_COUNT_MAX)
  })
})

describe('adding NPCs', () => {
  it('keeps the attributes a preset came with', () => {
    // The object literal in `addNpc` simply did not list them, and the field
    // being optional meant nothing complained.
    const attributes = { acc: 13, qui: 11 }
    const state = E.addNpcs(E.emptyEncounter(), draft({ attributes }), makeId)
    expect(state.members[0].attributes).toEqual(attributes)
  })

  it('starts them at full health', () => {
    const state = E.addNpcs(E.emptyEncounter(), draft({ toughness: 12 }), makeId)
    expect(state.members[0].toughness).toEqual({ current: 12, max: 12 })
  })

  it('defaults empty armour rather than storing a blank', () => {
    const state = E.addNpcs(E.emptyEncounter(), draft({ armor: '   ' }), makeId)
    expect(state.members[0].armor).toBe('Light (d4)')
  })
})

describe('the turn cursor', () => {
  const withThree = () => E.addNpcs(E.emptyEncounter(), draft({ count: 3 }), makeId)

  it('survives removing somebody else', () => {
    let state = E.nextTurn(withThree())
    expect(activeName(state)).toBe('Goblin 2')
    state = E.removeMember(state, state.members[0].id)
    expect(activeName(state)).toBe('Goblin 2')
  })

  it('is clamped when the active member is the one removed from the end', () => {
    let state = E.nextTurn(E.nextTurn(withThree()))
    expect(activeName(state)).toBe('Goblin 3')
    state = E.removeMember(state, state.members[2].id)
    expect(state.turnIndex).toBe(1)
    expect(activeName(state)).toBe('Goblin 2')
  })

  it('is repaired when a character is deleted from the roster', () => {
    // React filtered `members` and left `turnIndex` where it was, so the
    // highlight moved to a different combatant or off the end of the array.
    let state = E.addPlayerCharacters(E.emptyEncounter(), [pc('pc_1'), pc('pc_2')], makeId)
    state = E.addNpcs(state, draft(), makeId)
    state = E.nextTurn(E.nextTurn(state))
    expect(activeName(state)).toBe('Goblin 1')

    state = E.removeMembersOfCharacter(state, 'pc_1')
    expect(state.members).toHaveLength(2)
    expect(activeName(state)).toBe('Goblin 1')
  })

  it('goes back to the start when the last member leaves', () => {
    let state = E.addNpcs(E.emptyEncounter(), draft(), makeId)
    state = E.removeMember(state, state.members[0].id)
    expect(state).toMatchObject({ turnIndex: 0, round: 1 })
  })

  it('follows a member that is moved', () => {
    let state = E.nextTurn(withThree())
    expect(activeName(state)).toBe('Goblin 2')
    state = E.moveMember(state, state.members[1].id, 'up')
    expect(names(state)).toEqual(['Goblin 2', 'Goblin 1', 'Goblin 3'])
    expect(activeName(state)).toBe('Goblin 2')
  })

  it('refuses to move off either end', () => {
    const state = withThree()
    expect(E.moveMember(state, state.members[0].id, 'up')).toBe(state)
    expect(E.moveMember(state, state.members[2].id, 'down')).toBe(state)
  })
})

describe('sorting', () => {
  it('leaves the round alone', () => {
    // React wrote `round: prev.members.length ? 1 : prev.round`, so sorting in
    // round 5 put you back in round 1 with no warning.
    let state = E.addNpcs(E.emptyEncounter(), draft({ count: 2, initiative: 3 }), makeId)
    state = E.addNpcs(state, draft({ monsterType: 'Wolf', initiative: 15 }), makeId)
    state = { ...state, round: 5 }

    const sorted = E.sortByInitiative(state)
    expect(sorted.round).toBe(5)
    expect(names(sorted)[0]).toBe('Wolf 1')
    expect(sorted.turnIndex).toBe(0)
  })
})

describe('stepping the turn', () => {
  const two = () => E.addNpcs(E.emptyEncounter(), draft({ count: 2 }), makeId)

  it('advances the round on wrapping', () => {
    let state = two()
    expect(state.round).toBe(1)
    state = E.nextTurn(state)
    expect(state.round).toBe(1)
    state = E.nextTurn(state)
    expect(state).toMatchObject({ turnIndex: 0, round: 2 })
  })

  it('undoes itself, except against the floor', () => {
    const state = two()
    expect(E.prevTurn(E.nextTurn(state))).toEqual(state)
    // Round 1 is the floor, so stepping back from the very first turn moves the
    // cursor but cannot move the round.
    expect(E.prevTurn(state)).toMatchObject({ turnIndex: 1, round: 1 })
  })

  it('does nothing to an empty encounter', () => {
    const empty = E.emptyEncounter()
    expect(E.nextTurn(empty)).toBe(empty)
    expect(E.prevTurn(empty)).toBe(empty)
  })
})

describe('hurting and healing', () => {
  const wounded = () => {
    const state = E.addNpcs(E.emptyEncounter(), draft({ toughness: 8, painThreshold: 4 }), makeId)
    return {
      ...state,
      members: [{ ...state.members[0], toughness: makeToughness(2, 8) }],
    }
  }

  it('deals only what the target can take', () => {
    const state = E.adjust(wounded(), 'cmb_1', 'hurt', 20)
    expect(state.members[0].toughness).toEqual({ current: 0, max: 8 })
  })

  it('does not call a killing blow a pain threshold hit', () => {
    // React compared the number typed into the box, so a combatant on 2 hit for
    // 20 died *and* announced that it had exceeded its pain threshold.
    const member = wounded().members[0]
    expect(E.adjustmentEvents(member, 'hurt', 20)).toEqual([{ kind: 'down', name: 'Goblin 1' }])
    expect(E.adjust(wounded(), 'cmb_1', 'hurt', 20).members[0].prone).toBe(false)
  })

  it('prones a survivor whose threshold is exceeded', () => {
    const state = E.addNpcs(E.emptyEncounter(), draft({ toughness: 20, painThreshold: 4 }), makeId)
    const member = state.members[0]
    expect(E.adjustmentEvents(member, 'hurt', 5)).toEqual([
      { kind: 'pain', name: 'Goblin 1', amount: 5 },
    ])
    expect(E.adjust(state, member.id, 'hurt', 5).members[0].prone).toBe(true)
  })

  it('reports nothing for a blow that does not reach the threshold', () => {
    const state = E.addNpcs(E.emptyEncounter(), draft({ toughness: 20, painThreshold: 9 }), makeId)
    expect(E.adjustmentEvents(state.members[0], 'hurt', 3)).toEqual([])
  })

  it('never prones a creature with no threshold', () => {
    const state = E.addNpcs(
      E.emptyEncounter(),
      draft({ toughness: 20, painThreshold: null }),
      makeId
    )
    expect(E.adjust(state, state.members[0].id, 'hurt', 19).members[0].prone).toBe(false)
  })

  it('stands a healed combatant up', () => {
    let state = E.addNpcs(E.emptyEncounter(), draft({ toughness: 20, painThreshold: 1 }), makeId)
    const id = state.members[0].id
    state = E.adjust(state, id, 'hurt', 5)
    expect(state.members[0].prone).toBe(true)
    state = E.adjust(state, id, 'heal', 1)
    expect(state.members[0].prone).toBe(false)
  })

  it('ignores an adjustment of zero', () => {
    const state = wounded()
    expect(E.adjust(state, 'cmb_1', 'hurt', 0)).toBe(state)
    expect(E.adjustmentEvents(state.members[0], 'hurt', 0)).toEqual([])
  })

  it('only reports going down once', () => {
    const state = E.adjust(wounded(), 'cmb_1', 'hurt', 20)
    expect(E.adjustmentEvents(state.members[0], 'hurt', 5)).toEqual([])
  })
})

describe('roster sync', () => {
  it('pushes sheet edits into the combatant but leaves the wound alone', () => {
    let state = E.addPlayerCharacters(E.emptyEncounter(), [pc('pc_1', { name: 'Aria' })], makeId)
    state = E.adjust(state, state.members[0].id, 'hurt', 4)
    expect(state.members[0].toughness).toEqual({ current: 6, max: 10 })

    const renamed = [pc('pc_1', { name: 'Aria the Bold', toughness: 14, defense: 12 })]
    const synced = E.syncFromRoster(state, renamed)
    expect(synced.members[0]).toMatchObject({ name: 'Aria the Bold', defense: 12 })
    expect(synced.members[0].toughness).toEqual({ current: 6, max: 14 })
  })

  it('returns the same object when nothing changed, so no undo entry is recorded', () => {
    const roster = [pc('pc_1')]
    const state = E.addPlayerCharacters(E.emptyEncounter(), roster, makeId)
    expect(E.syncFromRoster(state, roster)).toBe(state)
  })

  it('leaves a combatant whose character was deleted alone', () => {
    const state = E.addPlayerCharacters(E.emptyEncounter(), [pc('pc_1')], makeId)
    expect(E.syncFromRoster(state, [])).toBe(state)
  })
})

describe('adding player characters', () => {
  it('refuses to add the same character twice', () => {
    const roster = [pc('pc_1'), pc('pc_2')]
    let state = E.addPlayerCharacters(E.emptyEncounter(), roster, makeId)
    state = E.addPlayerCharacters(state, roster, makeId)
    expect(state.members).toHaveLength(2)
  })
})

describe('the archive label', () => {
  it('counts each side and gets the plurals right', () => {
    let state = E.addPlayerCharacters(E.emptyEncounter(), [pc('pc_1')], makeId)
    state = E.addNpcs(state, draft({ count: 2 }), makeId)
    expect(E.archiveLabel({ ...state, round: 4 })).toBe('Round 4 — 1 PC, 2 NPCs')
  })

  it('describes an empty encounter without pretending it had anybody', () => {
    expect(E.archiveLabel(E.emptyEncounter())).toBe('Round 1 — 0 PCs, 0 NPCs')
  })
})

describe('side totals', () => {
  it('counts only the standing, and says how many are not', () => {
    let state = E.addPlayerCharacters(E.emptyEncounter(), [pc('pc_1'), pc('pc_2')], makeId)
    state = E.addNpcs(state, draft({ count: 2, toughness: 8 }), makeId)
    state = E.adjust(state, state.members[0].id, 'hurt', 99)

    expect(E.sideTotals(state.members)).toEqual({
      pcs: { count: 2, standing: 1, toughness: 10 },
      npcs: { count: 2, standing: 2, toughness: 16 },
    })
  })

  it('has nothing to say about an empty encounter', () => {
    expect(E.sideTotals([])).toBeNull()
  })
})

describe('field edits', () => {
  it('enforce their bounds in the transition, not in the widget', () => {
    const state = E.addNpcs(E.emptyEncounter(), draft(), makeId)
    const id = state.members[0].id
    expect(E.patchMember(state, id, { field: 'defense', value: 99 }).members[0].defense).toBe(20)
    expect(E.patchMember(state, id, { field: 'initiative', value: -4 }).members[0].initiative).toBe(0)
    expect(
      E.patchMember(state, id, { field: 'toughnessCurrent', value: 999 }).members[0].toughness
    ).toEqual({ current: 8, max: 8 })
  })

  it('coalesce per field and per combatant, but never a toggle', () => {
    expect(E.coalesceKeyFor('cmb_1', { field: 'note', value: 'x' })).toBe('note:cmb_1')
    expect(E.coalesceKeyFor('cmb_2', { field: 'note', value: 'x' })).toBe('note:cmb_2')
    expect(E.coalesceKeyFor('cmb_1', { field: 'prone', value: true })).toBeNull()
    expect(E.coalesceKeyFor('cmb_1', { field: 'flanked', value: true })).toBeNull()
  })
})
