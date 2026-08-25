import { useMemo } from 'react';
import type { EncounterState, MemberPatch } from '../../types';
import { CombatantCard } from '../cards/CombatantCard';
import { sideTotals } from '../../utils/encounter';
import type { SideTotals } from '../../utils/encounter';

const sideLabel = (noun: string, side: SideTotals) => {
  const plural = side.count === 1 ? '' : 's';
  const down = side.count - side.standing;
  const downNote = down > 0 ? `, ${down} down` : '';
  return `${side.count} ${noun}${plural} (${side.toughness} toughness standing${downNote})`;
};

type Props = {
  encounter: EncounterState;
  damageInputs: Record<string, number>;
  editingIds: Record<string, boolean>;
  canUndo: boolean;
  canRedo: boolean;
  onOpenBuilder: () => void;
  onSort: () => void;
  onPrevTurn: () => void;
  onNextTurn: () => void;
  onUndo: () => void;
  onRedo: () => void;
  onUpdateMember: (id: string, patch: MemberPatch) => void;
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
  canUndo,
  canRedo,
  onOpenBuilder,
  onSort,
  onPrevTurn,
  onNextTurn,
  onUndo,
  onRedo,
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

  const summary = useMemo(() => sideTotals(encounter.members), [encounter.members]);

  return (
    <section className="panel">
      <div className="panel-header">
        <h2>Initiative Order</h2>
        <div className="panel-actions wrap">
          <button onClick={onOpenBuilder}>Manage Combatants</button>
          <button onClick={onSort}>Sort</button>
          <button onClick={onPrevTurn}>Prev</button>
          <button onClick={onNextTurn}>Next</button>
          <button onClick={onUndo} disabled={!canUndo} title="Undo">↶</button>
          <button onClick={onRedo} disabled={!canRedo} title="Redo">↷</button>
        </div>
      </div>
      <p className="muted small">{roundInfo}</p>
      {summary && (
        <p className="muted small">
          {sideLabel('PC', summary.pcs)} vs {sideLabel('NPC', summary.npcs)}
        </p>
      )}
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
