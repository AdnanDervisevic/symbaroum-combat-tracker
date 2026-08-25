import type { Character, EncounterState, ExportPayload, BestiaryEntry } from '../types';
import { readBestiary, readCharacters, readEncounter } from './migrate';

/**
 * The save format this app writes, and the ones it can read. Version 1 is the
 * shape the app originally shipped with; it stays readable forever, because
 * people have exported files in it.
 */
export const CURRENT_SAVE_VERSION = 2;
const SUPPORTED_VERSIONS = [1, 2];
const supportedList = SUPPORTED_VERSIONS.join(' or ');

function createExportPayload(
  characters: Character[],
  encounter: EncounterState,
  bestiary: BestiaryEntry[]
): ExportPayload {
  return {
    version: CURRENT_SAVE_VERSION,
    characters,
    encounter,
    bestiary,
  };
}

export function exportToFile(characters: Character[], encounter: EncounterState, bestiary: BestiaryEntry[]): void {
  const payload = createExportPayload(characters, encounter, bestiary);
  const json = JSON.stringify(payload, null, 2);
  const blob = new Blob([json], { type: 'application/json' });
  const url = URL.createObjectURL(blob);

  const a = document.createElement('a');
  a.href = url;
  a.download = `symbaroum-combat-${new Date().toISOString().slice(0, 10)}.json`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export type ImportResult =
  | { success: true; data: ExportPayload; corrections: string[] }
  | { success: false; error: string };

/**
 * Refuse only what is structurally impossible; repair the rest and say so.
 *
 * The version used to be checked for being a number and never compared to
 * anything, so a file claiming version 7 was accepted and cast to the current
 * shape. And nothing looked at `turnIndex` or `round` at all, so an encounter
 * with no members and a turn marker at position 5 imported cleanly into a state
 * the UI cannot otherwise produce.
 */
export function validateImportData(data: unknown): ImportResult {
  if (!data || typeof data !== 'object') {
    return { success: false, error: 'Invalid file format' };
  }

  const payload = data as Record<string, unknown>;

  if (typeof payload.version !== 'number' || !Number.isFinite(payload.version)) {
    return { success: false, error: 'Missing or invalid version' };
  }

  if (!SUPPORTED_VERSIONS.includes(payload.version)) {
    return {
      success: false,
      error: `Unsupported save version ${payload.version}; this app reads version ${supportedList}.`,
    };
  }

  if (!Array.isArray(payload.characters)) {
    return { success: false, error: 'Missing or invalid characters array' };
  }

  if (!payload.encounter || typeof payload.encounter !== 'object') {
    return { success: false, error: 'Missing or invalid encounter data' };
  }

  const encounterRaw = payload.encounter as Record<string, unknown>;
  if (!Array.isArray(encounterRaw.members)) {
    return { success: false, error: 'Missing or invalid encounter members' };
  }

  const characters = readCharacters(payload.characters);
  const bestiary = readBestiary(payload.bestiary);
  const { encounter, corrections } = readEncounter(payload.encounter, { characters, bestiary });

  return {
    success: true,
    data: { version: CURRENT_SAVE_VERSION, characters, encounter, bestiary },
    corrections,
  };
}

export function importFromFile(): Promise<ImportResult> {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';

    input.onchange = async (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) {
        resolve({ success: false, error: 'No file selected' });
        return;
      }

      try {
        const text = await file.text();
        const data = JSON.parse(text);
        resolve(validateImportData(data));
      } catch {
        resolve({ success: false, error: 'Failed to parse JSON file' });
      }
    };

    input.oncancel = () => {
      resolve({ success: false, error: 'Import cancelled' });
    };

    input.click();
  });
}
