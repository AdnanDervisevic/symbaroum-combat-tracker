import type { Character, CharacterAttributes, AttributeKey } from '../../types';
import { clamp } from '../../utils';
import { ATTRIBUTE_FIELDS } from '../../utils/combatLogic';

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
          <input
            type="number"
            value={character.initiative}
            onChange={(e) =>
              onUpdate(character.id, {
                initiative: Number(e.target.value) || 0,
              })
            }
          />
        </label>
        <label>
          <span>Toughness</span>
          <input
            type="number"
            value={character.toughness}
            onChange={(e) =>
              onUpdate(character.id, {
                toughness: clamp(Number(e.target.value) || 0, 0, 999),
              })
            }
          />
        </label>
        <label>
          <span>Defense</span>
          <input
            type="number"
            value={character.defense}
            onChange={(e) =>
              onUpdate(character.id, {
                defense: Number(e.target.value) || 0,
              })
            }
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
          <input
            type="number"
            value={character.painThreshold ?? ""}
            onChange={(e) =>
              onUpdate(character.id, {
                painThreshold:
                  e.target.value === ""
                    ? null
                    : Math.max(0, Number(e.target.value) || 0),
              })
            }
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
      {!character.id.startsWith('pc_default_') && (
        <div className="card-actions">
          <button className="danger ghost" onClick={() => onDelete(character.id)}>
            Delete
          </button>
        </div>
      )}
    </div>
  );
}
