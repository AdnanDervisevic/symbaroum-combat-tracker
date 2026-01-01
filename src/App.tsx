import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import "./App.css";
import { usePersistentState } from "./hooks/usePersistentState";
import { buildDefaultCharacters } from "./data/defaultCharacters";
import type { Character, Combatant, EncounterState, CharacterAttributes, AttributeKey } from "./types";
import { clamp, uid } from "./utils";

// TODO: surface Symbaroum-specific presets for common NPC stat blocks
const TAB_OPTIONS = ["characters", "encounter", "help"] as const;
type TabKey = (typeof TAB_OPTIONS)[number];

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

type PainFlash = {
  name: string;
  amount: number;
  id: number;
};

type PainFlashTrigger = Omit<PainFlash, "id">;

const defaultEncounterState = (): EncounterState => ({
  members: [],
  turnIndex: 0,
  round: 1,
});

const buildNpcDraft = (): NpcDraft => ({
  name: "",
  initiative: 0,
  toughness: 10,
  defense: 10,
  armor: "Light (d4)",
  painThreshold: null,
  note: "",
  attributes: null,
});


const ATTRIBUTE_FIELDS = [
  { key: 'acc', label: 'ACC' },
  { key: 'cun', label: 'CUN' },
  { key: 'dis', label: 'DIS' },
  { key: 'per', label: 'PER' },
  { key: 'qui', label: 'QUI' },
  { key: 'res', label: 'RES' },
  { key: 'str', label: 'STR' },
  { key: 'vig', label: 'VIG' },
] as const satisfies ReadonlyArray<{ key: AttributeKey; label: string }>;

const hasAttributes = (attrs?: CharacterAttributes | null) =>
  !!attrs && ATTRIBUTE_FIELDS.some(({ key }) => attrs[key] !== null && attrs[key] !== undefined);

