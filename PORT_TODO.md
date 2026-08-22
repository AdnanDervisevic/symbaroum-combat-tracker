# OCaml Port — Progress Ledger

> **Read this first, before touching anything else in this branch.**

## What this is

This branch (`ocaml-port`) ports the Symbaroum Combat Tracker from React 19 + TypeScript
to **OCaml + Bonsai**. `master` keeps the React app and the live Vercel URL and is not
touched by this work.

The goal is **not** feature improvement. It is to produce a repository that demonstrates
OCaml and functional-design competence to a Jane Street reader. That audience constraint
drives every decision here: `Core` not `Stdlib`, `.mli` for every module, `ppx_expect` and
`Base_quickcheck`, `Identifiable.S`, `profile = janestreet` formatting. Idiom is as much
of the deliverable as behaviour — an OCaml repo written in tutorial style with assoc lists
signals the opposite of what we want.

**Two artifacts are the actual deliverable. Everything else serves them.**

1. `doc/model.md` — derivation of the combat probability model, its state-space reduction,
   and its stated assumptions.
2. A README table: *illegal state TypeScript permitted → the OCaml type that deletes it →
   the test documenting the bug it caused.*

This is 12–20 focused days of work spanning many sessions **with no shared context between
them**. This file is the only continuity. Trust it over any recollection.

---

## Current status

```
Phase:        0 — Toolchain spike — RESTARTING ON WSL2. Blocker resolved; awaiting a reboot.
Last session: 2026-08-22 — Native Windows opam proved unable to host `core` or `bonsai`
              (see §0.1b). Human resolved the contradiction: **use WSL2**, which restores
              the full approved plan. `wsl --install --no-distribution` succeeded and
              enabled Virtual Machine Platform. **A REBOOT IS REQUIRED** before WSL2 can
              start — it had not happened when this was written.
Next action:  1. Confirm WSL2 works:  wsl --status   (must not say "virtualisation is not
                 enabled"). If it still complains, the reboot has not happened yet — stop
                 and ask for one.
              2. Install Ubuntu:      wsl --install -d Ubuntu
              3. Re-run Phase 0 §0.1 INSIDE Ubuntu, not on Windows. See §0.1c.
              Do NOT start Phase 1 until a Bonsai hello-world renders.
```

---

## Update protocol

Every session follows this. It is the difference between a ledger and a lie.

1. **Read this file first**, before any other action. Trust it over recollection.
2. **Check a box only when the build is green with that work included** — not when the code
   is merely written. Green means:
   ```bash
   dune build @fmt && dune build -p symbaroum && dune runtest
   ```
3. **Update the status block and the decisions log in the same commit as the code.**
   A ledger that drifts from the tree is worse than no ledger.
4. **When a phase's exit criterion is met**, tick the phase heading and set `Next action`
   to the first unchecked task of the following phase.
5. **If this plan turns out to be wrong** — a library doesn't exist on Windows, an API
   signature differs, the rules reconstruction is off — **edit this file to reflect reality
   and note what changed in the decisions log.** Do not silently work around it. A wrong
   plan that is quietly routed around costs the next session a full rediscovery.

`doc/model.md` is written in Phase 5 and the README in Phase 8. Until then their content
accumulates here.

---

## Decisions log

Settled decisions. **Do not relitigate these.** Append new ones with a date and one line
of rationale.

| Date | Decision | Rationale |
|---|---|---|
| 2026-08-22 | **OCaml**, not Haskell/Elm/F# | It is Jane Street's language. Anything else is functional but off-target. |
| 2026-08-22 | **Native Windows opam**, not WSL2 | User's call, made against a WSL recommendation. Consequence: Bonsai-on-Windows is the plan's biggest risk, handled by the Phase 0 spike and its ranked fallbacks. |
| 2026-08-22 | **Core library *and* Bonsai UI** in scope | User's call, made against a core-only recommendation. Bonsai is Jane Street's own UI library, so it carries signal — but Phases 1/3/4/5 carry more. |
| 2026-08-22 | **Build the real probability model now**; it replaces the difficulty heuristic | A straight port only proves syntax transcription. The model is what turns "ported a webapp" into "built a probabilistic model over a pure functional core". |
| 2026-08-22 | **Fix the bugs, with a test documenting each** | Reproducing known-wrong behaviour is archaeology, not engineering. Each fix becomes a row in the README table. |
| 2026-08-22 | **`master` is untouched** | The live Vercel deployment and its real user data (`sct.v1.*` localStorage keys) stay working throughout. |
| 2026-08-22 | Split the plan's single `opam install` into three transactions | opam rolls back a whole failed transaction. One combined install would have reported "something failed" instead of "the core is fine, Bonsai is not" — which is the exact distinction the four fallbacks are keyed on. This is why we know precisely where the wall is. |
| 2026-08-22 | **`bonsai_web` is not an opam package** | It is a *library* inside the `bonsai` package. The plan's install line named it as a package; that line is wrong. Corrected in §0.1. |
| 2026-08-22 | **CONTRADICTION FOUND** (resolved two rows below). Native Windows opam cannot host Core or Bonsai. | See "Phase 0 findings" and "Open questions". This is the first time the plan has been proven wrong about something load-bearing. |
| 2026-08-22 | **RESOLVED: use WSL2. This supersedes the "native Windows opam" decision above.** | Asked the human, who chose WSL2 over the Base-instead-of-Core alternative. This restores the plan exactly as approved — `Core`, `Bonsai`, `expect_test_helpers_core`, `virtual_dom`, `Fdeque` all become available again. Nothing else in this file needs rethinking; only Phase 0 gets re-run, inside Ubuntu. |
| 2026-08-22 | The native Windows opam switch (`_opam/` at the repo root) is **abandoned, not deleted** | It is gitignored and costs nothing to leave. Deleting it is a Phase 8 tidy-up, not a blocker. Note it holds no `core`, so it cannot be reused. |
| 2026-08-22 | WSL was already present; only **Virtual Machine Platform** was disabled | `wsl --install --no-distribution` enabled it and returned success, but the change **needs a reboot**. `HypervisorPresent` reads `True` while `VirtualizationFirmwareEnabled` reads `False` — that is the normal masked reading from inside a running hypervisor, **not** a firmware problem. Don't send anyone into the BIOS over it. |

---

## Phase 0 — Toolchain spike  ⏱ ½ day

**This phase exists to fail fast.** It is the only phase that can invalidate the plan.
The machine has no opam, no OCaml, no dune, no Node, and no WSL distribution — only Git and
winget. Toolchain setup is a prerequisite, not a footnote.

