import type {
  Character,
  Combatant,
  EncounterState,
  MemberPatch,
  NpcDraft,
} from '../types'
import { clamp, uid } from './core'
import { characterToCombatant, normalizeAttributes, syncMemberFromPc } from './character'
import {
  applyDelta,
  exceedsPainThreshold,
  isDown,
  makeToughness,
  setCurrent,
  setMax,
} from './toughness'

/**
 * Every transition an encounter can make, as a pure function of the encounter.
 *
 * These used to live inside `App.tsx` as closures over `setEncounter`, which
 * made them impossible to exercise without a renderer — so the only way to know
 * whether removing a combatant repaired the turn cursor was to click it. They
 * take a state and return a state now. `App` decides *when*; this decides *what*.
 *
 * Id generation is a parameter rather than a global, so a test gets to say what
 * the ids are.
 */

export const NPC_COUNT_MIN = 1
export const NPC_COUNT_MAX = 20

export type MakeId = (prefix: string) => string

/** The name prefix a monster type numbers under. Anonymous NPCs share "NPC". */
export const counterKey = (monsterType?: string) => monsterType?.trim() || 'NPC'

/**
 * v1 has no counter, so derive one from the largest suffix already in use. A
 * fight holding "Goblin 1" and "Goblin 3" must not hand out "Goblin 3" again.
 */
export function rebuildNameCounter(members: Combatant[]): Record<string, number> {
  const counter: Record<string, number> = {}
  for (const m of members) {
    const key = counterKey(m.monsterType)
    const match = new RegExp(`^${key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s+(\\d+)$`).exec(
      m.name.trim()
    )
    const n = match ? Number(match[1]) : 0
    if (n > (counter[key] ?? 0)) counter[key] = n
  }
  return counter
}

export const emptyEncounter = (): EncounterState => ({
  members: [],
  turnIndex: 0,
  round: 1,
  nameCounter: {},
})

export const activeMember = (state: EncounterState): Combatant | undefined =>
  state.members[state.turnIndex]

/**
 * Replace the member list and put the turn cursor somewhere legal.
 *
 * Removing members without doing this is what left `turnIndex` pointing at a
 * different combatant, or past the end of the array with nothing highlighted at
 * all. Whoever was active stays active if they survived.
 */
export function withMembers(state: EncounterState, members: Combatant[]): EncounterState {
  const activeId = activeMember(state)?.id
  let turnIndex = 0
  if (members.length) {
    const stillThere = members.findIndex((m) => m.id === activeId)
    turnIndex = stillThere >= 0 ? stillThere : clamp(state.turnIndex, 0, members.length - 1)
  }
  return { ...state, members, turnIndex, round: members.length ? state.round : 1 }
}

export function addPlayerCharacters(
  state: EncounterState,
  characters: Character[],
  makeId: MakeId = uid
): EncounterState {
  const additions = characters
    .filter((pc) => !state.members.some((m) => m.refId === pc.id))
    .map((pc) => characterToCombatant(pc, makeId))
  if (!additions.length) return state
  return { ...state, members: [...state.members, ...additions] }
}

export function removeMember(state: EncounterState, id: string): EncounterState {
  const members = state.members.filter((m) => m.id !== id)
  if (members.length === state.members.length) return state
  return withMembers(state, members)
}

export function removeMembersOfCharacter(state: EncounterState, characterId: string): EncounterState {
  const members = state.members.filter((m) => m.refId !== characterId)
  if (members.length === state.members.length) return state
  return withMembers(state, members)
}

/**
 * Add `draft.count` NPCs.
 *
 * Numbering comes off a per-type high-water mark held on the encounter, not off
 * a count of the ones currently alive — counting live members is what produced a
 * second "Goblin 3" after Goblin 2 was removed. An explicitly typed name is the
 * GM's business and does not touch the counter.
 */
