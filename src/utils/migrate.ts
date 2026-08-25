import type {
  BestiaryEntry,
  Character,
  Combatant,
  EncounterState,
  Toughness,
} from '../types'
import { makeToughness } from './toughness'
import { uid } from './core'
import { rebuildNameCounter } from './encounter'
import { normalizeAttributes } from './character'

/**
 * Reading version 1 data — the shape the app shipped with — and repairing
 * anything that is out of range.
 *
 * Two rules here, both learned the hard way:
 *
 *   1. Repair, do not reject. A save with `turnIndex: 5` and no members is not
 *      worth refusing; it is worth fixing.
 *   2. Say what was repaired. A silent repair and a silent acceptance look
 *      identical from the outside, which is how a corrupted file gets trusted.
 */

type Raw = Record<string, unknown>

const asRecord = (v: unknown): Raw => (v && typeof v === 'object' ? (v as Raw) : {})
const asArray = (v: unknown): unknown[] => (Array.isArray(v) ? v : [])
const asString = (v: unknown, fallback = ''): string => (typeof v === 'string' ? v : fallback)
const asNumber = (v: unknown, fallback = 0): number =>
  typeof v === 'number' && Number.isFinite(v) ? v : fallback
const asBool = (v: unknown, fallback = false): boolean =>
  typeof v === 'boolean' ? v : fallback
const asNullableNumber = (v: unknown): number | null =>
  typeof v === 'number' && Number.isFinite(v) ? v : null

/**
 * A bare v1 number means different things depending on whose it is, and getting
 * this wrong silently rewrites people's characters.
 *
 * On a roster character or a bestiary template there is no fight in progress, so
 * the number *is* the maximum. On a combatant it is the current value, and the
 * maximum has to come from somewhere else — the roster entry or bestiary
 * template it came from — because v1 never stored one.
 */
function readMaxToughness(v: unknown, fallback: number): number {
  if (typeof v === 'number' && Number.isFinite(v)) return makeToughness(v, v).max
  const rec = asRecord(v)
  if (typeof rec.max === 'number') return makeToughness(asNumber(rec.max, fallback), rec.max).max
  return makeToughness(fallback, fallback).max
}

function readToughnessPair(v: unknown, knownMax?: number): Toughness {
  if (typeof v === 'number' && Number.isFinite(v)) {
    // Falling back to the current value is the honest last resort; the Edit
    // panel can raise the maximum afterwards.
    return makeToughness(v, Math.max(v, knownMax ?? v))
  }
  const rec = asRecord(v)
  if (typeof rec.current === 'number' || typeof rec.max === 'number') {
    const max = asNumber(rec.max, asNumber(rec.current, knownMax ?? 10))
    return makeToughness(asNumber(rec.current, max), max)
  }
  return makeToughness(knownMax ?? 10, knownMax ?? 10)
}

export const BUILTIN_ID_PREFIX = 'pc_default_'

export function readCharacter(v: unknown): Character {
  const c = asRecord(v)
  const id = asString(c.id) || uid('pc')
  return {
    id,
    name: asString(c.name, 'Unnamed'),
    role: asString(c.role),
    initiative: asNumber(c.initiative),
    toughness: readMaxToughness(c.toughness, 10),
    defense: asNumber(c.defense, 10),
    armor: asString(c.armor),
    painThreshold: asNullableNumber(c.painThreshold),
    attributes: normalizeAttributes(c.attributes as never),
    note: asString(c.note),
    // v1 never stored this, so recover it from the id prefix -- exactly once,
    // here, rather than on every render.
    isBuiltin: typeof c.isBuiltin === 'boolean' ? c.isBuiltin : id.startsWith(BUILTIN_ID_PREFIX),
  }
}

export const readCharacters = (v: unknown): Character[] => asArray(v).map(readCharacter)

export function readBestiaryEntry(v: unknown): BestiaryEntry {
  const e = asRecord(v)
  return {
    id: asString(e.id) || uid('bst'),
    monsterType: asString(e.monsterType, 'Unknown'),
    initiative: asNumber(e.initiative),
    toughness: readMaxToughness(e.toughness, 10),
    defense: asNumber(e.defense, 10),
    armor: asString(e.armor),
    painThreshold: asNullableNumber(e.painThreshold),
    note: asString(e.note),
    attributes: normalizeAttributes(e.attributes),
    updatedAt: asNumber(e.updatedAt, Date.now()),
  }
}