`core`, `ppx_jane`, and `yojson` are pure OCaml with good Windows support. **`bonsai_web` is
the risk**: it pulls a wide slice of the Jane Street release train, and packages in that
neighbourhood have historically carried `core_unix`, `spawn`, or C-stub dependencies that do
not build on native Windows. Whether the current release installs cleanly there is unknown.
Find out on day one, for ~45 minutes of effort, before writing a line of domain code.

### 0.1 Install

- [x] `winget install OCaml.opam` — got **opam 2.5.2**
- [x] **From PowerShell or cmd — NOT Git Bash.** opam's Windows support uses its own Cygwin
      root; MSYS2 path mangling from Git Bash causes confusing, misleading failures.
  - [x] `opam init --bare --yes --cygwin-internal-install` — exit 0
  - [x] `opam switch create . 5.2.0 --yes --no-install` — exit 0, OCaml 5.2.0 + mingw-w64
  - [ ] ~~`opam install core … bonsai bonsai_web …`~~ **FAILED — see findings below**
- [x] Add `_opam/` and `_build/` to `.gitignore`
- [ ] Record the **exact** resolved versions of `bonsai`, `js_of_ocaml`, and `ocamlformat`
      in the decisions log — Bonsai's API churned hard (Proc style with `Value.t`/`Computation.t`
      → Cont style with `Bonsai.t` and an explicit `graph`) and public docs lag the release.
      Follow `bonsai/examples/` **from the pinned release tag**, never blog posts.
- [ ] `.ocamlformat` with `profile = janestreet` and a pinned exact version, matched in the opam file

### 0.1b Phase 0 findings — READ THESE BEFORE RE-RUNNING ANYTHING

**The spike did its job: it found the wall on day one, before any domain code was written.**

#### What works on native Windows opam (verified installed in the local switch)

| package | version |
|---|---|
| `dune` | 3.24.2 |
| `base` | v0.16.5 |
| `ppx_jane` | v0.16.0 |
| `ppx_expect` | v0.16.2 |
| `base_quickcheck` | v0.16.0 |
| `yojson` | 3.0.0 |
| `ppx_yojson_conv` | v0.16.0 |
| `js_of_ocaml` + `js_of_ocaml-ppx` | 6.4.1 (verified by dry-run, not yet installed) |

#### What does NOT work, and why

**1. `core` is unavailable on native Windows at every version.** Two independent mechanisms:

- `core >= v0.17` → depends on `base_bigstring >= v0.17`, which the opam repository marks
  `available: arch != "x86_32" & os != "win32"`. opam refuses to even attempt it.
- `core v0.16` → resolves to `base_bigstring v0.16.0`, whose C stubs fail to compile under
  mingw-w64:
  ```
  base_bigstring_stubs.c:238:24: error: implicit declaration of function 'memmem'
  ```
  `memmem` is a glibc extension that mingw-w64 does not provide, so this is not a warning
  that can be flagged away — there is nothing to link against.

The `os != "win32"` marker from v0.17 onward is a **deliberate upstream decision**, not an
accident. Do not burn a session trying to patch around it.

**2. `bonsai` is unavailable on native Windows.** It transitively requires four separate
win32-excluded packages:

- `bonsai -> async >= v0.16 -> core_unix` — `os != "win32"`
- `bonsai -> core_unix >= v0.15 -> ocaml_intrinsics` — `arch = "x86_64" & os != "win32"`
- `bonsai -> textutils -> core >= v0.17 -> base_bigstring >= v0.17` — `os != "win32"`
- with `bonsai` old enough to avoid those, it demands `core_kernel < v0.14 -> ocaml < 4.12.0`

This is **exactly the risk the plan named as its biggest**, and it materialised. What the plan
did *not* predict is that `core` falls with it.

**3. `expect_test_helpers_core` depends on `core`**, so it falls too. Any Base-only path must
use `ppx_expect` with plain sexp printing instead of `Expect_test_helpers_core.print_s`.

#### Environment quirks that will bite the next session

- **opam is not on this shell's PATH.** winget installed it to
  `C:\Users\adnan\AppData\Local\Microsoft\WinGet\Packages\OCaml.opam_Microsoft.Winget.Source_8wekyb3d8bbwe\`
  and updated the *user* PATH, but an already-running shell keeps a cached environment.
  Prepend that directory in every command, or start a fresh shell.
- **Do not pipe `opam` through `2>&1` in PowerShell.** It wraps stderr lines in a
  `NativeCommandError` and sets `$?` to false even on exit 0. A future session will read that
  as a failure. Let stderr flow normally; it is captured anyway.
- Windows **Developer Mode is off**. opam noted it only enables symlinks without elevation and
  is not required. Not currently a problem.
- The switch is a **local switch** at the repo root, so `_opam/` sits in the working tree.
  Already gitignored.

### 0.1c Redo of §0.1, inside WSL2 — THIS IS THE LIVE CHECKLIST

§0.1 above is **dead**; it documents the native Windows attempt and is kept only as evidence.
Everything below runs **inside Ubuntu**, not in PowerShell.

**Prerequisites (Windows side, one time):**

- [x] `wsl --install --no-distribution` → "The requested operation is successful. Changes will
      not be effective until the system is rebooted." Virtual Machine Platform is now enabled.
- [ ] **REBOOT.** Until this happens `wsl --status` says *"WSL2 is unable to start since
      virtualisation is not enabled on this machine."* That message is about the pending
      feature enablement, **not** the firmware. Do not send anyone into the BIOS.
- [ ] `wsl --status` shows no virtualisation complaint
- [ ] `wsl --install -d Ubuntu` — sets a UNIX username/password interactively. **This prompts,
      so it cannot run from a non-interactive tool shell; a human runs it in a terminal.**

**Inside Ubuntu:**

- [ ] `sudo apt update && sudo apt install -y opam build-essential pkg-config m4 unzip curl git`
- [ ] `opam init --bare --yes --disable-sandboxing`
      (`--disable-sandboxing` because bubblewrap is unreliable under WSL2)
- [ ] Work from the repo. It is reachable at `/mnt/c/Users/adnan/symbaroum-combat-tracker`,
      **but do not build there** — `/mnt/c` is 9p-mounted and pathologically slow for dune,
      and a local switch on it will crawl. Either `git clone` into the Linux filesystem
      (`~/symbaroum-combat-tracker`) and push/pull between the two, or accept the slowness
      deliberately. **Decide this and record it as a decision-log row before proceeding.**
- [ ] `opam switch create . 5.2.0 --yes --no-install`
- [ ] `eval $(opam env)`
- [ ] `opam install -y core ppx_jane base_quickcheck expect_test_helpers_core yojson ppx_yojson_conv`
- [ ] `opam install -y js_of_ocaml js_of_ocaml-ppx virtual_dom`
- [ ] `opam install -y bonsai`  ← **note: NOT `bonsai_web`**, which is a library inside this
      package, not a package. Kept as three transactions so a Bonsai failure does not roll
      back and mask the core result — that split is what made the last spike diagnostic.
- [ ] Record the **exact resolved versions** (`opam list core bonsai js_of_ocaml ocamlformat`)
      here. The plan requires pinning `bonsai` and following `bonsai/examples/` from that
      same release tag, because the API churned (Proc style → Cont style) and public docs lag.
- [ ] `_opam/` and `_build/` already gitignored — confirm they still are in the clone

### 0.2 Prove it

- [ ] `dune build` succeeds on a trivial `lib/` + `test/` skeleton
- [ ] A Bonsai hello-world page builds and renders in a browser — **restored**, now that WSL2
      makes Bonsai available again. This is the real Phase 0 exit gate.

### 0.3 Exit criterion

**Do not start Phase 1 until 0.2 is green or a fallback is chosen and recorded here.**

Fallbacks, in order of preference:

- **A — recommended if Bonsai fails.** Core builds locally; `web/` builds only in GitHub
  Actions or an `ocaml/opam:debian-ocaml-5.2` container. Bonsai is never needed on Windows —
  edit, push, CI builds. Slow UI feedback loop, but Phases 1–5 are entirely headless anyway.
- **B.** Drop Bonsai, keep `js_of_ocaml` + `virtual_dom`. Much smaller dependency surface,
  `lib/` untouched, keeps most of the signal.
- **C.** Ship core + CLI; leave React on `master` as the UI.
- **D.** WSL2 (`wsl --install -d Ubuntu`, ~20 min). Ruled out by the user; last resort only
  if fallback A's feedback loop proves intolerable.

---

## Target structure

```
lib/symbaroum/          # zero js_of_ocaml dependency, ENFORCED BY CI
  scalars:    ids, attribute, attribute_value, attributes, dice, armor,
              defense, toughness, pain_threshold, attack_profile,
              monster_type, names, round, npc_count, adjust_amount
  aggregates: character, roster, combatant, turn_order, name_counter,
              encounter, bestiary, bounded_list, encounter_archive
  transitions: npc_draft, member_patch, command, event, world, undo_history
  import_export/: json_decoder, wire_v1, wire_v2, normalization, codec
  model/:     pmf, hit_chance, attrition_dp, combat_sim, difficulty
  data:       monster_preset, monster_presets (generated), default_roster
