import { usePersistentState } from './usePersistentState'
import { usePersistentHistory } from './usePersistentHistory'
import type { SetOptions } from './usePersistentHistory'
import type {
  BestiaryEntry,
  Character,
  EncounterHistoryEntry,
  EncounterState,
} from '../types'
import { buildDefaultCharacters } from '../data/defaultCharacters'
import { readBestiary, readCharacters, readEncounter } from '../utils/migrate'
import { emptyEncounter } from '../utils/encounter'
import { uid } from '../utils/core'

/**
 * Everything the app keeps between visits, loaded in one place.
 *
 * The **order of these declarations is load-bearing** and is the reason they
 * belong together rather than scattered through a component: the encounter and
 * the archive both need the roster and the bestiary already loaded, because
 * version 1 never stored a combatant's maximum toughness and it has to be
 * recovered from whichever sheet or template the combatant came from.
 *
 * Every key needs a version 1 reader, including the dull ones. Without one the
 * reader finds no version 2 key, skips the version 1 key it cannot interpret,
 * and returns the initial value -- which for the archive means a shelf of saved
 * encounters silently becoming an empty list.
 */

export type Theme = 'light' | 'dark'

export type StoredSession = {
  characters: Character[]
  setCharacters: React.Dispatch<React.SetStateAction<Character[]>>
  bestiary: BestiaryEntry[]
  setBestiary: React.Dispatch<React.SetStateAction<BestiaryEntry[]>>
  encounter: EncounterState
  setEncounter: (value: EncounterState | ((prev: EncounterState) => EncounterState), options?: SetOptions) => void
  undo: () => void
  redo: () => void
  canUndo: boolean
  canRedo: boolean
  encounterHistory: EncounterHistoryEntry[]
  setEncounterHistory: React.Dispatch<React.SetStateAction<EncounterHistoryEntry[]>>
  theme: Theme
  setTheme: React.Dispatch<React.SetStateAction<Theme>>
}

export function useStoredSession(): StoredSession {
  const [characters, setCharacters] = usePersistentState<Character[]>(
    'sct.characters',
    buildDefaultCharacters,
    readCharacters
  )

  const [bestiary, setBestiary] = usePersistentState<BestiaryEntry[]>(
    'sct.bestiary',
    () => [],
    readBestiary
  )

  const [encounter, setEncounter, { undo, redo, canUndo, canRedo }] =
    usePersistentHistory<EncounterState>('sct.encounter', emptyEncounter, (raw) =>
      readEncounter(raw, { characters, bestiary }).encounter
    )

  const [encounterHistory, setEncounterHistory] = usePersistentState<EncounterHistoryEntry[]>(
    'sct.encounterHistory',
    () => [],
    (raw) =>
      (Array.isArray(raw) ? raw : []).map((entry) => {
        const e = (entry ?? {}) as Partial<EncounterHistoryEntry>
        return {
          id: typeof e.id === 'string' ? e.id : uid('hist'),
          timestamp: typeof e.timestamp === 'number' ? e.timestamp : Date.now(),
          label: typeof e.label === 'string' ? e.label : 'Archived encounter',
          encounter: readEncounter(e.encounter, { characters, bestiary }).encounter,
        }
      })
  )

  const [theme, setTheme] = usePersistentState<Theme>('sct.theme', () => 'light', (raw) =>
    raw === 'dark' ? 'dark' : 'light'
  )

  return {
    characters,
    setCharacters,
    bestiary,
    setBestiary,
    encounter,
    setEncounter,
    undo,
    redo,
    canUndo,
    canRedo,
    encounterHistory,
    setEncounterHistory,
    theme,
    setTheme,
  }
}