export function addNpcs(
  state: EncounterState,
  draft: NpcDraft,
  makeId: MakeId = uid
): EncounterState {
  const count = clamp(Math.floor(draft.count), NPC_COUNT_MIN, NPC_COUNT_MAX)
  const monsterType = draft.monsterType.trim()
  const baseName = draft.name.trim()
  const key = counterKey(monsterType)
  const start = state.nameCounter[key] ?? 0
  const attributes = normalizeAttributes(draft.attributes)
  const toughness = makeToughness(draft.toughness, draft.toughness)

  const additions: Combatant[] = []
  for (let i = 0; i < count; i++) {
    additions.push({
      id: makeId('cmb'),
      source: 'npc',
      monsterType: monsterType || undefined,
      name: baseName ? (count > 1 ? `${baseName} ${i + 1}` : baseName) : `${key} ${start + i + 1}`,
      initiative: clamp(Math.floor(draft.initiative) || 0, 0, 99),
      toughness,
      defense: clamp(Math.floor(draft.defense) || 0, 1, 20),
      armor: draft.armor.trim() || 'Light (d4)',
      painThreshold: draft.painThreshold ?? null,
      prone: false,
      flanked: false,
      note: draft.note.trim(),
      // Omitted from the original object literal, so a preset's statblock was
      // dropped on the way into the fight.
      attributes,
    })
  }

  return {
    ...state,
    members: [...state.members, ...additions],
    nameCounter: baseName ? state.nameCounter : { ...state.nameCounter, [key]: start + count },
  }
}

/**
 * Apply one field edit.
 *
 * Every bound is enforced here rather than by the input that happens to raise
 * the change — a bound that lives in a widget is not a bound, and the previous
 * `Partial<Combatant>` merge could set any field to any value including
 * `source` and a negative toughness.
 */
export function applyMemberPatch(member: Combatant, patch: MemberPatch): Combatant {
  switch (patch.field) {
    case 'name':
      return { ...member, name: patch.value }
    case 'initiative':
      return { ...member, initiative: clamp(patch.value, 0, 99) }
    case 'toughnessCurrent':
      return { ...member, toughness: setCurrent(member.toughness, patch.value) }
    case 'toughnessMax':
      return { ...member, toughness: setMax(member.toughness, patch.value) }
    case 'defense':
      return { ...member, defense: clamp(patch.value, 1, 20) }
    case 'armor':
      return { ...member, armor: patch.value }
    case 'painThreshold':
      return { ...member, painThreshold: patch.value === null ? null : clamp(patch.value, 0, 999) }
    case 'prone':
      return { ...member, prone: patch.value }
    case 'flanked':
      return { ...member, flanked: patch.value }
    case 'note':
      return { ...member, note: patch.value }
  }
}

export function patchMember(
  state: EncounterState,
  id: string,
  patch: MemberPatch
): EncounterState {
  return {
    ...state,
    members: state.members.map((m) => (m.id === id ? applyMemberPatch(m, patch) : m)),
  }
}

/**
 * The undo key for a field edit, so a run of them collapses into one entry.
 * Toggles are single clicks and each deserves its own.
 */
export const coalesceKeyFor = (id: string, patch: MemberPatch): string | null =>
  patch.field === 'prone' || patch.field === 'flanked' ? null : `${patch.field}:${id}`

export function moveMember(
  state: EncounterState,
  id: string,
  direction: 'up' | 'down'
): EncounterState {
  const index = state.members.findIndex((m) => m.id === id)
  if (index === -1) return state
  const target = direction === 'up' ? index - 1 : index + 1
  if (target < 0 || target >= state.members.length) return state

  const members = [...state.members]
  const [moved] = members.splice(index, 1)
  members.splice(target, 0, moved)
  const activeId = activeMember(state)?.id
  return {
    ...state,
    members,
    turnIndex: activeId ? Math.max(0, members.findIndex((m) => m.id === activeId)) : 0,
  }
}

/**
 * Reorder by initiative, highest first, and start the order again.
 *
 * `round` is deliberately absent: sorting in round 5 used to put you back in
 * round 1 with no warning.
 */
export function sortByInitiative(state: EncounterState): EncounterState {
  return {
    ...state,
    members: [...state.members].sort((a, b) => (b.initiative || 0) - (a.initiative || 0)),
    turnIndex: 0,
  }
}

