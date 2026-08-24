import { useEffect, useRef, useState } from "react";
import type { FormEvent as ReactFormEvent } from "react";

type FormEvent = ReactFormEvent<HTMLFormElement>;
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import "./App.css";
import { usePersistentState } from "./hooks/usePersistentState";
import { usePersistentHistory } from "./hooks/usePersistentHistory";
import { onStorageError } from "./hooks/storage";
import { buildDefaultCharacters } from "./data/defaultCharacters";
import type {
  Character,
  Combatant,
  EncounterState,
  EncounterHistoryEntry,
  CharacterAttributes,
  AttributeKey,
  BestiaryEntry,
  MemberPatch,
} from "./types";
import { clamp, uid } from "./utils";
import { exportToFile, importFromFile } from "./utils/exportImport";
import {
  normalizeAttributes,
  syncMemberFromPc,
  buildNewCharacter,
  characterToCombatant,
} from "./utils/combatLogic";
import {
  counterKey,
  readBestiary,
  readCharacters,
  readEncounter,
} from "./utils/migrate";
import {
  applyDelta,
  exceedsPainThreshold,
  isDown,
  makeToughness,
  setCurrent,
  setMax,
} from "./utils/toughness";
import { CharactersPanel, EncounterPanel, HelpPanel, AddCombatantModal } from "./components";
import type { NpcDraft } from "./components";
import { NPC_COUNT_MIN, NPC_COUNT_MAX } from "./utils/npcConstants";
import type { MonsterPreset } from "./data/defaultMonsters";

const TAB_OPTIONS = ["characters", "encounter", "help"] as const;
type TabKey = (typeof TAB_OPTIONS)[number];

type PainFlash = {
  name: string;
  amount: number;
  id: string;
};

const defaultEncounterState = (): EncounterState => ({
  members: [],
  turnIndex: 0,
  round: 1,
  nameCounter: {},
});

const buildNpcDraft = (): NpcDraft => ({
  monsterType: "",
  name: "",
  count: 1,
  initiative: 0,
  toughness: 10,
  defense: 10,
  armor: "Light (d4)",
  painThreshold: null,
  note: "",
  attributes: null,
});

/** What happened during an adjustment, decided outside the state updater. */
type AdjustEvent =
  | { kind: "pain"; name: string; amount: number }
  | { kind: "down"; name: string };

function applyMemberPatch(member: Combatant, patch: MemberPatch): Combatant {
  switch (patch.field) {
    case "name":
      return { ...member, name: patch.value };
    case "initiative":
      return { ...member, initiative: clamp(patch.value, 0, 99) };
    case "toughnessCurrent":
      return { ...member, toughness: setCurrent(member.toughness, patch.value) };
    case "toughnessMax":
      return { ...member, toughness: setMax(member.toughness, patch.value) };
    case "defense":
      return { ...member, defense: patch.value };
    case "armor":
      return { ...member, armor: patch.value };
    case "painThreshold":
      return { ...member, painThreshold: patch.value };
    case "prone":
      return { ...member, prone: patch.value };
    case "flanked":
      return { ...member, flanked: patch.value };
    case "note":
      return { ...member, note: patch.value };
  }
}

/** Toggles are single clicks and each deserves its own undo entry. */
const coalesceKeyFor = (id: string, patch: MemberPatch): string | null =>
  patch.field === "prone" || patch.field === "flanked" ? null : `${patch.field}:${id}`;

