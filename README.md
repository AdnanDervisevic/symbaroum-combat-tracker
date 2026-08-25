# Symbaroum Combat Tracker

**🎲 [Use it at your table → symbaroum-combat-tracker.vercel.app](https://symbaroum-combat-tracker.vercel.app/)**

A browser-based initiative and combat tracker built for [Symbaroum](https://frialigan.se/en/games/symbaroum/) game masters and players. Bring it to the table on any device — no installation, no account, no internet connection required after the first load. Your characters, encounters, and bestiary are stored directly in your browser so your data is always there when you sit down to play.

## Features

- **Character Roster** — Create and manage player characters with full Symbaroum attributes (Accuracy, Cunning, Discretion, Perception, Quickness, Resolve, Strength, Vigilance), toughness, defense, armor, and Pain Threshold. Defense is the roll-under target from the sheet; monster presets print the attacker's modifier instead and are converted when you load one.
- **Initiative Tracker** — Add PCs and NPCs to an encounter, sort by initiative, and step through turns round by round.
- **Damage & Healing** — Apply damage or healing to any combatant; toughness is tracked as current out of maximum. The Pain Threshold is measured against the damage that actually landed, so a killing blow reports the combatant as down rather than merely winded. Blank means the creature never goes prone; `0` means every hit does.
- **Status Conditions** — Track Prone and Flanked states per combatant; Prone clears automatically on healing.
- **NPC Management** — Quickly add one or more NPCs with custom stats; monster types are numbered automatically.
- **Bestiary** — Monster types you add are saved and can be reloaded in future encounters without re-entering stats.
- **Monster Presets** — Browse built-in Symbaroum monster presets to populate NPC stats with one click.
- **Undo / Redo** — Full undo/redo history for the encounter state. A run of edits to one field collapses into a single entry, so typing a note costs one undo rather than fifty.
- **Encounter History** — Cleared encounters are saved (up to 10) and can be restored from the Manage Combatants modal.
- **Encounter Summary** — What each side actually brings: how many combatants, how many still standing, and their combined toughness. There is deliberately no difficulty rating; see [Design notes](#design-notes).
- **Round Recap** — Toast notification on round transition showing how many combatants are still standing.
- **Export / Import** — Save your entire session (characters, encounter, bestiary) to a JSON file and reload it later. Files are read by version; anything out of range is repaired on the way in and the repairs are reported rather than applied silently.
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
| `npm test` | Run the test suite once |
| `npm run test:watch` | Run the tests in watch mode |
| `npm run check` | Types, lint, tests, build — everything, in that order |
| `npm run build` | Type-check and build for production |
| `npm run preview` | Preview the production build locally |
| `npm run lint` | Run ESLint |

## Tech Stack

- [React 19](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/)
- [Vite](https://vite.dev/) — build tooling & dev server
- [Vitest](https://vitest.dev/) — tests
- [react-toastify](https://fkhadra.github.io/react-toastify/) — toast notifications

## Project Structure

```
src/
  types.ts          # The data model, and nothing else
  utils/
    encounter.ts    # Every encounter transition, as a pure function of state
    toughness.ts    # Current/max, damage dealt, pain thresholds
    migrate.ts      # Reading version 1 data, and repairing what is out of range
    exportImport.ts # Save files: version dispatch and IO
    character.ts    # Characters, their attributes, and joining a fight
    core.ts         # uid, clamp
  hooks/
    history.ts      # Undo/redo as data — push, coalesce, capacity
    storage.ts      # localStorage, with failures that are not swallowed
    usePersistent*  # The React wiring around the two above
  components/       # UI panels, cards, and modals
  data/             # Default characters and monster presets
  App.tsx           # Wiring: when things happen, not what they do
```

## Design notes

**The interesting parts are pure.** Every decision an encounter can make — adding
NPCs, removing one, sorting, stepping the turn, applying damage — is a function
from `EncounterState` to `EncounterState` in `utils/encounter.ts`. `App.tsx`
decides *when* those run and owns the things that are genuinely about being an
app: persistence, toasts, which tab is open. That split is why the test suite
needs a browser for exactly one file.

**Repairs are reported, never silent.** Anything loaded from disk or from
localStorage goes through a reader that clamps the turn cursor, floors the round,
renumbers duplicate ids and rebuilds the NPC name counter — and hands back a list
of what it changed. A silent repair and a silent acceptance look identical from
the outside, which is how a corrupted file gets trusted.

**There is no difficulty rating, on purpose.** The app used to compute one from a
weighted ratio of toughness, numbers and defense. The weights came from nowhere,
and it divided by the party's average defense — which is zero for a party of
unfilled sheets, so with stock data it returned `Infinity`. It was replaced with
an exact absorbing-state model on a branch, and that was deleted too: this app
records no weapons, abilities, traits or mystical powers, which is most of what
decides a Symbaroum fight. A number computed from toughness and defense alone
would be trusted and wrong. The encounter panel shows what each side has and
leaves the judgement to the GM.

**Numeric fields are `type="text"` with `inputMode="numeric"`.** A focused
`type="number"` changes its value when the page is scrolled under the cursor,
which in a tracker whose job is holding numbers between rolls is a silent
data-loss bug. It also does not support the selection API, so select-on-focus
cannot work there.

