import type { Character, Combatant, CharacterAttributes, AttributeKey } from '../types';
import { uid } from '../utils';

export const ATTRIBUTE_FIELDS = [
  { key: 'acc', label: 'ACC' },
  { key: 'cun', label: 'CUN' },
  { key: 'dis', label: 'DIS' },
  { key: 'per', label: 'PER' },
  { key: 'qui', label: 'QUI' },
  { key: 'res', label: 'RES' },
  { key: 'str', label: 'STR' },
  { key: 'vig', label: 'VIG' },
] as const satisfies ReadonlyArray<{ key: AttributeKey; label: string }>;

export const normalizeAttributes = (attrs?: CharacterAttributes | null): CharacterAttributes | null => {
  if (!attrs) return null;
  const next: CharacterAttributes = {};
  ATTRIBUTE_FIELDS.forEach(({ key }) => {
    const value = attrs[key];
    if (value === null || value === undefined) return;
    const num = Number(value);
    if (Number.isFinite(num)) {
      next[key] = num;
    }
  });
  return Object.keys(next).length ? next : null;
};

export const cloneAttributes = (attrs?: CharacterAttributes | null) => {
  const normalized = normalizeAttributes(attrs);
  return normalized ? { ...normalized } : null;
};

export const areAttributesEqual = (
  a?: CharacterAttributes | null,
  b?: CharacterAttributes | null,
) => {
  if (!a && !b) return true;
  if (!a || !b) return false;
  return ATTRIBUTE_FIELDS.every(({ key }) => (a[key] ?? null) === (b[key] ?? null));
};

export const syncMemberFromPc = (member: Combatant, pc: Character): Combatant => {
  const attrs = cloneAttributes(pc.attributes ?? null);
  const updated: Combatant = {
    ...member,
    name: pc.name,
    armor: pc.armor,
    defense: pc.defense,
    painThreshold: pc.painThreshold ?? null,
    attributes: attrs,
  };
  const changed =
    member.name !== updated.name ||
    member.armor !== updated.armor ||
    member.defense !== updated.defense ||
    (member.painThreshold ?? null) !== (pc.painThreshold ?? null) ||
    !areAttributesEqual(member.attributes ?? null, attrs);
  return changed ? updated : member;
};

export const buildNewCharacter = (): Character => ({
  id: uid("pc"),
  name: "New PC",
  role: "",
  initiative: 0,
  toughness: 10,
  defense: 10,
  armor: "Light (d4)",
  painThreshold: null,
  note: "",
  attributes: null,
});

export const characterToCombatant = (pc: Character): Combatant => ({
  id: uid("cmb"),
  source: "pc",
  refId: pc.id,
  name: pc.name,
  initiative: pc.initiative,
  toughness: pc.toughness,
  defense: pc.defense,
  armor: pc.armor,
  painThreshold: pc.painThreshold ?? null,
  prone: false,
  flanked: false,
  note: pc.note,
  attributes: cloneAttributes(pc.attributes ?? null),
});