test/                   # ppx_expect + Base_quickcheck
bin/symbaroum_cli.ml    # headless demo: load an export, print world + analysis
web/                    # Bonsai, js_of_ocaml
doc/model.md
```

Rules that hold throughout:

- Every `.ml` gets an `.mli` **except generated data**.
- Dependency direction is strictly downward: scalars → aggregates → transitions → `import_export`.
- **`model/` depends only on scalars, `combatant`, and `encounter`** — not on `command`,
  `world`, or the codec — so the DP is testable and benchmarkable in isolation.
- **Two dune packages** (`symbaroum`, `symbaroum_web`) make "the core has no JS dependency"
  a *checked* property. CI runs `dune build -p symbaroum` as its own step.
- **Avoid `core_unix` in the core library**: C stubs, a Windows problem, and it will not
  compile to JS. If something drags it in transitively, chase it down rather than work around it.

---

## Phase 1 — Scalars and ids  ⏱ 1–2 days

The most idiom-dense code in the repo, and the part a reviewer reads first. Each type kills
a specific illegal state that [`src/types.ts`](src/types.ts) permits.

- [ ] `ids.ml` — `Character_id`, `Combatant_id`, `Bestiary_id`, `Snapshot_id` via
      `Identifiable.Make`, giving `Map`/`Set`/`Table` free. Today all four are bare `string`.
      Also replaces `CharacterCard.tsx:112`'s `id.startsWith('pc_default_')` — a data property
      smuggled into an identifier — with an `is_builtin : bool` field.
- [ ] `attribute.ml` — the 8 attributes as a variant with `Map`/`Set`
- [ ] `attribute_value.ml` — `private int` bounded `1..20`, with `modifier t = 10 - raw`
- [ ] `attributes.ml` — *key-total* `Attribute_value.t option Attribute.Map.t`.
      Today `attributes?: CharacterAttributes | null` gives "no attributes" three spellings
      (`undefined`, `null`, `{}`) and each of the 8 fields three more.
      **`normalizeAttributes`, `cloneAttributes` and `areAttributesEqual` in
      [`combatLogic.ts`](src/utils/combatLogic.ts) exist solely to paper over this and all
      three vanish** — structural compare is derived.
- [ ] `dice.ml` — `{ count; sides; modifier }`, parser + `pmf`
- [ ] `armor.ml` — `Unarmored | Fixed of int | Rolled of Dice.t | Unparsed of string`,
      **total** parser. Today `armor: string` is never parsed anywhere. `Unparsed` is the
      honest representation: it round-trips the GM's free text while making "the model could
      not use this" visible in the type *and* in the UI.
- [ ] `defense.ml` — `private int` in `1..20`. See the Phase 2 data problem: the preset field
      mixes modifiers and absolute targets, and this constructor is where that is forced into the open.
- [ ] `toughness.ml` — `private { current : int; max : int }` with `0 <= current <= max`.
      Today `toughness: number` is current and max at once, clamped in three view-layer places
      ([App.tsx:407](src/App.tsx:407), [CombatantCard.tsx:89](src/components/cards/CombatantCard.tsx:89),
      [CharacterCard.tsx:52](src/components/cards/CharacterCard.tsx:52)) and **zero places on
      the import path**. `max` is also what the probability model needs to define "down".
- [ ] `pain_threshold.ml` — `No_threshold | Every_hit | At_least of int`.
      Today `number | null`, where `null` means "never prones" and `0` means "every hit prones" —
      a distinction that lives only in the author's head and in [App.tsx:411](src/App.tsx:411).
- [ ] `attack_profile.ml` — carries `source : From_data | Estimated_from_resistance`
- [ ] `monster_type.ml`, `names.ml`
- [ ] `round.ml` — `private int >= 1`
- [ ] `npc_count.ml`, `adjust_amount.ml`
- [ ] `Base_quickcheck` generators for every scalar, routed **through the smart constructors**
      so only legal values are generated
- [ ] `dune runtest` green

**Exit:** ~15 modules with full `.mli`s, generators, tests green.

---

## Phase 2 — Data port + normalization  ⏱ 1 day

- [ ] `monster_preset.ml` + `.mli`
- [ ] Generate `monster_presets.ml` from [`src/data/defaultMonsters.ts`](src/data/defaultMonsters.ts) (84 presets)
- [ ] Port [`src/data/defaultCharacters.ts`](src/data/defaultCharacters.ts) → `default_roster.ml`
- [ ] **Golden expect test dumping all 84 normalized presets in one `[%expect]`**, so the
      Defense reconciliation lands as a reviewable diff rather than a silent rewrite
- [ ] `dune runtest` green

### The two data problems — resolve these honestly, do not paper over them

**1. The preset `defense` field is internally inconsistent, and it becomes load-bearing.**
Verified in the source data:

```
Spring Elf:     qui: 13, defense: -3   // a MODIFIER (10 − qui)
Servant Daemon: qui: 15, defense: 15   // an absolute roll-under TARGET
```

Both sit in the same `number`-typed array. Today nothing consumes `defense` but a ratio, so
it does not matter. **The moment Defense becomes a to-hit target it matters enormously.**
`Defense.t = private int` in `1..20` makes the two structurally distinguishable at the
constructor; the golden test above makes the reconciliation reviewable.

Also in that file: `armor` is a bare integer in 81 of 84 presets and dice in 3, while PCs use
`'Light (d4)'`; 7 presets have all four stat fields `null`.

**2. The app has no weapon or damage data at all.** The to-hit side is grounded — all 84
presets carry `acc`. Only the damage die is a guess. Use the existing `resistance` field as
the prior (`Weak → 1d6`, `Ordinary → 1d8`, `Challenging → 1d10`, `Strong → 1d12`), mark it
`Estimated_from_resistance` in `Attack_profile.source`, make it editable in the UI, and
surface it in `caveats`. **Never let an estimate masquerade as data.**

---

## Phase 3 — Encounter, commands, undo  ⏱ 2–3 days

Stands alone as a portfolio piece: a headless combat engine with a transcript test and the
full bug ledger.

- [ ] `character.ml`, `roster.ml`, `combatant.ml`
- [ ] `turn_order.ml` — **nonempty zipper** `{ before; current; after }`
- [ ] `name_counter.ml` — high-water marks per monster type, **stored in the encounter**
- [ ] `encounter.ml` — the type that matters most:
  ```ocaml
  type t = private
    | Empty  of { name_counter : Name_counter.t }
    | Active of { members      : Combatant.t Combatant_id.Map.t
                ; order        : Combatant_id.t Turn_order.t
                ; round        : Round.t
                ; name_counter : Name_counter.t }
  ```
- [ ] `Invariant.S` implemented for `Encounter.t`
- [ ] `bestiary.ml`, `bounded_list.ml`, `encounter_archive.ml`
- [ ] `npc_draft.ml`, `member_patch.ml`
- [ ] `command.ml` — all 13 transitions, currently closures in [`src/App.tsx`](src/App.tsx)
- [ ] `event.ml` — `Pain_threshold_exceeded | Combatant_downed | Round_completed | Encounter_archived | Import_normalized | Rejected`
- [ ] `world.ml` — `World.apply : t -> Command.t -> t * Event.t list`, **pure and total**
- [ ] `undo_history.ml` — bounded zipper backed by `Fdeque`, with `push ~coalesce_with`
- [ ] **Combat transcript expect test** — apply a `Command.t list`, print state + events after
      each step. The best single demo file in the repo; it should read like a plausible combat log.
- [ ] Every bug-ledger test below that belongs to this phase
- [ ] `dune runtest` green

### Why these shapes

**`Combatant.Allegiance = Player_character of Character_id.t | Non_player of { monster_type : Monster_type.t option }`**
fuses three loosely-coupled fields (`source`, `refId?`, `monsterType?`) that today allow
`{source:'npc', refId:'pc_x'}`. Deletes the runtime guard at [App.tsx:453](src/App.tsx:453).
It also *forces* a fix: `addNpc` ([App.tsx:246](src/App.tsx:246)) builds a combatant literal
that silently omits `attributes`, so preset attributes are dropped; a total record makes the
compiler demand a value.

**`Encounter.t` as above:**
- Out-of-range `turnIndex` becomes **unrepresentable**. `{members: [], turnIndex: 5, round: 0}`
  is legal today and is *actually produced* by four paths: `handleImport`, `restoreEncounter`,
  `deleteCharacter` (prunes members without repairing the index), and hand-edited localStorage.
- **The sort-resets-round bug is deleted by construction.** [App.tsx:340](src/App.tsx:340) does
  `round: prev.members.length ? 1 : prev.round`. With `round` outside `Turn_order.t`,
  `sort_stable_by` structurally cannot touch it. This is the cleanest "the type deleted the
  bug" story — **put it in the README**.
- Duplicate ids become impossible; the `findIndex` scans in `moveMember`/`removeMember`
  become O(log n).
- Map-plus-ordered-id-list is exactly the shape `Bonsai.assoc` wants (Phase 6). Design it this
  way from the start.

**`Name_counter` in the encounter:** today `addNpc` counts *live* members
([App.tsx:231](src/App.tsx:231)), so adding 3 Goblins, removing Goblin 2, then adding one more
produces a second "Goblin 3". Migration consequence: v1 saves have no counter, so
`rebuild_from` derives it from the max observed suffix.

**`World.apply` returns events**, which kills the ugliest thing in the current code:
`applyAdjustment` ([App.tsx:398-435](src/App.tsx:398)) declares a mutable ref, writes to it
*inside* `members.map`, then reads it after `setEncounter` to fire a toast and a
`setTimeout(…, 0)` that dodges a React batching problem. Events make the reducer pure and the
toast text testable.

**`World.t = { roster; encounter; bestiary; history }`**, not `Encounter.t`, because several
transitions cross stores: `addNpc` writes encounter + bestiary; `clearEncounter` writes
encounter + history; `deleteCharacter` writes roster + encounter.

**`Member_patch.t` as an explicit variant** replaces `Partial<Combatant>`, whose shallow merge
([App.tsx:291](src/App.tsx:291)) can set *any* field to *any* value, including `source` and a
negative toughness.

**`Undo_history`** kills two bugs: `redo`
([usePersistentHistory.ts:112](src/hooks/usePersistentHistory.ts:112)) appends to `past` with
**no `slice(-50)`**, so ping-pong grows it unboundedly; and the dedupe at line 84 is JS
*reference* equality, which never fires for a fresh object literal — so every keystroke in a
note field burns a slot and 50 entries evaporate in one sentence.

---

## Phase 4 — Codec, migration, CLI  ⏱ 1–2 days

- [ ] `json_decoder.ml` — an `Applicative.S`. **Applicative, not monad — that is what makes
      error *accumulation* possible. Say so in the doc comment.** `field`, `field_opt`,
      `field_or`, `one_of`, `at` for JSON-path context, `all_errors`. ~120 lines, and one of
      the two files a reviewer will read closely.
- [ ] `wire_v1.ml` — mirrors [`src/types.ts`](src/types.ts) field-for-field including the
      optional/nullable spellings. **Frozen forever**: the deployed app has real user data in `sct.v1.*`.
- [ ] `wire_v2.ml` + `migrate.ml`
- [ ] `normalization.ml`
- [ ] `codec.ml`
- [ ] `bin/symbaroum_cli.ml`
- [ ] Decoder error-message expect tests against ~10 malformed blobs
- [ ] `dune runtest` green
- [ ] **Round-trip a real export from the deployed React app**

### Derive the writer, hand-write the reader

**`ppx_yojson_conv` for encoding. A hand-written applicative decoder for decoding.**

The argument, in the order worth making in an interview: encoding is total, decoding is
partial, so only the partial direction needs machinery. More importantly, **a derived
`of_yojson` on the domain types would reintroduce every illegal state** — it constructs
records directly and cannot route through `Toughness.of_current_max` or `Encounter.create`.
Deriving a reader on a `private` type either fails or requires making the type public,
defeating the entire design. **The trust boundary is precisely where smart constructors
matter most, so it is precisely where derivation is wrong.**

Also: derived readers raise on first mismatch, where an import reporting *"3 problems, at
these JSON paths"* is strictly better; and the JS shapes need "missing, null, and `{}` all
mean `None`" as a reusable combinator.

```
raw string -> Yojson.Safe.from_string -> version dispatch
  -> Wire_v1.decode | Wire_v2.decode    (* total records, no invariants *)
  -> Migrate.v1_to_v2                    (* pure record shuffling *)
  -> Wire_v2.to_domain                   (* smart constructors; the ONLY place *)
       : World.t * Normalization.t list