export const readBestiary = (v: unknown): BestiaryEntry[] => asArray(v).map(readBestiaryEntry)

function readCombatant(
  v: unknown,
  maxByRef: Map<string, number>,
  report: (correction: string) => void
): Combatant {
  const m = asRecord(v)
  const id = asString(m.id) || uid('cmb')
  const refId = asString(m.refId) || null
  const claimsPc = asString(m.source) === 'pc'
  const isPc = claimsPc && !!refId
  // The union has no room for "a player character belonging to nobody", and
  // demoting one is a change to the file worth mentioning rather than making
  // quietly.
  if (claimsPc && !isPc) {
    report(`${asString(m.name, 'A combatant')} was a player character with no roster entry; kept as an NPC.`)
  }
  // A wounded combatant's maximum was never stored, so recover it from the
  // roster entry or bestiary template it came from.
  const known = isPc ? maxByRef.get(refId as string) : maxByRef.get(asString(m.monsterType))
  const common = {
    id,
    name: asString(m.name, 'Unnamed'),
    initiative: asNumber(m.initiative),
    toughness: readToughnessPair(m.toughness, known),
    defense: asNumber(m.defense, 10),
    armor: asString(m.armor),
    painThreshold: asNullableNumber(m.painThreshold),
    prone: asBool(m.prone),
    flanked: asBool(m.flanked),
    attributes: normalizeAttributes(m.attributes as never),
    note: asString(m.note),
  }
  return isPc
    ? { ...common, source: 'pc', refId: refId as string }
    : { ...common, source: 'npc', monsterType: asString(m.monsterType) || undefined }
}


export type Repair = { encounter: EncounterState; corrections: string[] }

/**
 * Read an encounter from anything and hand back one the UI can actually be in,
 * plus the list of what had to change to get there.
 */
export function readEncounter(
  v: unknown,
  context: { characters?: Character[]; bestiary?: BestiaryEntry[] } = {}
): Repair {
  const corrections: string[] = []
  const e = asRecord(v)

  const maxByRef = new Map<string, number>()
  for (const c of context.characters ?? []) maxByRef.set(c.id, c.toughness)
  for (const b of context.bestiary ?? []) maxByRef.set(b.monsterType, b.toughness)

  const report = (correction: string) => corrections.push(correction)
  const seen = new Set<string>()
  const members: Combatant[] = asArray(e.members).map((raw) => {
    const read = readCombatant(raw, maxByRef, report)
    if (!seen.has(read.id)) {
      seen.add(read.id)
      return read
    }
    corrections.push(`Two combatants shared the id ${read.id}; the second was renumbered.`)
    const member = { ...read, id: uid('cmb') }
    seen.add(member.id)
    return member
  })

  const rawRound = asNumber(e.round, 1)
  const round = Math.max(1, Math.floor(rawRound))
  if (round !== rawRound) corrections.push(`Round ${rawRound} is not a round; set to ${round}.`)

  const rawIndex = asNumber(e.turnIndex, 0)
  let turnIndex = Math.floor(rawIndex)
  if (!members.length) {
    turnIndex = 0
  } else if (turnIndex < 0 || turnIndex >= members.length) {
    turnIndex = Math.min(Math.max(0, turnIndex), members.length - 1)
  }
  if (turnIndex !== rawIndex) {
    corrections.push(`The turn marker pointed at position ${rawIndex}; moved to ${turnIndex}.`)
  }

  // Absent is not the same as empty. An encounter whose NPCs were all named by
  // hand legitimately has `{}`, and rebuilding that on every read would report a
  // correction which had not been made.
  const hasCounter =
    !!e.nameCounter && typeof e.nameCounter === 'object' && !Array.isArray(e.nameCounter)
  const stored = asRecord(e.nameCounter) as Record<string, number>
  const usable =
    hasCounter && Object.values(stored).every((n) => typeof n === 'number' && Number.isFinite(n))
  let nameCounter = stored
  if (!usable) {
    nameCounter = rebuildNameCounter(members)
    if (members.length) corrections.push('Rebuilt the NPC name counter from the names in use.')
  }

  return { encounter: { members, turnIndex, round, nameCounter }, corrections }
}
