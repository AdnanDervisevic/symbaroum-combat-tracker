import type { Character } from '../types'

/**
 * The party the app ships with.
 *
 * `isBuiltin` has to be set here as well as recovered during migration: it is
 * what hides the Delete button, and a fresh install never goes through the
 * migration that reads it off the `pc_default_` prefix.
 *
 * `defense` is the roll-under target from the character sheet, not the modifier
 * a monster statblock prints.
 */
export function buildDefaultCharacters(): Character[] {
  return [
    {
      id: 'pc_default_cassimei',
      name: 'Cassimei',
      role: 'Bard',
      initiative: 0,
      toughness: 10,
      defense: 8,
      armor: 'Light (d4)',
      painThreshold: null,
      attributes: null,
      note: 'Charming storyteller',
      isBuiltin: true
    },
    {
      id: 'pc_default_thalia',
      name: 'Thalia',
      role: 'Wizard',
      initiative: 0,
      toughness: 10,
      defense: 3,
      armor: 'Light (d4)',
      painThreshold: null,
      attributes: null,
      note: 'Mystic scholar',
      isBuiltin: true
    },
    {
      id: 'pc_default_vigoi',
      name: 'Vigoi',
      role: 'Warrior',
      initiative: 0,
      toughness: 10,
      defense: 13,
      armor: 'Medium (d8)',
      painThreshold: null,
      attributes: null,
      note: 'Placeholder stats',
      isBuiltin: true
    },
    {
      id: 'pc_default_ymma',
      name: 'Ymma',
      role: 'Goblin',
      initiative: 0,
      toughness: 10,
      defense: 13,
      armor: 'Light (d4)',
      painThreshold: null,
      attributes: null,
      note: 'Placeholder stats',
      isBuiltin: true
    }
  ]
}
