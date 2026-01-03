import { useEffect } from 'react';
import type { FormEvent } from 'react';
import type { Character, EncounterState, CharacterAttributes } from '../../types';

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
  onClose: () => void;
  onTogglePcSelection: (id: string) => void;
  onAddSelectedPcs: () => void;
  onClearEncounter: () => void;
  onNpcDraftChange: <K extends keyof NpcDraft>(field: K, value: NpcDraft[K]) => void;
  onAddNpc: (ev: FormEvent) => void;
};

export function AddCombatantModal({
  characters,
  encounter,
  selectedPcIds,
  npcDraft,
  onClose,
  onTogglePcSelection,
  onAddSelectedPcs,
  onClearEncounter,
  onNpcDraftChange,
  onAddNpc,
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
        </div>
      </div>
    </div>
  );
}

export type { NpcDraft };
