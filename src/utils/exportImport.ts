import type { Character, EncounterState, ExportPayload } from '../types';

const CURRENT_VERSION = 1;

function createExportPayload(
  characters: Character[],
  encounter: EncounterState
): ExportPayload {
  return {
    version: CURRENT_VERSION,
    characters,
    encounter,
  };
}

export function exportToFile(characters: Character[], encounter: EncounterState): void {
  const payload = createExportPayload(characters, encounter);
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
  | { success: true; data: ExportPayload }
  | { success: false; error: string };

export function validateImportData(data: unknown): ImportResult {
  if (!data || typeof data !== 'object') {
    return { success: false, error: 'Invalid file format' };
  }

  const payload = data as Record<string, unknown>;

  if (typeof payload.version !== 'number') {
    return { success: false, error: 'Missing or invalid version' };
  }

  if (!Array.isArray(payload.characters)) {
    return { success: false, error: 'Missing or invalid characters array' };
  }

  if (!payload.encounter || typeof payload.encounter !== 'object') {
    return { success: false, error: 'Missing or invalid encounter data' };
  }

  const encounter = payload.encounter as Record<string, unknown>;
  if (!Array.isArray(encounter.members)) {
    return { success: false, error: 'Missing or invalid encounter members' };
  }

  // Validate each character has required fields
  for (const char of payload.characters) {
    if (!char || typeof char !== 'object') {
      return { success: false, error: 'Invalid character entry' };
    }
    const c = char as Record<string, unknown>;
    if (typeof c.id !== 'string' || typeof c.name !== 'string') {
      return { success: false, error: 'Character missing required fields (id, name)' };
    }
  }

  return {
    success: true,
    data: payload as unknown as ExportPayload
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
