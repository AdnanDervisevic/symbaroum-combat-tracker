import { useEffect, useState } from "react";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import "./App.css";
import { useStoredSession } from "./hooks/useStoredSession";
import { useRowState } from "./hooks/useRowState";
import { useRoster } from "./hooks/useRoster";
import { useCombatantBuilder } from "./hooks/useCombatantBuilder";
import { useEncounterCommands } from "./hooks/useEncounterCommands";
import { usePainFlash, useRoundRecap, useStorageAlert } from "./hooks/useAlerts";
import { exportToFile, importFromFile } from "./utils/exportImport";
import { CharactersPanel, EncounterPanel, HelpPanel, AddCombatantModal } from "./components";

/**
 * Composition.
 *
 * What an encounter *becomes* is in `utils/encounter.ts`, as pure functions.
 * *When* those run is in the hooks below, one per area of the app. What is left
 * here is which tab is open, moving data between a file and the session, and the
 * markup -- which is what a root component should be.
 */

const TAB_OPTIONS = ["characters", "encounter", "help"] as const;
type TabKey = (typeof TAB_OPTIONS)[number];

const TAB_LABELS: Record<TabKey, string> = {
  characters: "Characters",
  encounter: "Encounter",
  help: "Help",
};

const BOTTOM_RIGHT = { position: "bottom-right" } as const;

function App() {
  const [activeTab, setActiveTab] = useState<TabKey>("characters");

  const session = useStoredSession();
  const rows = useRowState();
  const roster = useRoster(session);
  const builder = useCombatantBuilder(session);
  const { painFlash, flash } = usePainFlash();
  const commands = useEncounterCommands(session, rows, flash);

  useStorageAlert();
  useRoundRecap(session.encounter);

  const { characters, bestiary, encounter, theme, setTheme } = session;

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
  }, [theme]);

  function handleExport() {
    exportToFile(characters, encounter, bestiary);
    toast.success("Data exported", { ...BOTTOM_RIGHT, autoClose: 2000 });
  }

  async function handleImport() {
    const result = await importFromFile();
    if (!result.success) {
      if (result.error !== "Import cancelled") toast.error(result.error, BOTTOM_RIGHT);
      return;
    }
    if (!window.confirm("This will replace all current data. Continue?")) return;

    session.setCharacters(result.data.characters);
    session.setEncounter(result.data.encounter);
    session.setBestiary(result.data.bestiary ?? []);

    // Repairs used to be silent, which makes an accepted file and a corrected
    // one look identical from the outside.
    if (result.corrections.length) {
      toast.info(
        `Imported with ${result.corrections.length} correction(s): ` +
          result.corrections.slice(0, 3).join(" "),
        { ...BOTTOM_RIGHT, autoClose: 8000 }
      );
      result.corrections.forEach((c) => console.info("Import correction: " + c));
    } else {
      toast.success("Data imported", { ...BOTTOM_RIGHT, autoClose: 2000 });
    }
  }

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
              {TAB_LABELS[tab]}
            </button>
          ))}
          <button
            className="theme-toggle"
            onClick={() => setTheme((prev) => (prev === "light" ? "dark" : "light"))}
            title="Toggle theme"
          >
            {theme === "light" ? "☾" : "☀"}
          </button>
        </nav>

        {activeTab === "characters" && (
          <CharactersPanel
            characters={characters}
            onUpdate={roster.update}
            onDelete={roster.remove}
            onAdd={roster.add}
            onAttributeChange={roster.changeAttribute}
            onExport={handleExport}
            onImport={handleImport}
          />
        )}

        {activeTab === "encounter" && (
          <EncounterPanel
            encounter={encounter}
            damageInputs={rows.damageInputs}
            editingIds={rows.editingIds}
            canUndo={session.canUndo}
            canRedo={session.canRedo}
            onOpenBuilder={builder.open}
            onSort={commands.sort}
            onPrevTurn={commands.previous}
            onNextTurn={commands.next}
            onUndo={session.undo}
            onRedo={session.redo}
            onUpdateMember={commands.patch}
            onRemoveMember={commands.remove}
            onMoveMember={commands.move}
            onToggleEditing={rows.toggleEditing}
            onAdjustInput={rows.setDamageInput}
            onApplyAdjustment={commands.adjust}
          />
        )}

        {activeTab === "help" && <HelpPanel />}
      </main>

      {builder.isOpen && (
        <AddCombatantModal
          characters={characters}
          encounter={encounter}
          selectedPcIds={builder.selectedPcIds}
          npcDraft={builder.draft}
          bestiary={bestiary}
          encounterHistory={session.encounterHistory}
          onClose={builder.close}
          onTogglePcSelection={builder.togglePc}
          onAddSelectedPcs={builder.addSelectedPcs}
          onClearEncounter={commands.clear}
          onNpcDraftChange={builder.changeDraft}
          onAddNpc={builder.submit}
          onLoadPreset={builder.loadPreset}
          onLoadBestiaryEntry={builder.loadBestiaryEntry}
          onDeleteBestiaryEntry={builder.deleteBestiaryEntry}
          onRestoreEncounter={(entry) => {
            if (commands.restore(entry)) builder.close();
          }}
          onDeleteHistoryEntry={commands.deleteArchived}
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
