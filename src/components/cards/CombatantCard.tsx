import type { Combatant, CharacterAttributes, MemberPatch } from '../../types';
import { ATTRIBUTE_FIELDS } from '../../utils/character';
import { NumberField, OptionalNumberField } from '../common/NumberField';
import { MAX_TOUGHNESS, isDown } from '../../utils/toughness';

const hasAttributes = (attrs?: CharacterAttributes | null) =>
  !!attrs && ATTRIBUTE_FIELDS.some(({ key }) => attrs[key] !== null && attrs[key] !== undefined);

// In Symbaroum, 10 is the baseline (modifier 0). Each point above 10 gives −1
// and each point below 10 gives +1, so modifier = 10 − rawValue.
function attrModifier(v: number): string {
  const mod = 10 - v;
  return mod > 0 ? `+${mod}` : String(mod);
}

type Props = {
  member: Combatant;
  isActive: boolean;
  isEditing: boolean;
  adjustValue: number;
  onUpdate: (id: string, patch: MemberPatch) => void;
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
  const down = isDown(member.toughness);
  return (
    <div
      className={
        "card encounter-card" + (isActive ? " active" : "") + (down ? " downed" : "")
      }
    >
      <div className="card-line compact-header">
        <div className="name-wrapper">
          <input
            className="name"
            value={member.name}
            readOnly={!isEditing}
            aria-readonly={!isEditing}
            onChange={(e) => onUpdate(member.id, { field: 'name', value: e.target.value })}
          />
          {member.monsterType && (
            <span className="monster-type-badge">{member.monsterType}</span>
          )}
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
                <strong>{attrModifier(v)}</strong>
              </div>
            );
          })}
        </div>
      )}
      <div className="stat-row single-line">
        <label className="stat-field">
          <span>Init</span>
          <NumberField
            value={member.initiative}
            min={0}
            max={99}
            readOnly={!isEditing}
            onCommit={(value) => onUpdate(member.id, { field: 'initiative', value })}
          />
        </label>
        <label className="stat-field">
          {/* Current out of maximum. The maximum used to not exist at all --
              one number was doing both jobs, so a wounded combatant had
              forgotten what it started with. */}
          <span>Tough</span>
          <NumberField
            value={member.toughness.current}
            min={0}
            max={member.toughness.max}
            readOnly={!isEditing}
            onCommit={(value) => onUpdate(member.id, { field: 'toughnessCurrent', value })}
          />
        </label>
        <label className="stat-field">
          <span>Max</span>
          <NumberField
            value={member.toughness.max}
            min={1}
            max={MAX_TOUGHNESS}
            readOnly={!isEditing}
            onCommit={(value) => onUpdate(member.id, { field: 'toughnessMax', value })}
          />
        </label>
        <label className="stat-field">
          <span>Def</span>
          <NumberField
            value={member.defense}
            min={1}
            max={20}
            readOnly={!isEditing}
            onCommit={(value) => onUpdate(member.id, { field: 'defense', value })}
          />
        </label>
        <label className="stat-field stat-field--text">
          <span>Armor</span>
          <input
            value={member.armor}
            readOnly={!isEditing}
            aria-readonly={!isEditing}
            onChange={(e) => onUpdate(member.id, { field: 'armor', value: e.target.value })}
          />
        </label>
        <label className="stat-field stat-field--text">
          <span>Pain Th.</span>
          <OptionalNumberField
            value={member.painThreshold}
            min={0}
            max={MAX_TOUGHNESS}
            placeholder="never"
            readOnly={!isEditing}
            onCommit={(value) => onUpdate(member.id, { field: 'painThreshold', value })}
          />
        </label>
      </div>
      {/* Below the strips a printed entry is a label column and a value column
          -- Weapons, Abilities, Traits, Tactics. Current toughness lives here
          rather than on a rule of its own, which is what it had before only
          because nothing else on the card would take it. */}
      <div className="entry-row">
        <div className="entry-label">State</div>
        <div className="entry-value status-row">
          <span className="toughness-readout">
            {down ? (
              'Down'
            ) : (
              <>
                {member.toughness.current}
                <span className="of-max"> / {member.toughness.max}</span>
              </>
            )}
          </span>
          <label className="toggle">
            <input
              type="checkbox"
              checked={member.prone}
              onChange={(e) => onUpdate(member.id, { field: 'prone', value: e.target.checked })}
            />
            Prone
          </label>
          <label className="toggle">
            <input
              type="checkbox"
              checked={member.flanked}
              onChange={(e) => onUpdate(member.id, { field: 'flanked', value: e.target.checked })}
            />
            Flanked
          </label>
        </div>
      </div>
      <div className="entry-row alt">
        <div className="entry-label">Damage</div>
        <div className="entry-value adjust-row inline">
          <label className="amount-inline">
            <span>Amount</span>
            <NumberField
              value={adjustValue}
              min={0}
              max={999}
              onCommit={(value) => onAdjustInput(member.id, value)}
            />
          </label>
          <div className="adjust-buttons">
            <button onClick={() => onApplyAdjustment(member.id, "heal")}>Heal</button>
            <button onClick={() => onApplyAdjustment(member.id, "hurt")}>Hurt</button>
          </div>
        </div>
      </div>
      <div className="entry-row grows">
        <div className="entry-label">Notes</div>
        <textarea
          className="entry-value"
          value={member.note || ""}
          onChange={(e) => onUpdate(member.id, { field: 'note', value: e.target.value })}
          placeholder="Conditions, effects"
        />
      </div>
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
