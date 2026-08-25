import type { BestiaryEntry, NpcDraft } from '../types'
import type { MonsterPreset } from '../data/defaultMonsters'
import { clamp } from './core'
import { normalizeAttributes } from './character'
import { makeToughness } from './toughness'

/**
 * Filling in the add-NPC form, and turning what it holds into a bestiary entry.
 *
 * This lived in `App.tsx` as three object literals, which meant the one rule in
 * it that is actually about Symbaroum -- how a statblock's defence becomes a
 * roll-under target -- was sitting in a component where nothing could test it.
 */

export const emptyDraft = (): NpcDraft => ({
  monsterType: '',
  name: '',
  count: 1,
  initiative: 0,
  toughness: 10,
  defense: 10,
  armor: 'Light (d4)',
  painThreshold: null,
  note: '',
  attributes: null,
})

/**
 * A monster statblock prints the **modifier** an attacker applies; a character
 * sheet prints the **roll-under target**. They are `10 - x` apart, and this app
 * stores the target everywhere so that the number in a box always means the same
 * thing regardless of which side it came from.
 */
export const targetFromModifier = (modifier: number): number => clamp(10 - modifier, 1, 20)

export function draftFromPreset(preset: MonsterPreset): NpcDraft {
  return {
    ...emptyDraft(),
    monsterType: preset.name,
    initiative: preset.attributes.qui ?? 0,
    defense: preset.defense === null ? 10 : targetFromModifier(preset.defense),
    toughness: preset.toughness ?? 10,
    armor: preset.armor ?? '',
    painThreshold: preset.painThreshold,
    attributes: preset.attributes,
  }
}

/**
 * A bestiary entry was written by the GM through this same form, so its defence
 * is already a target and is carried across unchanged.
 */
export function draftFromBestiaryEntry(entry: BestiaryEntry): NpcDraft {
  return {
    ...emptyDraft(),
    monsterType: entry.monsterType,
    initiative: entry.initiative,
    toughness: entry.toughness,
    defense: entry.defense,
    armor: entry.armor,
    painThreshold: entry.painThreshold,
    note: entry.note,
    attributes: entry.attributes ?? null,
  }
}

export function bestiaryEntryFromDraft(
  draft: NpcDraft,
  { id, now }: { id: string; now: number }
): BestiaryEntry {
  return {
    id,
    monsterType: draft.monsterType.trim(),
    initiative: Number(draft.initiative) || 0,
    toughness: makeToughness(draft.toughness, draft.toughness).max,
    defense: Number(draft.defense) || 0,
    armor: draft.armor.trim() || 'Light (d4)',
    painThreshold: draft.painThreshold ?? null,
    note: draft.note.trim(),
    // Carried so that reloading a saved monster restores its statblock too.
    attributes: normalizeAttributes(draft.attributes),
    updatedAt: now,
  }
}
