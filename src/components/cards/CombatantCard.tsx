import type { Combatant, CharacterAttributes } from '../../types';
import { clamp } from '../../utils';
import { ATTRIBUTE_FIELDS } from '../../utils/combatLogic';

const hasAttributes = (attrs?: CharacterAttributes | null) =>
  !!attrs && ATTRIBUTE_FIELDS.some(({ key }) => attrs[key] !== null && attrs[key] !== undefined);

type Props = {
  member: Combatant;
  isActive: boolean;
  isEditing: boolean;
  adjustValue: number;
  onUpdate: (id: string, patch: Partial<Combatant>) => void;
  onRemove: (id: string) => void;
  onMove: (id: string, direction: 'up' | 'down') => void;
  onToggleEditing: (id: string) => void;
  onAdjustInput: (id: string, value: number) => void;
  onApplyAdjustment: (id: string, mode: 'hurt' | 'heal') => void;
};

export function CombatantCard({
  member,
  isActive,
  isEditing,
  adjustValue,
  onUpdate,
  onRemove,
  onMove,
  onToggleEditing,
  onAdjustInput,
  onApplyAdjustment,
}: Props) {
  return (
    <div className={"card encounter-card" + (isActive ? " active" : "")}>
      <div className="card-line compact-header">
        <div className="name-wrapper">
          <input
            className="name"
            value={member.name}
            readOnly={!isEditing}
            aria-readonly={!isEditing}
            onChange={(e) => onUpdate(member.id, { name: e.target.value })}
          />
        </div>
        <div className="order-buttons">
          <button className="icon" onClick={() => onMove(member.id, "up")}>
            ↑
          </button>
          <button className="icon" onClick={() => onMove(member.id, "down")}>
            ↓
          </button>
        </div>
      </div>
      <div className="stat-block">
        <div className="stat-row single-line">
          <label className="stat-field">
            <span>Init</span>
            <input
              type="number"
              value={member.initiative}
              readOnly={!isEditing}
              aria-readonly={!isEditing}
              onChange={(e) =>
                onUpdate(member.id, {
                  initiative: Number(e.target.value) || 0,
                })
              }
            />
          </label>
          <label className="stat-field">
            <span>Tough</span>
            <input
              type="number"
              value={member.toughness}
              readOnly={!isEditing}
              aria-readonly={!isEditing}
              onChange={(e) =>
                onUpdate(member.id, {
                  toughness: clamp(Number(e.target.value) || 0, 0, 999),
                })
              }
            />
          </label>
          <label className="stat-field">
            <span>Def</span>
            <input
              type="number"
              value={member.defense}
              readOnly={!isEditing}
              aria-readonly={!isEditing}
              onChange={(e) =>
                onUpdate(member.id, {
                  defense: Number(e.target.value) || 0,
                })
              }
            />
          </label>
          <label className="stat-field">
            <span>Armor</span>
            <input
              value={member.armor}
              readOnly={!isEditing}
              aria-readonly={!isEditing}
              onChange={(e) => onUpdate(member.id, { armor: e.target.value })}
            />
          </label>
          <label className="stat-field">
            <span>Pain Th.</span>
            <input
              type="number"
              value={member.painThreshold ?? ""}
              readOnly={!isEditing}
              aria-readonly={!isEditing}
              onChange={(e) =>
                onUpdate(member.id, {
                  painThreshold:
                    e.target.value === ""
                      ? null
                      : Math.max(0, Number(e.target.value) || 0),
                })
              }
            />
          </label>
        </div>
      </div>
      {hasAttributes(member.attributes) && (
        <div className="attr-row">
          {ATTRIBUTE_FIELDS.filter(({ key }) => {
            const v = member.attributes?.[key];
            return typeof v === 'number' && Number.isFinite(v);
          }).map(({ key, label }) => {
            const v = member.attributes?.[key] as number;
            return (
              <div key={key} className="attr-cell" data-attr={key}>
                <span>{label}</span>
                <strong>{v}</strong>
              </div>
            );
          })}
        </div>
      )}
      <div className="status-row">
        <label className="toggle">
          <input
            type="checkbox"
            checked={member.prone}
            onChange={(e) => onUpdate(member.id, { prone: e.target.checked })}
          />
          Prone
        </label>
        <label className="toggle">
          <input
            type="checkbox"
            checked={member.flanked}
            onChange={(e) => onUpdate(member.id, { flanked: e.target.checked })}
          />
          Flanked
        </label>
      </div>
      <div className="adjust-row inline">
        <label className="amount-inline">
          <span>Amount</span>
          <input
            type="number"
            min={0}
            max={999}
            value={adjustValue}
            onChange={(e) =>
              onAdjustInput(
                member.id,
                Math.max(0, Math.min(999, Number(e.target.value) || 0))
              )
            }
          />
        </label>
        <div className="adjust-buttons">
          <button onClick={() => onApplyAdjustment(member.id, "heal")}>Heal</button>
          <button onClick={() => onApplyAdjustment(member.id, "hurt")}>Hurt</button>
        </div>
      </div>
      <textarea
        value={member.note || ""}
        onChange={(e) => onUpdate(member.id, { note: e.target.value })}
        placeholder="Notes / conditions"
      />
      <div className="card-actions">
        <button className="ghost" onClick={() => onToggleEditing(member.id)}>
          {isEditing ? "Done" : "Edit"}
        </button>
        <button className="danger ghost" onClick={() => onRemove(member.id)}>
          Remove
        </button>
      </div>
    </div>
  );
}
