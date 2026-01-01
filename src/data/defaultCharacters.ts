import type { Character } from '../types'
import { uid } from '../utils'

export function buildDefaultCharacters(): Character[] {
  return [
    {
      id: uid('pc'),
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
      id: uid('pc'),
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
      id: uid('pc'),
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
      id: uid('pc'),
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