const normalizeAttributes = (attrs?: CharacterAttributes | null): CharacterAttributes | null => {
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

const cloneAttributes = (attrs?: CharacterAttributes | null) => {
  const normalized = normalizeAttributes(attrs);
  return normalized ? { ...normalized } : null;
};

const areAttributesEqual = (
  a?: CharacterAttributes | null,
  b?: CharacterAttributes | null,
) => {
  if (!a && !b) return true;
  if (!a || !b) return false;
  return ATTRIBUTE_FIELDS.every(({ key }) => (a[key] ?? null) === (b[key] ?? null));
};

const syncMemberFromPc = (member: Combatant, pc: Character): Combatant => {
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

const buildNewCharacter = (): Character => ({
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

const characterToCombatant = (pc: Character): Combatant => ({
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

function App() {
  const [activeTab, setActiveTab] = useState<TabKey>("characters");
  const [characters, setCharacters] = usePersistentState<Character[]>(
    "sct.characters",
    () => buildDefaultCharacters()
  );
  const [encounter, setEncounter] = usePersistentState<EncounterState>(
    "sct.encounter",
    defaultEncounterState
  );
  const [selectedPcIds, setSelectedPcIds] = useState<string[]>([]);
  const [npcDraft, setNpcDraft] = useState<NpcDraft>(buildNpcDraft);
  const [damageInputs, setDamageInputs] = useState<Record<string, number>>({});
  const [isBuilderOpen, setBuilderOpen] = useState(false);
  const [painFlash, setPainFlash] = useState<PainFlash | null>(null);
  const [editingIds, setEditingIds] = useState<Record<string, boolean>>({});

  const activeMember = encounter.members[encounter.turnIndex];

  function updateCharacter(id: string, patch: Partial<Character>) {
    setCharacters((prev) => prev.map((c) => (c.id === id ? { ...c, ...patch } : c)));
  }

  function deleteCharacter(id: string) {
    if (!window.confirm("Delete this character?")) return;
    setCharacters((prev) => prev.filter((c) => c.id !== id));
    setEncounter((prev) => ({
      ...prev,
      members: prev.members.filter((m) => m.refId !== id),
    }));
  }

  function addCharacter() {
    setCharacters((prev) => [...prev, buildNewCharacter()]);
  }

  function togglePcSelection(id: string) {
    setSelectedPcIds((prev) =>
      prev.includes(id) ? prev.filter((pcId) => pcId !== id) : [...prev, id]
    );
  }

  function addSelectedPcs() {
    if (!selectedPcIds.length) return;
    setEncounter((prev) => {
      const additions = characters
        .filter((pc) => selectedPcIds.includes(pc.id))
        .filter((pc) => !prev.members.some((m) => m.refId === pc.id))
        .map(characterToCombatant);
      if (!additions.length) return prev;
      return { ...prev, members: [...prev.members, ...additions] };
    });
    setSelectedPcIds([]);
  }

  function handleNpcDraftChange<K extends keyof NpcDraft>(field: K, value: NpcDraft[K]) {
    setNpcDraft((prev) => ({ ...prev, [field]: value }));
  }

  function handleCharacterAttributeChange(id: string, key: AttributeKey, value: string) {
    const numeric = value.trim() === '' ? null : Number(value);
    setCharacters((prev) =>
      prev.map((character) => {
        if (character.id !== id) return character;
        const next: CharacterAttributes = { ...(character.attributes ?? {}) };
        if (numeric === null || Number.isNaN(numeric)) {
          delete next[key];
        } else {
          next[key] = numeric;
        }
        return { ...character, attributes: normalizeAttributes(next) };
      })
    );
  }

  function addNpc(ev: FormEvent) {
    ev.preventDefault();
    setEncounter((prev) => ({
      ...prev,
      members: [
        ...prev.members,
        {
          id: uid("cmb"),
          source: "npc",
          name: npcDraft.name.trim() || "NPC",
          initiative: Number(npcDraft.initiative) || 0,
          toughness: Number(npcDraft.toughness) || 0,
          defense: Number(npcDraft.defense) || 0,
          armor: npcDraft.armor.trim() || "Light (d4)",
          painThreshold: npcDraft.painThreshold ?? null,
          prone: false,
          flanked: false,
          note: npcDraft.note.trim(),
        },
      ],
    }));
    setNpcDraft(buildNpcDraft());
  }

  function updateMember(id: string, patch: Partial<Combatant>) {
    setEncounter((prev) => ({
      ...prev,
      members: prev.members.map((m) => (m.id === id ? { ...m, ...patch } : m)),
    }));
  }

  function removeMember(id: string) {
    setEncounter((prev) => {
      const members = prev.members.filter((m) => m.id !== id);
      let { turnIndex, round } = prev;
      if (!members.length) {
        turnIndex = 0;
        round = 1;
      } else if (turnIndex >= members.length) {
        turnIndex = Math.max(0, members.length - 1);
      }
      return { ...prev, members, turnIndex, round };
    });
    setEditingIds((prev) => {
      if (!prev[id]) return prev;
      const next = { ...prev };
      delete next[id];
      return next;
    });
  }

  function moveMember(id: string, direction: "up" | "down") {
    setEncounter((prev) => {
      const index = prev.members.findIndex((m) => m.id === id);
      if (index === -1) return prev;
      const target = direction === "up" ? index - 1 : index + 1;
      if (target < 0 || target >= prev.members.length) return prev;
      const members = [...prev.members];
      const [item] = members.splice(index, 1);
      members.splice(target, 0, item);
      const activeId = prev.members[prev.turnIndex]?.id;
      const turnIndex = activeId
        ? Math.max(0, members.findIndex((m) => m.id === activeId))
        : 0;
      return { ...prev, members, turnIndex };
    });
  }

  function sortByInitiative() {
    setEncounter((prev) => ({
      ...prev,
      members: [...prev.members].sort((a, b) => (b.initiative || 0) - (a.initiative || 0)),
      turnIndex: prev.members.length ? 0 : 0,
      round: prev.members.length ? 1 : prev.round,
    }));
  }

  function nextTurn() {
    setEncounter((prev) => {
      if (!prev.members.length) return prev;
      const turnIndex = (prev.turnIndex + 1) % prev.members.length;
      const round = turnIndex === 0 ? prev.round + 1 : prev.round;
      return { ...prev, turnIndex, round };
    });
  }

  function prevTurn() {
    setEncounter((prev) => {
      if (!prev.members.length) return prev;
      const turnIndex = (prev.turnIndex - 1 + prev.members.length) % prev.members.length;
      const round = turnIndex === prev.members.length - 1 ? Math.max(1, prev.round - 1) : prev.round;
      return { ...prev, turnIndex, round };
    });
  }

  function clearEncounter() {
    if (!window.confirm("Clear encounter?")) return;
    setEncounter(defaultEncounterState());
    setSelectedPcIds([]);
    setDamageInputs({});
    setEditingIds({});
  }

  function handleAdjustInput(memberId: string, value: number) {
    setDamageInputs((prev) => ({ ...prev, [memberId]: value }));
  }

  function applyAdjustment(memberId: string, mode: "hurt" | "heal") {
    const amount = Math.max(0, Math.min(99, damageInputs[memberId] ?? 1));
    if (amount === 0) return;
    const triggerRef: { current: PainFlashTrigger | null } = { current: null };
    setEncounter((prev) => ({
      ...prev,
      members: prev.members.map((member) => {
        if (member.id !== memberId) return member;
        const delta = mode === "hurt" ? -amount : amount;
        const nextToughness = clamp(member.toughness + delta, 0, 999);
        const updated: Combatant = { ...member, toughness: nextToughness };
        if (mode === "hurt") {
          const threshold = member.painThreshold;
          if (threshold !== null && amount >= threshold) {
            updated.prone = true;
            triggerRef.current = { name: member.name, amount };
          }
        }
        return updated;
      }),
    }));
    if (triggerRef.current) {
      const payload = { ...triggerRef.current };
      // Defer to ensure DOM updates for encounter apply first
      window.setTimeout(() => {
        setPainFlash({ ...payload, id: Date.now() });
      }, 0);
      toast.warning(
        triggerRef.current.name +
          " takes " +
          triggerRef.current.amount +
          " damage and exceeds Pain Threshold",
        { position: "bottom-right", autoClose: 4000 }
      );
    }
  }

  useEffect(() => {
    if (!painFlash) return;
    const timer = window.setTimeout(() => setPainFlash(null), 1600);
    return () => window.clearTimeout(timer);
  }, [painFlash]);

  function toggleEditing(memberId: string) {
    setEditingIds((prev) => ({ ...prev, [memberId]: !prev[memberId] }));
  }

  useEffect(() => {
    setEncounter((prev) => {
      if (!prev.members.length) return prev;
      const byId = new Map(characters.map((pc) => [pc.id, pc]));
      let changed = false;
      const members = prev.members.map((member) => {
        if (member.source !== 'pc' || !member.refId) return member;
        const pc = byId.get(member.refId);
        if (!pc) return member;
        const synced = syncMemberFromPc(member, pc);
        if (synced !== member) changed = true;
        return synced;
      });
      return changed ? { ...prev, members } : prev;
    });
  }, [characters]);

  const roundInfo = encounter.members.length
    ? "Round " + encounter.round + " — Active: " + (activeMember?.name ?? "-")
    : "No combatants yet.";
  return (
    <div className="app-shell">
      <main>
        <nav className="tabs">
          {TAB_OPTIONS.map((tab) => (
            <button
              key={tab}
              className={"tab" + (activeTab === tab ? " active" : "")}
              onClick={() => setActiveTab(tab)}
            >
              {tab === "characters" && "Characters"}
              {tab === "encounter" && "Encounter"}
              {tab === "help" && "Help"}
            </button>
          ))}
        </nav>

        {activeTab === "characters" && (
          <section className="panel">
            <div className="panel-header">
              <h2>Player Characters</h2>
              <button onClick={addCharacter}>Add Character</button>
            </div>
            <p className="muted small">Roster lives in your browser (localStorage).</p>
            <div className="cards two-col">
              {characters.map((character) => (
                <div className="card character-card" key={character.id}>
                  <div className="card-line dual">
                    <input
                      className="name"
                      value={character.name}
                      onChange={(e) => updateCharacter(character.id, { name: e.target.value })}
                      placeholder="Name"
                    />
                    <input
                      className="role"
                      value={character.role}
                      onChange={(e) => updateCharacter(character.id, { role: e.target.value })}
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
                          updateCharacter(character.id, {
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
                          updateCharacter(character.id, {
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
                          updateCharacter(character.id, {
                            defense: Number(e.target.value) || 0,
                          })
                        }
                      />
                    </label>
                    <label>
                      <span>Armor</span>
                      <input
                        value={character.armor}
                        onChange={(e) => updateCharacter(character.id, { armor: e.target.value })}
                      />
                    </label>
                    <label>
                      <span>Pain Threshold</span>
                      <input
                        type="number"
                        value={character.painThreshold ?? ""}
                        onChange={(e) =>
                          updateCharacter(character.id, {
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
                            onChange={(e) =>
                              handleCharacterAttributeChange(character.id, key, e.target.value)
                            }
                          />
                        </label>
                      ))}
                    </div>
                  </details>
                  <textarea
                    value={character.note}
                    onChange={(e) => updateCharacter(character.id, { note: e.target.value })}
                    placeholder="Notes"
                  />
                  <div className="card-actions">
                    <button className="danger ghost" onClick={() => deleteCharacter(character.id)}>
                      Delete
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}

        {activeTab === "encounter" && (
          <section className="panel">
            <div className="panel-header">
              <h2>Initiative Order</h2>
              <div className="panel-actions wrap">
                <button onClick={() => setBuilderOpen(true)}>Manage Combatants</button>
                <button onClick={sortByInitiative}>Sort</button>
                <button onClick={prevTurn}>Prev</button>
                <button onClick={nextTurn}>Next</button>
              </div>
            </div>
            <p className="muted small">{roundInfo}</p>
            <div className="cards encounter-grid">
              {!encounter.members.length && (
                <p className="muted">Add PCs or NPCs from the Manage dialog.</p>
              )}
              {encounter.members.map((member, idx) => {
                const adjustValue = damageInputs[member.id] ?? 1;
                const isEditing = !!editingIds[member.id];
                return (
                  <div
                    key={member.id}
                    className={
                      "card encounter-card" + (idx === encounter.turnIndex ? " active" : "")
                    }
                  >
                    <div className="card-line compact-header">
                      <div className="name-wrapper">
                        <input
                          className="name"
                          value={member.name}
                          readOnly={!isEditing}
                          aria-readonly={!isEditing}
                          onChange={(e) => updateMember(member.id, { name: e.target.value })}
                        />
                      </div>
                      <div className="order-buttons">
                        <button className="icon" onClick={() => moveMember(member.id, "up")}>
                          ↑
                        </button>
                        <button className="icon" onClick={() => moveMember(member.id, "down")}>
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
                              updateMember(member.id, {
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
                              updateMember(member.id, {
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
                              updateMember(member.id, {
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
                            onChange={(e) => updateMember(member.id, { armor: e.target.value })}
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
                              updateMember(member.id, {
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
                          onChange={(e) => updateMember(member.id, { prone: e.target.checked })}
                        />
                        Prone
                      </label>
                      <label className="toggle">
                        <input
                          type="checkbox"
                          checked={member.flanked}
                          onChange={(e) => updateMember(member.id, { flanked: e.target.checked })}
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
                          max={99}
                          value={adjustValue}
                          onChange={(e) =>
                            handleAdjustInput(
                              member.id,
                              Math.max(0, Math.min(99, Number(e.target.value) || 0))
                            )
                          }
                        />
                      </label>
                      <div className="adjust-buttons">
                        <button onClick={() => applyAdjustment(member.id, "heal")}>Heal</button>
                        <button onClick={() => applyAdjustment(member.id, "hurt")}>Hurt</button>
                      </div>
                    </div>
                    <textarea
                      value={member.note || ""}
                      onChange={(e) => updateMember(member.id, { note: e.target.value })}
                      placeholder="Notes / conditions"
                    />
                    <div className="card-actions">
                      <button className="ghost" onClick={() => toggleEditing(member.id)}>
                        {isEditing ? "Done" : "Edit"}
                      </button>
                      <button className="danger ghost" onClick={() => removeMember(member.id)}>
                        Remove
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </section>
        )}

        {activeTab === "help" && (
          <section className="panel">
            <h2>Quick Help</h2>
            <ul>
              <li>Characters tab stores your standard PCs (localStorage).</li>
              <li>Encounter tab pulls PCs in, builds NPCs, and tracks initiative.</li>
              <li>Pain Threshold triggers auto-prone + warnings; amount input catches big hits.</li>
              <li>Edit per card when you need to tweak stats mid-session.</li>
            </ul>
            <p className="muted small">
              Rules reference: Symbaroum core book. Tracker simply records what you enter.
            </p>
          </section>
        )}
      </main>
      {isBuilderOpen && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal">
            <div className="modal-header">
              <h3>Manage Combatants</h3>
              <button className="icon" aria-label="Close" onClick={() => setBuilderOpen(false)}>
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
                          onChange={() => togglePcSelection(pc.id)}
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
                  <button onClick={addSelectedPcs} disabled={!selectedPcIds.length}>
                    Add Selected PCs
                  </button>
                  <button className="danger ghost" onClick={clearEncounter}>
                    Clear Encounter
                  </button>
                </div>
              </section>

              <section className="modal-section">
                <h4>Quick NPC</h4>
                <form className="inline-form labeled" onSubmit={addNpc}>
                  <label>
                    <span>Name</span>
                    <input
                      value={npcDraft.name}
                      onChange={(e) => handleNpcDraftChange("name", e.target.value)}
                      required
                    />
                  </label>
                  <label>
                    <span>Initiative</span>
                    <input
                      type="number"
                      value={npcDraft.initiative}
                      onChange={(e) => handleNpcDraftChange("initiative", Number(e.target.value) || 0)}
                      required
                    />
                  </label>
                  <label>
                    <span>Toughness</span>
                    <input
                      type="number"
                      value={npcDraft.toughness}
                      onChange={(e) => handleNpcDraftChange("toughness", Number(e.target.value) || 0)}
                      required
                    />
                  </label>
                  <label>
                    <span>Defense</span>
                    <input
                      type="number"
                      value={npcDraft.defense}
                      onChange={(e) => handleNpcDraftChange("defense", Number(e.target.value) || 0)}
                      required
                    />
                  </label>
                  <label>
                    <span>Armor</span>
                    <input
                      value={npcDraft.armor}
                      onChange={(e) => handleNpcDraftChange("armor", e.target.value)}
                    />
                  </label>
                  <label>
                    <span>Pain Threshold</span>
                    <input
                      type="number"
                      value={npcDraft.painThreshold ?? ""}
                      onChange={(e) =>
                        handleNpcDraftChange(
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
                      onChange={(e) => handleNpcDraftChange("note", e.target.value)}
                    />
                  </label>
                  <button type="submit">Add NPC</button>
                </form>
              </section>
            </div>
          </div>
        </div>
      )}

      {painFlash && (
        <div className="pain-flash" key={painFlash.id}>
          <div className="pain-flash__ring" />
          <div className="pain-flash__text">
            <span>{painFlash.name}</span>
            <small>Took {painFlash.amount} damage!</small>
          </div>
        </div>
      )}

      <ToastContainer newestOnTop closeOnClick pauseOnFocusLoss={false} theme="dark" />
    </div>
  );
}

export default App;