```

**Normalization is total and *reported*, never silent and never rejecting.** Only structurally
impossible input (unparseable JSON, `members` not an array, unknown version) errors. Everything
else is repaired and returned as `Normalization.t list`: `Turn_index_clamped`, `Round_clamped`,
`Duplicate_id_replaced`, `Orphan_pc_demoted`, `Armor_unparsed`, `Name_counter_rebuilt`. The
import dialog can then say "Loaded — 3 corrections applied" *and* the tests can assert the
corrections, which turns "we clamp somewhere" into a specification.

**All `turnIndex`/`round` normalization happens in exactly one function: `Encounter.create`.**
Not in the decoder, not in the migration, not in the UI.

Version dispatch fixes a real hole: [exportImport.ts:44](src/utils/exportImport.ts:44) checks
that `version` is a number and **never compares it to 1**, so a `version: 7` file is accepted
and blind-cast. New behaviour errors on unknown versions.

On disk: keep *reading* the five `sct.v1.*` keys forever; write one consolidated `sct.v2.app`.

---

## Phase 5 — Probability model  ⏱ 2–4 days — **DO NOT CUT THIS**

This is the centerpiece and the artifact you actually want read. It replaces the heuristic at
[EncounterPanel.tsx:5-35](src/components/panels/EncounterPanel.tsx:5), whose weights
(0.5 / 0.3 / 0.2) are derived from nothing.

- [ ] `pmf.ml` — `float array`, exact convolution
- [ ] `hit_chance.ml` — **all Symbaroum rules live in this one function**
- [ ] `attrition_dp.ml` — power iteration over `Bigarray.Array1`
- [ ] `combat_sim.ml` — Monte Carlo oracle, `Splittable_random`
- [ ] `difficulty.ml` — `analyze`, budget dispatch, labels
- [ ] `doc/model.md`
- [ ] Closed-form anchor tests
- [ ] Monotonicity property over 1,000 generated cases
- [ ] DP↔MC agreement test with a **fixed seed**
- [ ] Targeting-bias table (expect test)
- [ ] `dune runtest` green

### Ship the exact DP; keep Monte Carlo as the oracle

Not either/or — they have distinct jobs. `Attrition_dp` computes exact absorption probability:
deterministic, no seed, no confidence interval to explain to a GM, and it returns a *rigorous*
error bound. `Combat_sim` runs the full rules to (a) validate the DP under matched assumptions,
(b) **quantify the bias** the DP's simplifications introduce as a printed number rather than a
hand-wave, and (c) handle encounters that blow the state budget.

### The reduction

Naively the state is the full HP vector: 4 PCs and 6 NPCs at 10 toughness is
`11^10 ≈ 2.6 × 10^10`. Dead on arrival.

**Under focus fire the HP vector collapses to two integers per side.** If each side attacks its
enemies in a fixed order, then at any moment the enemies before the current target are dead and
those after are at full toughness. So the party's entire state is `(i, h_A)` — index of the
first living PC and its remaining toughness. Symmetrically `(j, h_B)`.

```
s = (i, h_A, prone_A, j, h_B, prone_B)
```

**Prone is nearly free**: only the two current targets can take damage, so prone costs a factor
of 4, not `2^(n_A+n_B)`. The DP therefore models the app's signature mechanic *exactly* rather
than dropping it.

| encounter | states |
|---|---|
| 4 PCs (T=10) vs 6 NPCs (T=10) | 14,000 |
| 5 PCs (T=15) vs 8 NPCs (T=15) | 48,600 |
| 8 PCs (T=20) vs 20 NPCs (T=20) | 302,400 |

### Transition

`Hit_chance.of_matchup ~attacker ~defender_defense ~defender_prone ~attacker_flanking` holds
every rule, so a rules correction is a one-line diff. The modeled rule: d20 roll-under,
effective target `TN = Accurate_att + (10 − Defense_def)` clamped to `[1,19]`, `p_hit = TN/20`.
**State plainly in `doc/model.md` that this is a reconstruction** — reasonably but not fully
confident against the core book, and the prone/flanking modifiers are unverified.

Damage is exact convolution, not sampling: `D_net = max(0, weapon_dice − armor_reduction)`,
with all mass at `≤ 0` collapsed onto 0. Support is small (1d8 vs 1d4 is 8 outcomes).

**Within-round sequencing is exact**: the round operator is the composition of per-combatant
attack operators in initiative order, not a simultaneous approximation. Two payoffs worth
stating: it resolves "does a combatant that dies before its turn still act?" as a modeled fact,
and it eliminates mutual annihilation, so `p_wins + p_wiped = 1` exactly.

### Solving it

**Power iteration over a flat `Bigarray.Array1` of float64**, applied out-of-place into a
scratch buffer, no allocation in the hot loop. (js_of_ocaml maps `Bigarray` to `Float64Array`;
a plain `float array` becomes a boxed JS array — this matters.)

Power iteration rather than solving `(I − Q)x = b` because:

- **No BLAS/LAPACK**, so the core stays pure OCaml with zero C stubs — which is exactly what
  lets it compile to JS *and* build on native Windows opam. A hard constraint, not a preference.
- **The round distribution comes free**, and "median 4 rounds, 90th percentile 9" is more useful
  to a GM than `p_win` alone.
- **The error bar is rigorous**: after `k` rounds the unabsorbed transient mass `m_k` is an
  exact upper bound on how far `p_win` can still move, so return `[p, p + m_k]`. That is a
  proof, not a heuristic — which is the difference that matters for this audience.
  Stop at `m_k < 1e-9` or 200 rounds.

Cost for 4v6 at T=10: ~45M flops, comfortably under 100 ms in js_of_ocaml. For 8v20 at T=20:
~4 × 10^9 — too slow for a browser.

**So the fallback lives in the return type.** Budget **250,000 states → exact DP; above →
Monte Carlo at 20,000 samples**. Note the pleasing inversion: DP cost is quadratic in toughness,
MC cost is *independent* of it, so MC is faster exactly where DP is infeasible. At 20k samples
`stderr ≤ 0.0035`, far tighter than a 6-bucket label needs.

```ocaml
type analysis =
  { label : Label.t
  ; p_party_wins : float
  ; p_bounds : float * float
  ; expected_party_casualties : float
  ; round_quantiles : (float * int) list
  ; method_ : Method.t   (* Exact_dp {states; rounds; residual} | Monte_carlo {samples; stderr; seed} *)
  ; caveats : Caveat.t list }

