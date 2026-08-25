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
  EncounterState,
  EncounterHistoryEntry,
  CharacterAttributes,
  AttributeKey,
  BestiaryEntry,
  MemberPatch,
  NpcDraft,
} from "./types";
import { clamp, uid } from "./utils/core";
import { exportToFile, importFromFile } from "./utils/exportImport";
import { normalizeAttributes, buildNewCharacter } from "./utils/combatLogic";
import { readBestiary, readCharacters, readEncounter } from "./utils/migrate";
import { isDown, makeToughness } from "./utils/toughness";
import * as Encounter from "./utils/encounter";
import { CharactersPanel, EncounterPanel, HelpPanel, AddCombatantModal } from "./components";
import type { MonsterPreset } from "./data/defaultMonsters";

/**
 * Wiring.
 *
 * Every decision about what an encounter *becomes* lives in `utils/encounter.ts`
 * as a pure function; this file decides when those run, and owns the things that
 * are genuinely about being an app — persistence, toasts, which tab is open.
 * That split is what lets the transitions be tested without a renderer.
 */

const TAB_OPTIONS = ["characters", "encounter", "help"] as const;
type TabKey = (typeof TAB_OPTIONS)[number];

type PainFlash = {
  name: string;
  amount: number;
  id: string;
};

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
  // version 1 stored a single number and the maximum was simply gone.
  const [encounter, setEncounter, { undo, redo, canUndo, canRedo }] = usePersistentHistory<EncounterState>(
    "sct.encounter",
    Encounter.emptyEncounter,
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
  // Every persisted key needs a version-1 reader, including this one: without it
  // the v2 key is missing, the v1 key is skipped, and a shelf of archived
  // encounters silently becomes an empty list.
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

  function deleteCharacter(id: string) {
    if (!window.confirm("Delete this character?")) return;
    setCharacters((prev) => prev.filter((c) => c.id !== id));
    setEncounter((prev) => Encounter.removeMembersOfCharacter(prev, id));
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
    const chosen = characters.filter((pc) => selectedPcIds.includes(pc.id));
    setEncounter((prev) => Encounter.addPlayerCharacters(prev, chosen));
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
      // prints the roll-under target. Convert here so that every `defense` in
      // the app afterwards is the same quantity -- the number you roll under.
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
    setEncounter((prev) => Encounter.addNpcs(prev, npcDraft));

    const monsterType = npcDraft.monsterType.trim();
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
          attributes: normalizeAttributes(npcDraft.attributes),
          updatedAt: Date.now(),
        };
        return existing ? prev.map((e) => (e.id === existing.id ? entry : e)) : [...prev, entry];
      });
    }

    setNpcDraft(buildNpcDraft());
  }

  function updateMember(id: string, patch: MemberPatch) {
    setEncounter((prev) => Encounter.patchMember(prev, id, patch), {
      coalesce: Encounter.coalesceKeyFor(id, patch),
    });
  }

  function removeMember(id: string) {
    setEncounter((prev) => Encounter.removeMember(prev, id));
    // Both maps used to be pruned only here and only for editingIds, so
    // damageInputs grew an entry for every combatant that had ever existed.
    const forget = (prev: Record<string, unknown>) => {
      if (!(id in prev)) return prev;
      const next = { ...prev };
      delete next[id];
      return next;
    };
    setEditingIds((prev) => forget(prev) as Record<string, boolean>);
    setDamageInputs((prev) => forget(prev) as Record<string, number>);
  }

  function moveMember(id: string, direction: "up" | "down") {
    setEncounter((prev) => Encounter.moveMember(prev, id, direction));
  }

  function sortByInitiative() {
    setEncounter(Encounter.sortByInitiative);
  }

  function nextTurn() {
    setEncounter(Encounter.nextTurn);
  }

  function prevTurn() {
    setEncounter(Encounter.prevTurn);
  }

  function clearEncounter() {
    if (!window.confirm("Clear encounter?")) return;
    if (encounter.members.length > 0) {
      const pcs = encounter.members.filter((m) => m.source === "pc").length;
      const npcs = encounter.members.filter((m) => m.source === "npc").length;
      const label = `Round ${encounter.round} — ${pcs} PC${pcs !== 1 ? "s" : ""}, ${npcs} NPC${npcs !== 1 ? "s" : ""}`;
      const entry: EncounterHistoryEntry = {
        id: uid("hist"),
        timestamp: Date.now(),
        label,
        encounter,
      };
      setEncounterHistory((prev) => [entry, ...prev].slice(0, MAX_HISTORY_ENTRIES));
    }
    setEncounter(Encounter.emptyEncounter());
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
   * Apply the blow, then announce what it did.
   *
   * This used to declare a mutable ref, write to it from inside the
   * `setEncounter` updater, read it afterwards and flush through
   * `setTimeout(…, 0)` to dodge a batching problem. The updater is a pure
   * function of `prev` now -- so two quick clicks both land -- and the events
   * are worked out separately from the state this render can see.
   */
  function applyAdjustment(memberId: string, mode: Encounter.AdjustMode) {
    const amount = clamp(damageInputs[memberId] ?? 1, 0, 999);
    const member = encounter.members.find((m) => m.id === memberId);
    if (!member) return;

    const events = Encounter.adjustmentEvents(member, mode, amount);
    setEncounter((prev) => Encounter.adjust(prev, memberId, mode, amount));

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

  // Mirror roster edits into the combatants that came from them.
  //
  // This writes through the history-recording setter, so without a coalescing
  // key it is the per-keystroke undo bug again by a side door: renaming a
  // character who is in the fight would push one encounter entry per letter. A
  // shared key collapses a run of roster edits into one, which is the right
  // grain anyway -- these are consequences of an edit, not edits.
  useEffect(() => {
    setEncounter((prev) => Encounter.syncFromRoster(prev, characters), {
      coalesce: "roster-sync",
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
