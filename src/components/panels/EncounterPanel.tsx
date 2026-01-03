import type { Combatant, EncounterState } from '../../types';
import { CombatantCard } from '../cards/CombatantCard';

type Props = {
  encounter: EncounterState;
  damageInputs: Record<string, number>;
  editingIds: Record<string, boolean>;
  onOpenBuilder: () => void;
  onSort: () => void;
  onPrevTurn: () => void;
  onNextTurn: () => void;
  onUpdateMember: (id: string, patch: Partial<Combatant>) => void;
  onRemoveMember: (id: string) => void;
  onMoveMember: (id: string, direction: 'up' | 'down') => void;
  onToggleEditing: (id: string) => void;
  onAdjustInput: (id: string, value: number) => void;
  onApplyAdjustment: (id: string, mode: 'hurt' | 'heal') => void;
};

export function EncounterPanel({
  encounter,
  damageInputs,
  editingIds,
  onOpenBuilder,
  onSort,
  onPrevTurn,
  onNextTurn,
  onUpdateMember,
  onRemoveMember,
  onMoveMember,
  onToggleEditing,
  onAdjustInput,
  onApplyAdjustment,
}: Props) {
  const activeMember = encounter.members[encounter.turnIndex];
  const roundInfo = encounter.members.length
    ? "Round " + encounter.round + " — Active: " + (activeMember?.name ?? "-")
    : "No combatants yet.";

  return (
    <section className="panel">
      <div className="panel-header">
        <h2>Initiative Order</h2>
        <div className="panel-actions wrap">
          <button onClick={onOpenBuilder}>Manage Combatants</button>
          <button onClick={onSort}>Sort</button>
          <button onClick={onPrevTurn}>Prev</button>
          <button onClick={onNextTurn}>Next</button>
        </div>
      </div>
      <p className="muted small">{roundInfo}</p>
      <div className="cards encounter-grid">
        {!encounter.members.length && (
          <p className="muted">Add PCs or NPCs from the Manage dialog.</p>
        )}
        {encounter.members.map((member, idx) => (
          <CombatantCard
            key={member.id}
            member={member}
            isActive={idx === encounter.turnIndex}
            isEditing={!!editingIds[member.id]}
            adjustValue={damageInputs[member.id] ?? 1}
            onUpdate={onUpdateMember}
            onRemove={onRemoveMember}
            onMove={onMoveMember}
            onToggleEditing={onToggleEditing}
            onAdjustInput={onAdjustInput}
            onApplyAdjustment={onApplyAdjustment}
          />
        ))}
      </div>
    </section>
  );
}