val analyze : Encounter.t -> analysis option   (* None iff either side is empty *)
```

### Assumptions — state these explicitly in `doc/model.md`

**Included:** initiative-ordered sequential resolution; one attack per combatant per round;
d20 roll-under modified by Defense; exact damage-minus-armor convolution floored at 0; death
removes a combatant; pain threshold → prone → lose next action → stand; fight to the last combatant.

**Excluded:** healing, mystical powers, morale/retreat, flanking (needs pairing structure the
app does not model), multi-attacks, initiative re-rolls, criticals.

**Focus fire is the load-bearing assumption.** It is defensible — focus fire is the optimal
attrition strategy for both sides, so assuming it symmetrically is a Nash-flavoured equilibrium
assumption, and it is what makes exactness possible at all. But **quantify the bias rather than
assert it is small**: `Combat_sim` supports
``~targeting:[ `Focus_in_order | `Uniform_random | `Weakest_first ]`` and an expect test prints
`p_win` under each across a dozen encounters. Also give the reviewer the number that forecloses
the alternative: under uniform targeting you need the multiset of HPs per type, and multisets of
20 NPCs over 11 HP values is `C(30,10) ≈ 3 × 10^7` before multiplying by the party side. That
shows the choice was *computed*, not assumed.

### Labels

`≥ 0.95` Trivial · `0.85–0.95` Easy · `0.60–0.85` Balanced · `0.35–0.60` Hard ·
`0.15–0.35` Deadly · `< 0.15` Overwhelming. Pinned by an expect test at the boundaries.

