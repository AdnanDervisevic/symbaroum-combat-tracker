import { useEffect, useRef } from 'react';
import type { FormEvent as ReactFormEvent } from 'react';
import type { Character, EncounterState, EncounterHistoryEntry, CharacterAttributes, BestiaryEntry } from '../../types';
import { DEFAULT_MONSTERS, MONSTER_CATEGORIES } from '../../data/defaultMonsters';
import type { MonsterPreset } from '../../data/defaultMonsters';
import { NPC_COUNT_MIN, NPC_COUNT_MAX } from '../../utils/npcConstants';
import { NumberField, OptionalNumberField } from '../common/NumberField';
import { MAX_TOUGHNESS } from '../../utils/toughness';

type FormEvent = ReactFormEvent<HTMLFormElement>;

type NpcDraft = {
  monsterType: string;
  name: string;
  count: number;
  initiative: number;
  toughness: number;
  defense: number;
  armor: string;
  painThreshold: number | null;
  note: string;
  attributes?: CharacterAttributes | null;
};

type Props = {
  characters: Character[];
  encounter: EncounterState;
  selectedPcIds: string[];
  npcDraft: NpcDraft;
  bestiary: BestiaryEntry[];
  encounterHistory: EncounterHistoryEntry[];
  onClose: () => void;
  onTogglePcSelection: (id: string) => void;
  onAddSelectedPcs: () => void;
  onClearEncounter: () => void;
  onNpcDraftChange: <K extends keyof NpcDraft>(field: K, value: NpcDraft[K]) => void;
  onAddNpc: (ev: FormEvent) => void;
  onLoadPreset: (preset: MonsterPreset) => void;
  onLoadBestiaryEntry: (entry: BestiaryEntry) => void;
  onDeleteBestiaryEntry: (id: string) => void;
  onRestoreEncounter: (entry: EncounterHistoryEntry) => void;
  onDeleteHistoryEntry: (id: string) => void;
};