export function nextTurn(state: EncounterState): EncounterState {
  if (!state.members.length) return state
  const turnIndex = (state.turnIndex + 1) % state.members.length
  return { ...state, turnIndex, round: turnIndex === 0 ? state.round + 1 : state.round }
}

export function prevTurn(state: EncounterState): EncounterState {
  if (!state.members.length) return state
  const turnIndex = (state.turnIndex - 1 + state.members.length) % state.members.length
  const wrapped = turnIndex === state.members.length - 1
  return { ...state, turnIndex, round: wrapped ? Math.max(1, state.round - 1) : state.round }
}

export type AdjustMode = 'hurt' | 'heal'

/** Something worth telling the GM about, decided without touching the UI. */
export type AdjustEvent =
  | { kind: 'pain'; name: string; amount: number }
  | { kind: 'down'; name: string }

/**
 * What one blow does to one combatant.
 *
 * The pain threshold is tested against the damage that actually landed, not the
 * number typed into the box: a combatant on 2 hit for 20 takes 2, and being
 * reduced to zero is *down* rather than prone.
 */
export function resolveAdjustment(member: Combatant, mode: AdjustMode, amount: number) {
  const { next, dealt } = applyDelta(member.toughness, mode === 'hurt' ? -amount : amount)
  const proned =
    mode === 'hurt' && next.current > 0 && exceedsPainThreshold(member.painThreshold, dealt)
  return {
    toughness: next,
    dealt,
    prone: mode === 'heal' ? false : member.prone || proned,
    proned,
    downed: next.current === 0 && member.toughness.current > 0,
  }
}

export function adjust(
  state: EncounterState,
  id: string,
  mode: AdjustMode,
  amount: number
): EncounterState {
  const clamped = clamp(Math.floor(amount), 0, 999)
  if (clamped === 0) return state
  return {
    ...state,
    members: state.members.map((m) => {
      if (m.id !== id) return m
      const { toughness, prone } = resolveAdjustment(m, mode, clamped)
      return { ...m, toughness, prone }
    }),
  }
}

/** The events an adjustment would raise, for the caller to announce. */
export function adjustmentEvents(
  member: Combatant,
  mode: AdjustMode,
  amount: number
): AdjustEvent[] {
  const clamped = clamp(Math.floor(amount), 0, 999)
  if (clamped === 0) return []
  const outcome = resolveAdjustment(member, mode, clamped)
  const events: AdjustEvent[] = []
  if (outcome.proned) events.push({ kind: 'pain', name: member.name, amount: outcome.dealt })
  if (outcome.downed) events.push({ kind: 'down', name: member.name })
  return events
}

/** Mirror roster edits into the combatants that came from them. */
export function syncFromRoster(state: EncounterState, characters: Character[]): EncounterState {
  if (!state.members.length) return state
  const byId = new Map(characters.map((pc) => [pc.id, pc]))
  let changed = false
  const members = state.members.map((member) => {
    if (member.source !== 'pc' || !member.refId) return member
    const pc = byId.get(member.refId)
    if (!pc) return member
    const synced = syncMemberFromPc(member, pc)
    if (synced !== member) changed = true
    return synced
  })
  return changed ? { ...state, members } : state
}

export type SideTotals = { count: number; standing: number; toughness: number }

/**
 * What each side brings, as facts rather than a verdict.
 *
 * There used to be a difficulty score here, whose weights came from nowhere and
 * which divided by the party's average defence — zero for the shipped
 * placeholders, so with stock data it returned `Infinity`. It is not replaced by
 * a better score: this app records no weapons, abilities, traits or mystical
 * powers, which is most of what decides a Symbaroum fight.
 */
export function sideTotals(members: Combatant[]): { pcs: SideTotals; npcs: SideTotals } | null {
  if (!members.length) return null
  const describe = (side: Combatant[]): SideTotals => {
    const standing = side.filter((m) => !isDown(m.toughness))
    return {
      count: side.length,
      standing: standing.length,
      toughness: standing.reduce((sum, m) => sum + m.toughness.current, 0),
    }
  }
  return {
    pcs: describe(members.filter((m) => m.source === 'pc')),
    npcs: describe(members.filter((m) => m.source === 'npc')),
  }
}
