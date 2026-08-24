import type { Character, CharacterAttributes, AttributeKey } from '../../types';
import { ATTRIBUTE_FIELDS } from '../../utils/combatLogic';
import { NumberField, OptionalNumberField } from '../common/NumberField';
import { MAX_TOUGHNESS } from '../../utils/toughness';

const hasAttributes = (attrs?: CharacterAttributes | null) =>
  !!attrs && ATTRIBUTE_FIELDS.some(({ key }) => attrs[key] !== null && attrs[key] !== undefined);

type Props = {
  character: Character;
  onUpdate: (id: string, patch: Partial<Character>) => void;
  onDelete: (id: string) => void;
  onAttributeChange: (id: string, key: AttributeKey, value: string) => void;
};

export function CharacterCard({ character, onUpdate, onDelete, onAttributeChange }: Props) {
  return (
    <div className="card character-card">
      <div className="card-line dual">
        <input
          className="name"
          value={character.name}
          onChange={(e) => onUpdate(character.id, { name: e.target.value })}
          placeholder="Name"
        />
        <input
          className="role"
          value={character.role}
          onChange={(e) => onUpdate(character.id, { role: e.target.value })}
          placeholder="Role"
        />
      </div>
      <div className="grid stats">
        <label>
          <span>Initiative</span>
          <NumberField
            value={character.initiative}
            min={0}
            max={99}
            onCommit={(initiative) => onUpdate(character.id, { initiative })}
          />
        </label>
        <label>
          <span>Toughness</span>
          <NumberField
            value={character.toughness}
            min={1}
            max={MAX_TOUGHNESS}
            onCommit={(toughness) => onUpdate(character.id, { toughness })}
          />
        </label>
        <label>
          {/* The number on the sheet: what this character rolls under. Monster
              statblocks print a modifier instead, and are converted on load. */}
          <span>Defense (roll under)</span>
          <NumberField
            value={character.defense}
            min={1}
            max={20}
            onCommit={(defense) => onUpdate(character.id, { defense })}
          />
        </label>
        <label>
          <span>Armor</span>
          <input
            value={character.armor}
            onChange={(e) => onUpdate(character.id, { armor: e.target.value })}
          />
        </label>
        <label>
          <span>Pain Threshold</span>
          <OptionalNumberField
            value={character.painThreshold}
            min={0}
            max={MAX_TOUGHNESS}
            placeholder="never"
            onCommit={(painThreshold) => onUpdate(character.id, { painThreshold })}
          />
        </label>
      </div>
      <details className="attributes-editor" open={hasAttributes(character.attributes)}>
        <summary>Attributes (optional)</summary>
        <div className="attributes-grid">
          {ATTRIBUTE_FIELDS.map(({ key, label }) => (
            <label key={key}>
              <span>{label}</span>
              <input
                type="number"
                value={character.attributes?.[key] ?? ''}
                onChange={(e) => onAttributeChange(character.id, key, e.target.value)}
              />
            </label>
          ))}
        </div>
      </details>
      <textarea
        value={character.note}
        onChange={(e) => onUpdate(character.id, { note: e.target.value })}
        placeholder="Notes"
      />
      {!character.isBuiltin && (
        <div className="card-actions">
          <button className="danger ghost" onClick={() => onDelete(character.id)}>
            Delete
          </button>
        </div>
      )}
    </div>
  );
}
