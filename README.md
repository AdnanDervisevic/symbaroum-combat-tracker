# Symbaroum Combat Tracker

**🎲 [Play it now → symbaroum-combat-tracker.vercel.app](https://symbaroum-combat-tracker.vercel.app/)**

A browser-based initiative and combat tracker built for [Symbaroum](https://frialigan.se/en/games/symbaroum/) game masters and players. Bring it to the table on any device — no installation, no account, no internet connection required after the first load. Your characters, encounters, and bestiary are stored directly in your browser so your data is always there when you sit down to play.

## Features

- **Character Roster** — Create and manage player characters with full Symbaroum attributes (Accuracy, Cunning, Discretion, Perception, Quickness, Resolve, Strength, Vigilance), toughness, defense, armor, and Pain Threshold.
- **Initiative Tracker** — Add PCs and NPCs to an encounter, sort by initiative, and step through turns round by round.
- **Damage & Healing** — Apply damage or healing to any combatant. Pain Threshold violations automatically trigger the Prone condition (and a visual flash alert).
- **Status Conditions** — Track Prone and Flanked states per combatant; Prone clears automatically on healing.
- **NPC Management** — Quickly add one or more NPCs with custom stats; monster types are numbered automatically.
- **Bestiary** — Monster types you add are saved and can be reloaded in future encounters without re-entering stats.
- **Monster Presets** — Browse built-in Symbaroum monster presets to populate NPC stats with one click.
- **Undo / Redo** — Full undo/redo history for the encounter state, persisted across page reloads.
- **Encounter History** — Cleared encounters are saved (up to 10) and can be restored from the Manage Combatants modal.
- **Encounter Difficulty** — Automatic difficulty rating (Trivial → Overwhelming) based on PC vs. NPC toughness, numbers, and defense.
- **Round Recap** — Toast notification on round transition showing how many combatants are still standing.
- **Export / Import** — Save your entire session (characters, encounter, bestiary) to a JSON file and reload it later.
- **Dark / Light Theme** — Toggle between themes; preference is saved in localStorage.
- **Persistent State** — All data (characters, encounter, bestiary, theme) survives page refreshes via versioned localStorage keys.

## Getting Started

```bash
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) in your browser.

### Other Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start the development server with HMR |
| `npm run build` | Type-check and build for production |
| `npm run preview` | Preview the production build locally |
| `npm run lint` | Run ESLint |

## Tech Stack

- [React 19](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/)
- [Vite](https://vite.dev/) — build tooling & dev server
- [react-toastify](https://fkhadra.github.io/react-toastify/) — toast notifications

## Project Structure

```
src/
  components/       # UI panels, cards, and modals
  data/             # Default characters and monster presets
  hooks/            # usePersistentState, usePersistentHistory
  utils/            # Combat logic, export/import, helpers
  types.ts          # Shared TypeScript types
  App.tsx           # Root orchestration component
```

