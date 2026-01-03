import type { Character } from '../types'

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
      note: 'Charming storyteller'
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
      note: 'Mystic scholar'
    },
    {
      id: 'pc_default_vigoi',
      name: 'Vigoi',
      role: 'Warrior',
      initiative: 0,
      toughness: 10,
      defense: 0,
      armor: 'Medium (d8)',
      painThreshold: null,
      attributes: null,
      note: 'Placeholder stats'
    },
    {
      id: 'pc_default_ymma',
      name: 'Ymma',
      role: 'Goblin',
      initiative: 0,
      toughness: 10,
      defense: 0,
      armor: 'Light (d4)',
      painThreshold: null,
      attributes: null,
      note: 'Placeholder stats'
    }
  ]
}