export function AddCombatantModal({
  characters,
  encounter,
  selectedPcIds,
  npcDraft,
  bestiary,
  encounterHistory,
  onClose,
  onTogglePcSelection,
  onAddSelectedPcs,
  onClearEncounter,
  onNpcDraftChange,
  onAddNpc,
  onLoadPreset,
  onLoadBestiaryEntry,
  onDeleteBestiaryEntry,
  onRestoreEncounter,
  onDeleteHistoryEntry,
}: Props) {
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        onClose();
      }
    }
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const addLabel = npcDraft.count > 1 ? `Add ${npcDraft.count} NPCs` : 'Add NPC';
  const presetSelectRef = useRef<HTMLSelectElement>(null);

  function handlePresetChange(e: React.ChangeEvent<HTMLSelectElement>) {
    const name = e.target.value;
    if (!name) return;
    const preset = DEFAULT_MONSTERS.find((m) => m.name === name);
    if (preset) onLoadPreset(preset);
    // Reset the select back to the placeholder after loading
    if (presetSelectRef.current) presetSelectRef.current.value = '';
  }

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal">
        <div className="modal-header">
          <h3>Manage Combatants</h3>
          <button className="icon" aria-label="Close" onClick={onClose}>
            ×
          </button>
        </div>
        <div className="modal-body">
          <section className="modal-section">
            <h4>Player Characters</h4>
            <div className="pc-picker">
              {characters.length === 0 && (
                <p className="muted">Add characters in the Characters tab first.</p>
              )}
              {characters.map((pc) => {
                const disabled = encounter.members.some(
                  (m) => m.source === "pc" && m.refId === pc.id
                );
                const checked = selectedPcIds.includes(pc.id);
                return (
                  <label key={pc.id} className={"pc-option" + (disabled ? " disabled" : "")}>
                    <input
                      type="checkbox"
                      disabled={disabled}
                      checked={checked}
                      onChange={() => onTogglePcSelection(pc.id)}
                    />
                    <div>
                      <strong>{pc.name}</strong>
                      <span className="muted">{pc.role || "PC"}</span>
                      <small className="muted">
                        Initiative {pc.initiative} • Toughness {pc.toughness}
                      </small>
                    </div>
                  </label>
                );
              })}
            </div>
            <div className="modal-actions">
              <button onClick={onAddSelectedPcs} disabled={!selectedPcIds.length}>
                Add Selected PCs
              </button>
              <button className="danger ghost" onClick={onClearEncounter}>
                Clear Encounter
              </button>
            </div>
          </section>

          <section className="modal-section">
            <h4>Quick NPC</h4>
            <div className="preset-row">
              <label className="preset-label">
                <span>Load from Book</span>
                <select
                  ref={presetSelectRef}
                  defaultValue=""
                  onChange={handlePresetChange}
                  className="preset-select"
                >
                  <option value="" disabled>— select monster —</option>
                  {MONSTER_CATEGORIES.map((cat) => (
                    <optgroup key={cat} label={cat}>
                      {DEFAULT_MONSTERS.filter((m) => m.category === cat).map((m) => (
                        <option key={m.name} value={m.name}>
                          {m.name} ({m.resistance})
                        </option>
                      ))}
                    </optgroup>
                  ))}
                </select>
              </label>
            </div>
            <form className="inline-form labeled" onSubmit={onAddNpc}>
              <label className="wide">
                <span>Monster Type</span>
                <input
                  value={npcDraft.monsterType}
                  onChange={(e) => onNpcDraftChange("monsterType", e.target.value)}
                  placeholder="e.g. Goblin"
                />
              </label>
              <label>
                <span>Name</span>
                <input
                  value={npcDraft.name}
                  onChange={(e) => onNpcDraftChange("name", e.target.value)}
                  placeholder="Auto-numbered from Monster Type if blank"
                />
              </label>
              <label>
                <span>Initiative</span>
                <NumberField
                  value={npcDraft.initiative}
                  min={0}
                  max={99}
                  onCommit={(value) => onNpcDraftChange("initiative", value)}
                />
              </label>
              <label>
                <span>Toughness</span>
                <NumberField
                  value={npcDraft.toughness}
                  min={1}
                  max={MAX_TOUGHNESS}
                  onCommit={(value) => onNpcDraftChange("toughness", value)}
                />
              </label>
              <label>
                {/* Presets store the modifier an attacker applies; it is
                    converted to the roll-under target when one is loaded, so
                    this box always means the same thing as the one on a
                    character sheet. */}
                <span>Defense (roll under)</span>
                <NumberField
                  value={npcDraft.defense}
                  min={1}
                  max={20}
                  onCommit={(value) => onNpcDraftChange("defense", value)}
                />
              </label>
              <label>
                <span>Armor</span>
                <input
                  value={npcDraft.armor}
                  onChange={(e) => onNpcDraftChange("armor", e.target.value)}
                />
              </label>
              <label>
                <span>Pain Threshold</span>
                <OptionalNumberField
                  value={npcDraft.painThreshold}
                  min={0}
                  max={MAX_TOUGHNESS}
                  placeholder="never"
                  onCommit={(value) => onNpcDraftChange("painThreshold", value)}
                />
              </label>
              <label>
                <span>Quantity</span>
                <NumberField
                  value={npcDraft.count}
                  min={NPC_COUNT_MIN}
                  max={NPC_COUNT_MAX}
                  onCommit={(value) => onNpcDraftChange("count", value)}
                />
              </label>
              <label className="wide">
                <span>Notes</span>
                <input
                  value={npcDraft.note}
                  onChange={(e) => onNpcDraftChange("note", e.target.value)}
                />
              </label>
              <button type="submit">{addLabel}</button>
            </form>
          </section>

          <section className="modal-section">
            <h4>Bestiary</h4>
            {bestiary.length === 0 ? (
              <p className="muted">Add an NPC with a Monster Type to save it here.</p>
            ) : (
              <div className="bestiary-list">
                {bestiary.map((entry) => (
                  <div key={entry.id} className="bestiary-item">
                    <div className="bestiary-info">
                      <strong>{entry.monsterType}</strong>
                      <small className="muted">
                        Tough {entry.toughness} • Def {entry.defense} • {entry.armor}
                      </small>
                    </div>
                    <div className="bestiary-actions">
                      <button onClick={() => onLoadBestiaryEntry(entry)}>Load</button>
                      <button className="danger ghost" onClick={() => onDeleteBestiaryEntry(entry.id)}>×</button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>

          {encounterHistory.length > 0 && (
            <section className="modal-section">
              <h4>Past Encounters</h4>
              <div className="history-list">
                {encounterHistory.map((entry) => (
                  <div key={entry.id} className="history-item">
                    <div className="history-info">
                      <strong>{entry.label}</strong>
                      <small className="muted">
                        {new Date(entry.timestamp).toLocaleDateString()} {new Date(entry.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </small>
                    </div>
                    <div className="history-actions">
                      <button onClick={() => onRestoreEncounter(entry)}>Restore</button>
                      <button className="danger ghost" onClick={() => onDeleteHistoryEntry(entry.id)}>×</button>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}
        </div>
      </div>
    </div>
  );
}

export type { NpcDraft };