**Do not calibrate these to the old heuristic** — continuity with a broken baseline is not a goal.

**Lead the UI with `expected_party_casualties`, not `p_win`**: parties rarely fight to the last
member, so "Balanced — 71% win, expect 1.3 casualties, median 5 rounds" is far more actionable
than a bare label.

---

## Phase 6 — Bonsai skeleton  ⏱ 2–3 days

**Ends with:** a page that looks like the React app, read-only, real data, existing CSS.

- [ ] `web/` dune package, js_of_ocaml entry point
- [ ] Reuse [`src/App.css`](src/App.css) (780 lines) and [`src/index.css`](src/index.css)
      **verbatim**, keeping class names in the Vdom. This makes the UI phase a *pure logic port*
      with an identical-looking result — the fastest route to a side-by-side screenshot in the
      README. `ppx_css` is nicer OCaml but it is polish; only after parity.
- [ ] Static render of roster + encounter from `Default_roster`
- [ ] `Difficulty_readout` (static first)
- [ ] Component tree:
  ```
  App.component
  ├─ theme state -> Edge.on_change -> document.documentElement.dataset.theme
  ├─ App_state machine (world + undo) -> world, inject
  ├─ Characters_panel  -> assoc -> Character_card
  ├─ Encounter_panel   -> Difficulty_readout; assoc -> Combatant_card
  ├─ Help_panel (static)
  ├─ Add_combatant_modal (owns Npc_draft state)
  └─ Toasts ~events
  ```

---

## Phase 7 — Interactivity + persistence  ⏱ 2–3 days

**Ends with:** feature parity.

- [ ] **Collapse four of the five stores into one `Bonsai.state_machine0` over
      `World.t Undo_history.t`**, action type `Command.t | Undo | Redo`. Today `addNpc` and
      `clearEncounter` each write two stores in two `setState` calls, so there is a real window
      where encounter and bestiary disagree and undo covers only one. One machine, one `apply`,
      one atomic transition. **Theme stays a separate `Bonsai.state` — deliberately not undoable.**
- [ ] **`damageInputs` and `editingIds` become `Bonsai.assoc` per-row state.** Today they are
      root-level maps keyed by combatant id, pruned only in `removeMember` and only for
      `editingIds` — **`damageInputs` leaks entries forever**. `assoc` creates and destroys row
      state with the row, so the framework structurally removes the leak. **Worth noting in the
      README.** This is also why `Encounter.Active` holds a `Map` *plus* an ordered id list:
      `assoc` produces a `Vdom.Node.t Combatant_id.Map.t` and the panel renders by mapping the
      ordered ids through it.
- [ ] **Toasts:** drop `react-toastify`, roll ~60 lines — a `Bonsai.state` queue fed by the
      `Event.t list` from `apply`, expired by `Bonsai.Clock.every`. Cleaner than the React
      version precisely *because* events are returned rather than fired from inside the reducer.
- [ ] **Difficulty readout:** the DP can take ~200 ms, so do **not** compute it in render.
      `Edge.on_change` on a signature of the model-relevant fields → `Effect.of_sync_fun` →
      `Bonsai.state`, with a monotone request counter dropping stale results and a `Clock`
      debounce. Show "computing…" between. (A Web Worker via a second js_of_ocaml entry point is
      the real fix, but the Bonsai-side ergonomics are unverified — optional polish, not a
      plan dependency.)
- [ ] **localStorage:** no first-class Bonsai binding exists (`Persistent_var` is a different
      thing). ~30 lines over `Dom_html.window##.localStorage` wrapping `Js.Optdef` and
      exceptions, with `set` returning `Or_error` so `QuotaExceededError` is handled explicitly
      rather than `console.warn`ed away as it is today. Persist via **throttled**
      `Edge.on_change` — writing hundreds of KB per keystroke makes an app feel broken. Persist
      `present` plus `past` truncated to 20, gated on serialized size < 1 MB, falling back to
      present-only.
