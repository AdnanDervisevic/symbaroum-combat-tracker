import { useEffect } from 'react';
import type { FormEvent as ReactFormEvent } from 'react';
import type { Character, EncounterState, EncounterHistoryEntry, CharacterAttributes } from '../../types';

type FormEvent = ReactFormEvent<HTMLFormElement>;

type NpcDraft = {
  name: string;
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
  encounterHistory: EncounterHistoryEntry[];
  onClose: () => void;
  onTogglePcSelection: (id: string) => void;
  onAddSelectedPcs: () => void;
  onClearEncounter: () => void;
  onNpcDraftChange: <K extends keyof NpcDraft>(field: K, value: NpcDraft[K]) => void;
  onAddNpc: (ev: FormEvent) => void;
  onRestoreEncounter: (entry: EncounterHistoryEntry) => void;
  onDeleteHistoryEntry: (id: string) => void;
};

export function AddCombatantModal({
  characters,
  encounter,
  selectedPcIds,
  npcDraft,
  encounterHistory,
  onClose,
  onTogglePcSelection,
  onAddSelectedPcs,
  onClearEncounter,
  onNpcDraftChange,
  onAddNpc,
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
            <form className="inline-form labeled" onSubmit={onAddNpc}>
              <label>
                <span>Name</span>
                <input
                  value={npcDraft.name}
                  onChange={(e) => onNpcDraftChange("name", e.target.value)}
                  required
                />
              </label>
              <label>
                <span>Initiative</span>
                <input
                  type="number"
                  value={npcDraft.initiative}
                  onChange={(e) => onNpcDraftChange("initiative", Number(e.target.value) || 0)}
                  required
                />
              </label>
              <label>
                <span>Toughness</span>
                <input
                  type="number"
                  value={npcDraft.toughness}
                  onChange={(e) => onNpcDraftChange("toughness", Number(e.target.value) || 0)}
                  required
                />
              </label>
              <label>
                <span>Defense</span>
                <input
                  type="number"
                  value={npcDraft.defense}
                  onChange={(e) => onNpcDraftChange("defense", Number(e.target.value) || 0)}
                  required
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
                <input
                  type="number"
                  value={npcDraft.painThreshold ?? ""}
                  onChange={(e) =>
                    onNpcDraftChange(
                      "painThreshold",
                      e.target.value === ""
                        ? null
                        : Math.max(0, Number(e.target.value) || 0)
                    )
                  }
                />
              </label>
              <label className="wide">
                <span>Notes</span>
                <input
                  value={npcDraft.note}
                  onChange={(e) => onNpcDraftChange("note", e.target.value)}
                />
              </label>
              <button type="submit">Add NPC</button>
            </form>
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
