import type { Character, AttributeKey } from '../../types';
import { CharacterCard } from '../cards/CharacterCard';

type Props = {
  characters: Character[];
  onUpdate: (id: string, patch: Partial<Character>) => void;
  onDelete: (id: string) => void;
  onAdd: () => void;
  onAttributeChange: (id: string, key: AttributeKey, value: string) => void;
  onExport: () => void;
  onImport: () => void;
};

export function CharactersPanel({
  characters,
  onUpdate,
  onDelete,
  onAdd,
  onAttributeChange,
  onExport,
  onImport,
}: Props) {
  return (
    <section className="panel">
      <div className="panel-header">
        <h2>Player Characters</h2>
        <div className="panel-actions wrap">
          <button onClick={onAdd}>Add Character</button>
          <button onClick={onExport}>Export</button>
          <button onClick={onImport}>Import</button>
        </div>
      </div>
      <div className="cards two-col">
        {characters.map((character) => (
          <CharacterCard
            key={character.id}
            character={character}
            onUpdate={onUpdate}
            onDelete={onDelete}
            onAttributeChange={onAttributeChange}
          />
        ))}
      </div>
    </section>
  );
}
