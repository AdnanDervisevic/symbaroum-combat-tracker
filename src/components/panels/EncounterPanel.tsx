import { useMemo } from 'react';
import type { Combatant, EncounterState } from '../../types';
import { CombatantCard } from '../cards/CombatantCard';

function calculateDifficulty(members: Combatant[]): { label: string; pcStats: string; npcStats: string } | null {
  const pcs = members.filter((m) => m.source === 'pc');
  const npcs = members.filter((m) => m.source === 'npc');

  if (pcs.length === 0 || npcs.length === 0) return null;

  const pcToughness = pcs.reduce((sum, m) => sum + m.toughness, 0);
  const npcToughness = npcs.reduce((sum, m) => sum + m.toughness, 0);
  const pcDefense = Math.round(pcs.reduce((sum, m) => sum + m.defense, 0) / pcs.length);
  const npcDefense = Math.round(npcs.reduce((sum, m) => sum + m.defense, 0) / npcs.length);

  // Ratio considers: toughness pool, numbers advantage, defense
  const toughnessRatio = npcToughness / pcToughness;
  const numbersRatio = npcs.length / pcs.length;
  const defenseRatio = npcDefense / pcDefense;
  const score = (toughnessRatio * 0.5) + (numbersRatio * 0.3) + (defenseRatio * 0.2);

  let label: string;
  if (score < 0.5) label = 'Trivial';
  else if (score < 0.8) label = 'Easy';
  else if (score < 1.2) label = 'Balanced';
  else if (score < 1.6) label = 'Hard';
  else if (score < 2.0) label = 'Deadly';
  else label = 'Overwhelming';

  return {
    label,
    pcStats: `${pcs.length} PCs (${pcToughness} HP, ${pcDefense} avg def)`,
    npcStats: `${npcs.length} NPCs (${npcToughness} HP, ${npcDefense} avg def)`,
  };
}

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

  const difficulty = useMemo(() => calculateDifficulty(encounter.members), [encounter.members]);

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
      {difficulty && (
        <p className="muted small">
          <strong>Difficulty: {difficulty.label}</strong> — {difficulty.pcStats} vs {difficulty.npcStats}
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
