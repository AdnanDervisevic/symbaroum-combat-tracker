import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import "./App.css";
import { usePersistentState } from "./hooks/usePersistentState";
import { buildDefaultCharacters } from "./data/defaultCharacters";
import type { Character, Combatant, EncounterState, CharacterAttributes, AttributeKey } from "./types";
import { clamp, uid } from "./utils";
import { exportToFile, importFromFile } from "./utils/exportImport";
import {
  normalizeAttributes,
  syncMemberFromPc,
  buildNewCharacter,
  characterToCombatant,
} from "./utils/combatLogic";
import { CharactersPanel, EncounterPanel, HelpPanel, AddCombatantModal } from "./components";
import type { NpcDraft } from "./components";

const TAB_OPTIONS = ["characters", "encounter", "help"] as const;
type TabKey = (typeof TAB_OPTIONS)[number];

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
  const [theme, setTheme] = usePersistentState<"light" | "dark">("sct.theme", () => "light");

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
  }, [theme]);

  function toggleTheme() {
    setTheme((prev) => (prev === "light" ? "dark" : "light"));
  }

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

  function handleExport() {
    exportToFile(characters, encounter);
    toast.success("Data exported", { position: "bottom-right", autoClose: 2000 });
  }

  async function handleImport() {
    const result = await importFromFile();
    if (!result.success) {
      if (result.error !== "Import cancelled") {
        toast.error(result.error, { position: "bottom-right" });
      }
      return;
    }
    if (!window.confirm("This will replace all current data. Continue?")) return;
    setCharacters(result.data.characters);
    setEncounter(result.data.encounter);
    toast.success("Data imported", { position: "bottom-right", autoClose: 2000 });
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

  function openBuilder() {
    // Pre-select all PCs that aren't already in the encounter
    const availablePcIds = characters
      .filter((pc) => !encounter.members.some((m) => m.refId === pc.id))
      .map((pc) => pc.id);
    setSelectedPcIds(availablePcIds);
    setBuilderOpen(true);
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
      const activeId = prev.members[prev.turnIndex]?.id;
      const members = prev.members.filter((m) => m.id !== id);
      let { turnIndex, round } = prev;
      if (!members.length) {
        turnIndex = 0;
        round = 1;
      } else if (activeId === id) {
        turnIndex = Math.min(turnIndex, members.length - 1);
      } else {
        turnIndex = Math.max(0, members.findIndex((m) => m.id === activeId));
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
    const amount = Math.max(0, Math.min(999, damageInputs[memberId] ?? 1));
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
        } else if (mode === "heal" && member.prone) {
          updated.prone = false;
        }
        return updated;
      }),
    }));
    if (triggerRef.current) {
      const payload = { ...triggerRef.current };
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
          <button className="theme-toggle" onClick={toggleTheme} title="Toggle theme">
            {theme === "light" ? "\u263E" : "\u2600"}
          </button>
        </nav>

        {activeTab === "characters" && (
          <CharactersPanel
            characters={characters}
            onUpdate={updateCharacter}
            onDelete={deleteCharacter}
            onAdd={addCharacter}
            onAttributeChange={handleCharacterAttributeChange}
            onExport={handleExport}
            onImport={handleImport}
          />
        )}

        {activeTab === "encounter" && (
          <EncounterPanel
            encounter={encounter}
            damageInputs={damageInputs}
            editingIds={editingIds}
            onOpenBuilder={openBuilder}
            onSort={sortByInitiative}
            onPrevTurn={prevTurn}
            onNextTurn={nextTurn}
            onUpdateMember={updateMember}
            onRemoveMember={removeMember}
            onMoveMember={moveMember}
            onToggleEditing={toggleEditing}
            onAdjustInput={handleAdjustInput}
            onApplyAdjustment={applyAdjustment}
          />
        )}

        {activeTab === "help" && <HelpPanel />}
      </main>

      {isBuilderOpen && (
        <AddCombatantModal
          characters={characters}
          encounter={encounter}
          selectedPcIds={selectedPcIds}
          npcDraft={npcDraft}
          onClose={() => setBuilderOpen(false)}
          onTogglePcSelection={togglePcSelection}
          onAddSelectedPcs={addSelectedPcs}
          onClearEncounter={clearEncounter}
          onNpcDraftChange={handleNpcDraftChange}
          onAddNpc={addNpc}
        />
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