function App() {
  const [activeTab, setActiveTab] = useState<TabKey>("characters");
  const [characters, setCharacters] = usePersistentState<Character[]>(
    "sct.characters",
    () => buildDefaultCharacters(),
    (raw) => readCharacters(raw)
  );
  const [bestiary, setBestiary] = usePersistentState<BestiaryEntry[]>(
    "sct.bestiary",
    () => [],
    (raw) => readBestiary(raw)
  );
  // Declared after the two above so the migration can recover each combatant's
  // maximum toughness from the roster entry or bestiary template it came from --
  // v1 stored a single number and the maximum was simply gone.
  const [encounter, setEncounter, { undo, redo, canUndo, canRedo }] = usePersistentHistory<EncounterState>(
    "sct.encounter",
    defaultEncounterState,
    (raw) => readEncounter(raw, { characters, bestiary }).encounter
  );
  const [selectedPcIds, setSelectedPcIds] = useState<string[]>([]);
  const [npcDraft, setNpcDraft] = useState<NpcDraft>(buildNpcDraft);
  const [damageInputs, setDamageInputs] = useState<Record<string, number>>({});
  const [isBuilderOpen, setBuilderOpen] = useState(false);
  const [painFlash, setPainFlash] = useState<PainFlash | null>(null);
  const [editingIds, setEditingIds] = useState<Record<string, boolean>>({});
  const [theme, setTheme] = usePersistentState<"light" | "dark">(
    "sct.theme",
    () => "light",
    (raw) => (raw === "dark" ? "dark" : "light")
  );
  // Every persisted key needs a v1 reader, including this one: without it the
  // v2 key is missing, the v1 key is skipped, and a shelf of archived encounters
  // silently becomes an empty list.
  const [encounterHistory, setEncounterHistory] = usePersistentState<EncounterHistoryEntry[]>(
    "sct.encounterHistory",
    () => [],
    (raw) =>
      (Array.isArray(raw) ? raw : []).map((entry) => {
        const e = (entry ?? {}) as Partial<EncounterHistoryEntry>;
        return {
          id: typeof e.id === "string" ? e.id : uid("hist"),
          timestamp: typeof e.timestamp === "number" ? e.timestamp : Date.now(),
          label: typeof e.label === "string" ? e.label : "Archived encounter",
          encounter: readEncounter(e.encounter, { characters, bestiary }).encounter,
        };
      })
  );

  const MAX_HISTORY_ENTRIES = 10;

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
  }, [theme]);

  // A failed write used to be a console.warn, so a full localStorage meant the
  // session quietly stopped saving. Say it once, out loud.
  const storageWarned = useRef(false);
  useEffect(() => {
    onStorageError((key, err) => {
      console.warn("Failed to write localStorage key " + key, err);
      if (storageWarned.current) return;
      storageWarned.current = true;
      toast.error(
        "Browser storage is full — changes are no longer being saved. Export your data.",
        { position: "bottom-right", autoClose: false }
      );
    });
    return () => onStorageError(null);
  }, []);

  // Round change detection for recap
  const prevRoundRef = useRef(encounter.round);
  useEffect(() => {
    if (encounter.round > prevRoundRef.current && encounter.members.length > 0) {
      const standing = encounter.members.filter((m) => !isDown(m.toughness)).length;
      const down = encounter.members.length - standing;
      const summary = down > 0
        ? `Round ${prevRoundRef.current} complete — ${standing} standing, ${down} down`
        : `Round ${prevRoundRef.current} complete — All ${standing} combatants standing`;
      toast.info(summary, { position: "bottom-right", autoClose: 3000 });
    }
    prevRoundRef.current = encounter.round;
  }, [encounter.round, encounter.members]);

  function toggleTheme() {
    setTheme((prev) => (prev === "light" ? "dark" : "light"));
  }

  function updateCharacter(id: string, patch: Partial<Character>) {
    setCharacters((prev) => prev.map((c) => (c.id === id ? { ...c, ...patch } : c)));
  }

  /**
   * Removing members without repairing the cursor left `turnIndex` pointing at a
   * different combatant, or past the end of the array with nothing highlighted.
   * Keep whoever was active if they survived; otherwise clamp into range.
   */
  function withRepairedCursor(prev: EncounterState, members: Combatant[]): EncounterState {
    const activeId = prev.members[prev.turnIndex]?.id;
    let turnIndex = 0;
    if (members.length) {
      const stillThere = members.findIndex((m) => m.id === activeId);
      turnIndex = stillThere >= 0 ? stillThere : clamp(prev.turnIndex, 0, members.length - 1);
    }
    return { ...prev, members, turnIndex, round: members.length ? prev.round : 1 };
  }

  function deleteCharacter(id: string) {
    if (!window.confirm("Delete this character?")) return;
    setCharacters((prev) => prev.filter((c) => c.id !== id));
    setEncounter((prev) =>
      withRepairedCursor(
        prev,
        prev.members.filter((m) => m.refId !== id)
      )
    );
  }

  function addCharacter() {
    setCharacters((prev) => [...prev, buildNewCharacter()]);
  }

  function handleExport() {
    exportToFile(characters, encounter, bestiary);
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
    setBestiary(result.data.bestiary ?? []);
    // Repairs used to be silent, which makes an accepted file and a corrected
    // one look identical.
    if (result.corrections.length) {
      toast.info(
        `Imported with ${result.corrections.length} correction(s): ` +
          result.corrections.slice(0, 3).join(" "),
        { position: "bottom-right", autoClose: 8000 }
      );
      result.corrections.forEach((c) => console.info("Import correction: " + c));
    } else {
      toast.success("Data imported", { position: "bottom-right", autoClose: 2000 });
    }
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

  function loadBestiaryEntry(entry: BestiaryEntry) {
    setNpcDraft({
      monsterType: entry.monsterType,
      name: "",
      count: 1,
      initiative: entry.initiative,
      toughness: entry.toughness,
      defense: entry.defense,
      armor: entry.armor,
      painThreshold: entry.painThreshold,
      note: entry.note,
      attributes: entry.attributes ?? null,
    });
  }

  function deleteBestiaryEntry(id: string) {
    setBestiary((prev) => prev.filter((e) => e.id !== id));
  }

  function handleLoadPreset(preset: MonsterPreset) {
    setNpcDraft({
      monsterType: preset.name,
      name: "",
      count: 1,
      initiative: preset.attributes.qui ?? 0,
      // A statblock prints the *modifier* an attacker applies; a character sheet
      // prints the roll-under target. Convert here so that every `defense` in the
      // app afterwards is the same quantity -- the number you roll under.
      defense: preset.defense === null ? 10 : clamp(10 - preset.defense, 1, 20),
      toughness: preset.toughness ?? 10,
      armor: preset.armor ?? '',
      painThreshold: preset.painThreshold,
      note: "",
      attributes: preset.attributes,
    });
  }

  function addNpc(ev: FormEvent) {
    ev.preventDefault();
    const count = Math.max(NPC_COUNT_MIN, Math.min(NPC_COUNT_MAX, npcDraft.count));
    const monsterType = npcDraft.monsterType.trim();
    const baseName = npcDraft.name.trim();
    const attributes = normalizeAttributes(npcDraft.attributes);

    setEncounter((prev) => {
      const key = counterKey(monsterType);
      // A high-water mark, not a head count. Counting live members meant that
      // removing Goblin 2 and adding one more produced a second Goblin 3.
      const start = prev.nameCounter[key] ?? 0;

      const newMembers: Combatant[] = [];
      for (let i = 0; i < count; i++) {
        const name = baseName
          ? (count > 1 ? `${baseName} ${i + 1}` : baseName)
          : `${key} ${start + i + 1}`;
        newMembers.push({
          id: uid("cmb"),
          source: "npc",
          monsterType: monsterType || undefined,
          name,
          initiative: Number(npcDraft.initiative) || 0,
          toughness: makeToughness(npcDraft.toughness, npcDraft.toughness),
          defense: Number(npcDraft.defense) || 0,
          armor: npcDraft.armor.trim() || "Light (d4)",
          painThreshold: npcDraft.painThreshold ?? null,
          prone: false,
          flanked: false,
          note: npcDraft.note.trim(),
          // Was omitted entirely, so a preset's statblock was dropped on the way
          // into the fight.
          attributes,
        });
      }
      const nameCounter = baseName
        ? prev.nameCounter
        : { ...prev.nameCounter, [key]: start + count };
      return { ...prev, members: [...prev.members, ...newMembers], nameCounter };
    });

    if (monsterType) {
      setBestiary((prev) => {
        const existing = prev.find((e) => e.monsterType === monsterType);
        const entry: BestiaryEntry = {
          id: existing ? existing.id : uid("bst"),
          monsterType,
          initiative: Number(npcDraft.initiative) || 0,
          toughness: makeToughness(npcDraft.toughness, npcDraft.toughness).max,
          defense: Number(npcDraft.defense) || 0,
          armor: npcDraft.armor.trim() || "Light (d4)",
          painThreshold: npcDraft.painThreshold ?? null,
          note: npcDraft.note.trim(),
          attributes,
          updatedAt: Date.now(),
        };
        if (existing) {
          return prev.map((e) => (e.id === existing.id ? entry : e));
        }
        return [...prev, entry];
      });
    }

    setNpcDraft(buildNpcDraft());
  }

  function updateMember(id: string, patch: MemberPatch) {
    setEncounter(
      (prev) => ({
        ...prev,
        members: prev.members.map((m) => (m.id === id ? applyMemberPatch(m, patch) : m)),
      }),
      { coalesce: coalesceKeyFor(id, patch) }
    );
  }

  function removeMember(id: string) {
    setEncounter((prev) =>
      withRepairedCursor(
        prev,
        prev.members.filter((m) => m.id !== id)
      )
    );
    setEditingIds((prev) => {
      if (!prev[id]) return prev;
      const next = { ...prev };
      delete next[id];
      return next;
    });
    // Used to be pruned only for editingIds, so this map grew an entry for every
    // combatant that had ever existed.
    setDamageInputs((prev) => {
      if (!(id in prev)) return prev;
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
      turnIndex: 0,
      // `round` is deliberately untouched. Sorting in round 5 used to put you
      // back in round 1 with no warning.
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
    // Save to history if there were members
    if (encounter.members.length > 0) {
      const pcs = encounter.members.filter((m) => m.source === "pc").length;
      const npcs = encounter.members.filter((m) => m.source === "npc").length;
      const label = `Round ${encounter.round} — ${pcs} PC${pcs !== 1 ? "s" : ""}, ${npcs} NPC${npcs !== 1 ? "s" : ""}`;
      const entry: EncounterHistoryEntry = {
        id: uid("hist"),
        timestamp: Date.now(),
        label,
        encounter: { ...encounter },
      };
      setEncounterHistory((prev) => [entry, ...prev].slice(0, MAX_HISTORY_ENTRIES));
    }
    setEncounter(defaultEncounterState());
    setSelectedPcIds([]);
    setDamageInputs({});
    setEditingIds({});
  }

  function restoreEncounter(entry: EncounterHistoryEntry) {
    if (!window.confirm("Restore this encounter? Current encounter will be cleared.")) return;
    // Archived encounters predate the counter and the cursor repair, so they go
    // through the same reader an imported file does.
    setEncounter(readEncounter(entry.encounter, { characters, bestiary }).encounter);
    setBuilderOpen(false);
    toast.success("Encounter restored", { position: "bottom-right", autoClose: 2000 });
  }

  function deleteHistoryEntry(id: string) {
    setEncounterHistory((prev) => prev.filter((e) => e.id !== id));
  }

  function handleAdjustInput(memberId: string, value: number) {
    setDamageInputs((prev) => ({ ...prev, [memberId]: value }));
  }

  /**
   * Work out the new state *and* what happened, then act on both.
   *
   * This used to declare a mutable ref, write to it from inside the `setEncounter`
   * updater, read it afterwards and flush through `setTimeout(…, 0)` to dodge a
   * batching problem. React may call an updater twice, so that fired the toast
   * twice in StrictMode. Nothing here writes to anything outside itself.
   */
  function applyAdjustment(memberId: string, mode: "hurt" | "heal") {
    const amount = clamp(damageInputs[memberId] ?? 1, 0, 999);
    if (amount === 0) return;

    const member = encounter.members.find((m) => m.id === memberId);
    if (!member) return;

    const delta = mode === "hurt" ? -amount : amount;

    // What one blow does to one combatant. Pure, so the updater below can call
    // it on whatever `prev` really is -- two quick clicks both land.
    const resolve = (m: Combatant) => {
      const { next, dealt } = applyDelta(m.toughness, delta);
      // Against the damage that actually landed, not the number in the box: a
      // combatant on 2 hit for 20 takes 2, and being reduced to zero is *down*
      // rather than prone.
      const proned =
        mode === "hurt" && next.current > 0 && exceedsPainThreshold(m.painThreshold, dealt);
      const prone = mode === "heal" ? false : m.prone || proned;
      return { next, dealt, prone, proned, downed: next.current === 0 && m.toughness.current > 0 };
    };

    const preview = resolve(member);
    if (preview.dealt === 0 && mode === "hurt") return;
    if (mode === "heal" && preview.next.current === member.toughness.current && !member.prone) return;

    setEncounter((prev) => ({
      ...prev,
      members: prev.members.map((m) => {
        if (m.id !== memberId) return m;
        const { next, prone } = resolve(m);
        return { ...m, toughness: next, prone };
      }),
    }));

    const events: AdjustEvent[] = [];
    if (preview.proned) events.push({ kind: "pain", name: member.name, amount: preview.dealt });
    if (preview.downed) events.push({ kind: "down", name: member.name });

    for (const event of events) {
      if (event.kind === "pain") {
        setPainFlash({ name: event.name, amount: event.amount, id: uid("flash") });
        toast.warning(
          `${event.name} takes ${event.amount} damage and exceeds Pain Threshold`,
          { position: "bottom-right", autoClose: 4000 }
        );
      } else {
        toast.error(`${event.name} is down`, { position: "bottom-right", autoClose: 4000 });
      }
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
  }, [characters, setEncounter]);

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
            {theme === "light" ? "☾" : "☀"}
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
            canUndo={canUndo}
            canRedo={canRedo}
            onOpenBuilder={openBuilder}
            onSort={sortByInitiative}
            onPrevTurn={prevTurn}
            onNextTurn={nextTurn}
            onUndo={undo}
            onRedo={redo}
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
          bestiary={bestiary}
          encounterHistory={encounterHistory}
          onClose={() => setBuilderOpen(false)}
          onTogglePcSelection={togglePcSelection}
          onAddSelectedPcs={addSelectedPcs}
          onClearEncounter={clearEncounter}
          onNpcDraftChange={handleNpcDraftChange}
          onAddNpc={addNpc}
          onLoadPreset={handleLoadPreset}
          onLoadBestiaryEntry={loadBestiaryEntry}
          onDeleteBestiaryEntry={deleteBestiaryEntry}
          onRestoreEncounter={restoreEncounter}
          onDeleteHistoryEntry={deleteHistoryEntry}
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