- [ ] v1 localStorage migration on load
- [ ] Import/export dialogs

---

## Phase 8 — Deploy + docs  ⏱ 1 day

- [ ] GitHub Actions: `ocaml/setup-ocaml@v3` with dep caching → `dune build @fmt` →
      `dune build -p symbaroum` (**proves the core is JS-free**) → `dune runtest` →
      `dune build --profile release @web` → publish
- [ ] **Keep Vercel** by committing the built `public/` to the branch Vercel watches, with
      `vercel.json` set to `{"framework": null, "buildCommand": null, "outputDirectory": "public"}` —
      pure static, no Node, no build on Vercel's side. This preserves the existing URL in the
      README. (GitHub Pages via `peaceiris/actions-gh-pages` is simpler if you would rather drop
      Vercel; both is fine.)
- [ ] README leading with the model and the illegal-state table
- [ ] Side-by-side screenshot
- [ ] **Bundle size, stated honestly:** ~1.5–4 MB unminified, ~400–900 KB gzipped. `Base`
      instead of `Core` would shrink it meaningfully — but Core idiom *is* the goal, so keep
      Core and note the tradeoff in the README. **Being visibly aware of the cost is worth more
      here than the kilobytes.**

---

## Bug ledger

One named test per fixed bug, with the old wrong behaviour in a comment above the new
`[%expect]`. **This table is also the README table.** Tick a row when its test is green.

| ✓ | test | bug |
|---|---|---|
| [ ] | `test_npc_naming_survives_removal` | live count → duplicate "Goblin 3" ([App.tsx:231](src/App.tsx:231)) |
| [ ] | `test_npc_preset_attributes_are_kept` | `addNpc` silently drops `attributes` ([App.tsx:246](src/App.tsx:246)) |
| [ ] | `test_sort_preserves_round` | [App.tsx:340](src/App.tsx:340) resets round to 1 |
| [ ] | `test_delete_character_repairs_cursor` | [App.tsx:112](src/App.tsx:112) prunes members, leaves `turnIndex` |
| [ ] | `test_redo_respects_capacity` | `redo` never slices `past` ([usePersistentHistory.ts:112](src/hooks/usePersistentHistory.ts:112)) |
| [ ] | `test_typing_a_note_costs_one_undo` | reference-identity dedupe ([usePersistentHistory.ts:84](src/hooks/usePersistentHistory.ts:84)) |
| [ ] | `test_import_rejects_unknown_version` | `version` never compared to 1 ([exportImport.ts:44](src/utils/exportImport.ts:44)) |
| [ ] | `test_import_repairs_out_of_range_turn_index` | blind cast after the version check |
| [ ] | `test_difficulty_with_zero_defense_party` | `npcDefense / pcDefense` → `Infinity` ([EncounterPanel.tsx:19](src/components/panels/EncounterPanel.tsx:19)) |
| [ ] | `test_pain_threshold_uses_damage_dealt` | compares raw input, ignoring armor and clamping ([App.tsx:411](src/App.tsx:411)) |

**On the ninth row** — the divide-by-zero is reachable with stock data but narrower than it
first looks. The four default PCs have defense 8, 3, 0, 0, averaging to 2.75 → `Math.round` → 3,
so a **full party never triggers it**. It fires when the PCs *in the encounter* round to 0
average defense — e.g. adding only Vigoi and/or Ymma. **Write the test to that case.**

---

## Illegal-state table  → becomes the README table in Phase 8

| TypeScript state that is representable today | OCaml type that deletes it | Test |
|---|---|---|
| `{members: [], turnIndex: 5, round: 0}` | `Encounter.t` = `Empty \| Active` with a nonempty `Turn_order.t` zipper | `test_delete_character_repairs_cursor` |
| Sort silently resets `round` to 1 | `Round.t` lives outside `Turn_order.t`, so `sort_stable_by` cannot reach it | `test_sort_preserves_round` |
| `{source:'npc', refId:'pc_x'}` | `Allegiance = Player_character of Character_id.t \| Non_player of {...}` | (compile-time; note in README) |
| "no attributes" spelled `undefined` / `null` / `{}` | key-total `Attribute_value.t option Attribute.Map.t` | deletes `normalizeAttributes` + `areAttributesEqual` |
| `painThreshold: 0` vs `null` meaning different things | `No_threshold \| Every_hit \| At_least of int` | `test_pain_threshold_uses_damage_dealt` |
| `toughness` is current and max at once; unclamped on import | `private { current; max }` with `0 <= current <= max` | quickcheck: any `Adjust` sequence |
| `Partial<Combatant>` shallow-merges any field to any value | `Member_patch.t` explicit variant | (compile-time) |
| `armor: string` never parsed | `Unarmored \| Fixed \| Rolled \| Unparsed` total parser | `Armor.parse` totality property |
| Duplicate combatant ids | `Combatant.t Combatant_id.Map.t` | (compile-time) |
| `version: 7` accepted and blind-cast | explicit version dispatch, error on unknown | `test_import_rejects_unknown_version` |
| `damageInputs` grows without bound | `Bonsai.assoc` per-row state | (structural; note in README) |
| `id.startsWith('pc_default_')` as a data property | `is_builtin : bool` field on the record | (compile-time) |

---

## Testing strategy

**`ppx_expect` for anything a human should read the output of.** Use
`Expect_test_helpers_core.print_s [%sexp (x : t)]`.

**Golden dumps:**
- All 84 normalized presets in one `[%expect]` (Defense reconciliation as a reviewable diff)
- **Combat transcript** — a `Command.t list` applied step by step, printing state + events.
  The best single demo file in the repo.
- Decoder error messages against ~10 malformed blobs
- The difficulty table over 12 canonical encounters

**Closed-form anchors for the model:**
- 1v1 with `p_hit = 1` and lethal damage, party first → exactly `1.000000`
- Party of N vs 0 foes → `1.0`
- `Dice.pmf` for `2d6` → the 11 exact probabilities

**`Base_quickcheck` properties**, in rough order of value. Generators go *through* the smart
constructors, so only legal values are generated; the high-value generator is a `Command.t list`
applied to a generated `World.t`.

- [ ] 1. **Decoder totality** — for arbitrary junk `Yojson.Safe.t`, `of_json` returns `Ok` or
     `Error` and never raises. `validateImportData` fails this catastrophically today.
- [ ] 2. **Model monotonicity** — adding a foe, or raising any foe's toughness / Accurate /
     damage, weakly decreases `p_win`. A genuine theorem about the model and the strongest
     bug-catcher in the analysis code. **A quant reviewer will look for exactly this.**
- [ ] 3. **Round-trip** — `of_json (to_json w) = Ok (w, [])`, with *no* normalizations (the
     stronger statement)
- [ ] 4. **Normalization is a fixed point** — re-decoding a repaired value yields zero further repairs
- [ ] 5. **Undo capacity** — `depth` never exceeds capacity under any push/undo/redo sequence
- [ ] 6. `redo ∘ undo = id` when `can_undo`; `undo ∘ push = id` with coalescing off
- [ ] 7. **Cursor validity** and `Encounter.invariant` (via `Invariant.S`) after every command
- [ ] 8. **Round monotonicity** — non-decreasing under `Next_turn`, +1 exactly on wrap, always `>= 1`
- [ ] 9. `Prev_turn ∘ Next_turn = id` **except** at `(round = 1, index = 0)` where the floor
     bites — **assert the exception explicitly**; it documents an asymmetry that is otherwise folklore
- [ ] 10. Active-combatant identity preserved by `Move_member` and by removing a *different* combatant
- [ ] 11. No duplicate ids; auto-generated names pairwise distinct
- [ ] 12. `0 <= current <= max` after any `Adjust` sequence
- [ ] 13. `Armor.parse` total; `Pmf.t` sums to 1 within `1e-12`
- [ ] 14. **DP ↔ MC agreement** — `|p_dp − p_mc| < 4 · stderr` with a **fixed**
     `Splittable_random` seed (fixed seed + generous bound = not flaky)

---

## Verification

**Per phase, locally:**

```bash
dune build @fmt && dune build -p symbaroum && dune runtest
```

- **Phase 0** — a Bonsai hello-world renders in a browser. If it does not, pick a fallback
  **before** writing domain code.
- **Phases 1–3** — `dune runtest` green; the combat transcript expect test reads like a
  plausible combat log when eyeballed.
- **Phase 4** — export a real save from the live Vercel app, run it through
  `bin/symbaroum_cli.ml`, confirm the printed world matches what the React UI shows and that
  every reported normalization is explainable.
- **Phase 5** — closed-form anchors pass exactly; DP↔MC agree within `4 · stderr`; monotonicity
  holds over 1,000 generated cases; the CLI prints an analysis for the 12 canonical encounters
  in well under a second each.
- **Phases 6–7** — run both apps side by side (React via `npm run dev` after installing Node,
  OCaml via the built static output) and walk the same script in each: add PCs, add 3 NPCs from
  a preset, remove the middle one, add another (**names must not collide — this is the ported
  bug**), damage past a pain threshold, heal, sort, step a full round, undo/redo, export,
  reimport, reload the page.
- **Phase 8** — CI green on a clean checkout; the deployed URL loads and its localStorage
  `sct.v1.*` data migrates without loss.

**Cross-implementation check, worth doing once in Phase 4:** run the same command sequence
through both implementations and diff the resulting JSON. Every difference should be
attributable to a specific bug-ledger entry. **Anything unattributable is a port bug.**

---

## Scope control

**Realistic total: 12–20 focused days.** ~2,000 lines of TS becomes ~3,500–5,000 lines of OCaml
once `.mli`s and tests are counted.

**If time-boxed, cut in this order:**
1. Phase 7 polish (ship a read-mostly UI)
2. Phase 6 entirely (ship core + CLI + model; keep React on `master` as the UI and link to it)

**Do not cut Phase 5.** Phases 1, 3, 4, and 5 carry the signal.

---

## Open questions / blocked

### ✅ RESOLVED — the toolchain contradiction (was blocking)

Two of the four settled decisions were mutually incompatible: **"native Windows opam"** and
**"Core library *and* Bonsai UI"**. Phase 0 proved native Windows opam cannot host either
`Core` or `Bonsai` (§0.1b has the mechanism and the evidence).

**The human chose WSL2.** That keeps the plan exactly as approved and discards only the
native-Windows constraint. Nothing downstream of Phase 0 changes.

Kept for the record, because the reasoning is worth not re-deriving:

- **`Base` is still Jane Street's own library**, and `ppx_jane`, `ppx_expect`, and
  `base_quickcheck` — which carry most of the idiom signal — all work natively on Windows.
  A Base-only port would *not* have been a tutorial-grade fallback. It was a real option.
- `Fdeque` (used by `Undo_history`) lives in Core. A Base path needed a hand-rolled two-list
  deque — ~20 lines, and arguably reads *better* to a reviewer than importing one.
- **The plan's fallbacks A, B and C were all dead**, not just unattractive. Each assumed the
  core library builds locally. Fallback B (`js_of_ocaml` + `virtual_dom`, no Bonsai) fails
  too: `virtual_dom` has no win32 exclusion of its own but depends on `core`, so it schedules
  `base_bigstring.v0.16.0` — the exact package whose mingw compile failed. That is why this
  was a blocking question rather than a fallback selection.
- ⚠️ **`opam install --dry-run` compiles nothing.** It reports what the *solver* would
  schedule, and the solver happily schedules packages that then fail to build. A dry-run
  "Done." is not evidence that anything works. This misled the analysis once already —
  verify with a real install before believing a green dry-run.

### Non-blocking

- [ ] **Symbaroum to-hit formula** — `TN = Accurate_att + (10 − Defense_def)` clamped to `[1,19]`
      is a reconstruction, reasonably but not fully confident against the core book. Verify
      against the actual rules text if a copy is available. Prone and flanking modifiers are
      **unverified**. Until verified, `doc/model.md` must say so plainly.
- [ ] **Preset `defense` semantics** — resolve modifier-vs-target per preset in Phase 2. The
      golden test makes the reconciliation reviewable, but someone has to decide the rule.

---

## Assumptions to revisit

Stated so they do not quietly ossify into facts.

- **Focus fire** is assumed symmetrically for both sides. Bias is quantified in Phase 5 via the
  targeting-mode expect test, not asserted to be small.
- **Damage dice are estimated** from the `resistance` field, not data. Tagged
  `Estimated_from_resistance`, surfaced in `caveats`, editable in the UI.
- **250,000 states** is the DP/MC budget boundary. Chosen from a ~100 ms js_of_ocaml target;
  re-measure once the DP actually runs in a browser.
- **20,000 MC samples** gives `stderr ≤ 0.0035`. Fine for a 6-bucket label; revisit if the UI
  ever shows a raw probability to more than 2 significant figures.
- **200 rounds / `m_k < 1e-9`** power-iteration stopping rule.
- **Undo capacity 50**, `past` truncated to 20 for persistence, 1 MB serialization gate.
