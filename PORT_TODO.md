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
Phase:        3 COMPLETE - encounter, commands, undo. **Phase 4 is next and unblocked.**
Last session: 2026-08-23 - the headless combat engine. 15 new modules across
              `aggregates/` and `transitions/`, the six Phase 3 bug-ledger rows, a
              combat transcript that reads like a combat log, and 20 quickcheck
              properties. The library was reorganised into `scalars/`,
              `aggregates/`, `transitions/`, `data/` under
              `(include_subdirs unqualified)`, and `Command` was renamed `Action`
              because `Core.Command` shadows it. The property tests found one real
              port bug on their first run - see the decisions log.
              THE REPO IS at `~/symbaroum-combat-tracker` (ext4, in WSL2). The tree at
              `C:\Users\adnan\symbaroum-combat-tracker` is STALE at f7662d0 - never commit
              to it. Windows reaches the live repo at
              `\wsl.localhost\Ubuntu\home\adnan\symbaroum-combat-tracker`.
              Pinned: ocaml 5.2.0, core v0.16.2, bonsai v0.16.0 (**Proc style**),
              js_of_ocaml 5.9.1, dune 3.23.1, ocamlformat 0.29.0.
              `virtual_dom` pins the train to v0.16 - do not bump `core` to v0.17.
Next action:  Start **Phase 4 - codec, migration, CLI**. First task: `json_decoder.ml`,
              the applicative decoder, then `wire_v1.ml` (**frozen forever** - the
              deployed app has real user data in `sct.v1.*`). Note `normalization.ml`
              already landed in Phase 1, ahead of the plan, because `Encounter.create`
              needs it. Build from the repo root inside WSL. Green means all four of:
                dune build @fmt && dune build -p symbaroum && dune runtest && dune build
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
| 2026-08-22 | WSL was already present; only **Virtual Machine Platform** was disabled | `\wsl --install --no-distribution` enabled it and returned success, but the change **needs a reboot**. `HypervisorPresent` reads `True` while `VirtualizationFirmwareEnabled` reads `False` — that is the normal masked reading from inside a running hypervisor, **not** a firmware problem. Don't send anyone into the BIOS over it. |
| 2026-08-23 | ~~The repo stays canonical on Windows.~~ **REVERSED the same day — see the next row.** | Original reasoning, kept because the *mistake* is the instructive part: `/mnt/c` measured ~78x slower than ext4 for dune-shaped I/O, but a second tree looked like the bigger risk, so sources stayed on 9p with only `_build` moved off. **The error was benchmarking the filesystem without testing that the workflow actually functions on it.** Speed was never the problem. |
| 2026-08-23 | **The repo lives in ext4 at `~/symbaroum-combat-tracker`. `/mnt/c` is abandoned for this work.** | **`dune promote` silently no-ops on `/mnt/c`** — exit 0, no error, file unchanged. Proven by copying the identical tree to ext4, where it promotes first try. Not a permissions problem: `metadata,uid=1000,gid=1000` was added to `/etc/wsl.conf`, WSL restarted, ownership confirmed correct as `adnan:adnan` — **and promote still no-opped**. The cause is dune's sandbox/`.corrected` propagation over 9p, not ownership. This is disqualifying rather than annoying: ppx_expect promotion is the core loop, the plan leans on it for the 86-preset golden dump, the combat transcript, the decoder-error corpus and the difficulty table, and it **fails invisibly** — a green-looking run that silently discards the correction is worse than any slowdown. Windows reaches the repo at `\wsl.localhost\Ubuntu\home\adnan\symbaroum-combat-tracker`; measured ~1.5x slower reads, `git status` 41 ms, `grep` 68 ms — fine. Ratified by the human. |
| 2026-08-23 | `.gitattributes` forces `eol=lf` | Committing from Windows was CRLF-converting every OCaml source. With the tree readable from both sides, the two views must not be able to disagree, and ocamlformat/dune must never be handed CRLF. |
| 2026-08-23 | **`bonsai` pins the whole Jane Street train to v0.16** | Installing `virtual_dom` downgraded 55 packages (`core` v0.17.2 → v0.16.2, `base` v0.17.3 → v0.16.5, and the entire ppx set). v0.16 is perfectly idiomatic, so this costs nothing — but **do not "helpfully" bump `core` to v0.17**, because it will silently take the UI stack with it. |
| 2026-08-23 | Ubuntu **26.04 LTS**, not the plan's unstated assumption | Whatever `\wsl --install -d Ubuntu` shipped. Newer than expected; if an opam package needs an older glibc or a missing distro package, suspect this first. |
| 2026-08-23 | `sudo` needs a password → **`apt` steps are permanent human hand-offs** | Not fixable from a tool shell, and passwords must not be handled by one. Structure future sessions so all `apt` work is batched into a single command the human runs once, rather than discovered piecemeal. |
| 2026-08-23 | **Use `Core.String_id.Make`, not a hand-rolled `Identifiable.Make`** | The plan specified `Identifiable.Make` for the four ids. Core already ships `String_id`, which is `t = private string`, rejects the empty string and edge whitespace in `of_string`/`t_of_sexp`, is **generative** (so each application is a genuinely distinct type), and includes `Identifiable` and `Quickcheckable`. A hand-rolled version was written first and then deleted: it was shadowed by `Core.String_id` the moment `open! Core` was in scope, which is the language pointing out that the wheel already exists. Note `of_string` **raises**; the Phase 4 decoder lifts it with `Or_error.try_with` rather than every id module growing its own `create`. |
| 2026-08-23 | **`Resistance` has 6 bands, not the plan's 4** | Counted in `defaultMonsters.ts`: Weak 14, Ordinary 31, Challenging 20, Strong 14, **Mighty 4**, **Legendary 3**. The plan's damage prior mapped only the first four. The band is the *only* stand-in for weapon data the app does not record, so a missing band would have silently handed the seven nastiest creatures in the file a mild weapon. The prior is now Weak 1d6 / Ordinary 1d8 / Challenging 1d10 / Strong 1d12 / Mighty 1d12+1 / Legendary 1d12+2, stated in one place (`Attack_profile.damage_prior`) so `doc/model.md` can quote it and a reviewer can disagree with it in one edit. |
| 2026-08-23 | **`Armor.t` is a record `{ text; reduction }`, not the plan's bare variant** | The plan had `Unarmored \| Fixed of int \| Rolled of Dice.t \| Unparsed of string`, which loses the user's text for every value that *does* parse: `"Light (d4)"` becomes `Rolled 1d4` and renders back as `"1d4"`. Two costs. It is a visible regression against the React UI, which displays that string; and it breaks the codec round-trip property (`of_json (to_json w) = Ok (w, [])` with **no** normalizations) that Phase 4 wants to state in its strong form. Keeping `text` beside a parsed `reduction option` costs one field and buys both. `private` plus a single total `parse` stops the two disagreeing. `reduction = None` is the old `Unparsed`. |
| 2026-08-23 | **`Defense.t` stores the absolute target (`1..20`), and exposes both constructors** | Confirmed that the two preset spellings are the same quantity: Spring Elf `qui 13, defense -3` and Servant Daemon `qui 15, defense 15` are related by `modifier = 10 - target`, with `target = Quick`. So `of_modifier (-3)` and `of_target 13` both give `13`, while `of_modifier 15` **errors** -- exactly the forcing function the plan wanted, sited at the constructor. Phase 2 still needs the human ruling on the 29 unexplained presets. |
| 2026-08-23 | Added `bounded_int.ml`, a functor the plan did not name | `Attribute_value`, `Defense`, `Npc_count` and `Adjust_amount` are all "an int, but only these ones" and were shaping up as four near-identical modules. One functor gives all four `of_int`/`of_int_exn`/`of_int_clamped`/`to_int` plus a generator **routed through the smart constructor**, which is the plan's own rule for generators. `of_int_clamped` exists only for the import path, which reports the repair. |
| 2026-08-23 | `Dice.distribution` lands in Phase 1, not Phase 5 | The plan listed "parser + pmf" under `dice.ml` while putting `Pmf` in `model/`. Exact convolution over a support of at most `count * sides` values needs no `Pmf` type, so `Dice` returns `(int * float) list` and Phase 5's `Pmf.of_dice` will wrap it. Keeps `Dice` self-contained and gives the 2d6 closed-form anchor a home now. |
| 2026-08-23 | The pain threshold is checked against **post-armour, pre-clamp** damage | Two candidate quantities: what got through armour, and what the target could actually absorb before reaching zero. They differ only on a lethal blow, and a combatant at zero toughness is *down*, not prone -- so the cap would change no outcome while making the rule harder to state. Recorded in `pain_threshold.mli` and pinned by an expect test, so the choice is visible rather than accidental. |
| 2026-08-23 | `names.ml` in the plan is `name.ml` here | Singular reads better as a type module, and the type is `Name.t`. No other change. |
| 2026-08-23 | **RULED: the `defense` field is a MODIFIER, everywhere.** The roll-under target is `10 - defense`. | The human's call, and the data agrees. Counting all 86 presets, the modifier reading is legal for **74 of the 79** that carry the field; the 5 exceptions are the absolute-target spelling. It is also the only reading under which the *shipped player characters* are legal: Vigoi and Ymma store `defense: 0`, which as a modifier is a target of exactly 10 -- average, which is precisely what their "Placeholder stats" note means -- and as an absolute target is `0`, outside `Defense.t`'s range and the direct source of the `Infinity` in the old heuristic. This supersedes the earlier "29 unexplained" analysis, which was measuring residuals against `10 - qui` rather than asking whether `10 - defense` is a legal target. |
| 2026-08-23 | Where the modifier reading fails, **derive from Quick and record a `Caveat.t`** | 12 presets need this: 5 whose stored number is not a legal modifier, 7 with no `defense` field at all. Quick is present in **all 86** presets, so the fallback is always available. `defense_raw` keeps the discarded number and `Defense_reading.t` records which path ran, so the golden test prints the substitution. Worth noting what the dump shows: for 3 of the 5, stored and derived are the *same number*, because those presets store the target and `of_quick` recovers exactly it. |
| 2026-08-23 | **The ledger's "7 presets have all four stat fields null" was half wrong** | Counted directly: the 7 do have `toughness`, `defense`, `armor` and `painThreshold` null -- but their **attributes are complete**. `acc` is null in **0** presets and `qui` in **0**, not "79 of 86 carry acc". So every preset gets an attack profile, and only `toughness` is genuinely missing. 79 of 86 are modellable, the 7 blocked solely by toughness. |
| 2026-08-23 | The generated data module is a **dumb transcription**; all judgement lives in `Monster_preset.of_raw` | `monster_presets_data.ml` holds only wire types (`int option`, `string option`, `(string * int option) list`) so it can be diffed against the TypeScript line by line. Generated by `scripts/gen_monster_presets.py`. Splitting it from the hand-written `monster_presets.ml` also breaks the dependency cycle that a single generated module would have had with `Monster_preset.Raw`. |
| 2026-08-23 | `Character.t` is a **public record**, not `private` | The one deliberate exception to the rest of the library. `private` exists to force construction through a constructor that can reject an illegal combination -- and there is none here: every field is already a type that cannot hold a bad value, and no invariant relates two fields. Sealing it would buy nothing and cost the functional-update syntax the Phase 3 commands are written with. |
| 2026-08-23 | **The library is laid out in four directories under `(include_subdirs unqualified)`** | Forty modules in one flat directory was not the plan's target structure and was not readable; the human said so. They now sit in `scalars/`, `aggregates/`, `transitions/`, `data/`, and `test/` mirrors that layout for the same reason. `unqualified` keeps module names flat (`Symbaroum.Dice`, not `Symbaroum.Scalars.Dice`), so **no reference in any file had to change**. The layering is a review rule, not a compiler rule, and the `dune` file says so plainly rather than implying more than it delivers. The one boundary that *is* enforced is the package boundary, by `dune build -p symbaroum`. |
| 2026-08-23 | **`Command` is renamed `Action`** | `world.ml` failed to compile with "Unbound constructor Command.Add_character" -- not a missing module, a module that resolved to `Core.Command`, Core's command-line library. Same lesson as `String_id` in Phase 1: `open! Core` is a large namespace and the right response is to take Core's name seriously. `Action` also reads better where it is going, since a Bonsai `state_machine0` takes an action. |
| 2026-08-23 | **`Encounter.add` dedupes the incoming batch against itself, and `World.apply` rejects a batch with a repeated id** | A port bug, not a React one, and the **first thing the Phase 3 property tests found**. `add` filtered `additions` against the members already in the fight but not against itself, so a batch carrying one id twice raised out of `Map.of_alist_exn` on an empty encounter -- and on a non-empty one did something quieter and worse, leaving an id in the turn order that the member map did not have. Both layers now hold, for different reasons: `add` is total for any list, which is what the `Map` behind `Active` needs; and `apply` refuses the batch outright, because adding two NPCs when three were asked for is not a silence anyone wants. Documented by `test/aggregates/test_encounter.ml`. **This is the entry to point at when asked what property testing bought.** |
| 2026-08-23 | **`Normalization.to_string_hum` shifts turn numbers to one-based** | The fields hold what was on the wire, which is zero-based. The strings are read by a GM, who has never seen a zero-based turn -- the UI counts "turn 3 of 5". Reviewing the promoted expect output caught the message saying "moved to 2" beside a display reading "turn 3/3". The shift happens once, at the point where the number stops being data and starts being a sentence. `Name_counter_rebuilt` was reworded in the same pass: it said "for 1 monster types", which was ungrammatical and told the GM nothing; it now names the marks. |
| 2026-08-23 | **`Test_helpers.describe_action` lives in the tests, not in `Action`** | The transcript needs one line of English per action. Putting it in the library would have been inventing a requirement to justify a function: the library owes the UI a way to *perform* an action, not to narrate one, and nothing outside the tests wants this rendering. If Phase 7 turns out to want an undo label, move it then. |
| 2026-08-23 | Added `caveat.ml` and `initiative.ml`, neither in the plan | `Caveat.t` was scheduled for Phase 5, but Phase 2 is where most caveats are *discovered*, so it is one shared vocabulary rather than one type per phase. `Initiative.t` bounds `0 .. 99` a field the React app coerces with `Number(...) \|\| 0`, where a negative value silently reorders the descending sort. |
| 2026-08-23 | **`dune build -p symbaroum` does not catch dev-profile warnings** | `bounded_int.mli` passed the release build and failed `dune build` with warning 67 (unused functor parameter; fixed with `Make (_ : Arg)`). The release profile relaxes warnings, so a green `-p` build proves the core is JS-free and proves nothing about warnings. This is why "green" means all four checks and is never shorthand for any one of them. |

---

## Phase 0 — Toolchain spike  ⏱ ½ day — ✅ COMPLETE (2026-08-23)

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

Drive Ubuntu from a Windows tool shell with:

```
wsl.exe -d Ubuntu -- bash -s <<'SH'
  ...script...
SH
```

Piping the script on stdin avoids the nested-quoting mess that `bash -lc '...'` creates;
that mess silently produced empty output once already.

**Prerequisites (Windows side) — DONE:**

- [x] `\wsl --install --no-distribution` enabled Virtual Machine Platform (needed a reboot)
- [x] Rebooted; `\wsl --status` no longer complains about virtualisation
- [x] Ubuntu **26.04 LTS** installed, WSL2, kernel 6.18.33.2. 32 cores, 15 GB RAM, 955 GB free.

**Environment facts, measured:**

- `sudo` **requires a password**, so every `apt` step is a human hand-off — a non-interactive
  tool shell cannot do it, and must not try to handle the password.
- A fresh install has an **empty apt index**: `apt-cache policy opam` returns nothing until
  `apt update` has run. That is not "opam is unavailable".
- **`/mnt/c` is ~78× slower than the Linux filesystem** for the small-file I/O dune does:
  300 file creates took **465 ms** on `/mnt/c` vs **6 ms** on `~`. Measured, not assumed.

**Decided: the repo lives in the Linux filesystem at `~/symbaroum-combat-tracker`.**
`/mnt/c` is abandoned for this work. An earlier decision the same day said the opposite; it
was reversed after testing, and both rows are kept in the decisions log because the mistake
is the instructive part.

- **`dune promote` silently no-ops on `/mnt/c`.** Exit 0, no error, source file unchanged.
  The `.corrected` file never leaves dune's sandbox. This is not a permissions problem —
  `metadata,uid=1000,gid=1000` was added to `/etc/wsl.conf` and WSL restarted, ownership
  became a correct `adnan:adnan`, **and promote still no-opped**.
- That is disqualifying, not merely annoying: ppx_expect promotion is the inner loop, and it
  fails *invisibly*. A run that looks green while discarding the correction is worse than any
  slowdown. Speed was never the real issue — the 78x measurement was a red herring that
  nearly bought a broken layout.
- Windows can still read and write the tree at
  `\wsl.localhost\Ubuntu\home\adnan\symbaroum-combat-tracker` (~1.5x slower reads,
  `git status` 41 ms, `grep` 68 ms). Use that for any Windows-side editor or tool.
- **The stale checkout at `C:\Users\adnan\symbaroum-combat-tracker` is NOT canonical.** It
  stops at commit `f7662d0`. Do not commit there; do not `git pull` from it. If it is ever
  revived, re-clone from `origin` instead of trusting it.
- Use a **named global switch** (`sct`), not a local `_opam/`.
- `scripts/dune.sh` wraps the switch and `DUNE_BUILD_DIR` so none of this has to be
  re-remembered. `DUNE_BUILD_DIR` is now optional — `_build` in ext4 is fine — but the
  wrapper keeps it out of the tree anyway.

**⚠️ General lesson, worth applying to the rest of this port:** benchmarking a tool is not the
same as testing that it works. The filesystem decision was made from a clean 78x measurement
and was still wrong, because nothing had actually exercised `dune promote` on it.

**Inside Ubuntu:**

- [x] **HUMAN STEP (needs the sudo password):**
      `sudo apt update && sudo apt install -y build-essential m4 unzip pkg-config bubblewrap rsync curl git ca-certificates libgmp-dev zlib1g-dev opam`
      → opam **2.5.0**, gcc **15.2.0**. A second hand-off was needed later for Bonsai's
      depexts (`libffi-dev libssl-dev`); **batch these next time** — opam only reveals a
      depext when the solver reaches that package, and with no stdin it aborts (exit 10)
      rather than failing loudly.
- [x] `opam init --bare --yes --shell-setup` — **sandboxing stays ON.** The earlier note here
      said to pass `--disable-sandboxing` "because bubblewrap is unreliable under WSL2". That
      was received wisdom, and it is wrong on this kernel: bubblewrap was tested directly
      (`bwrap --unshare-all --ro-bind / / ... /bin/true`) and works, with
      `max_user_namespaces=63276`. Do not weaken the sandbox without re-testing.
- [x] `opam switch create sct 5.2.0 --yes --no-install`  ← named, not local
- [x] `eval $(opam env --switch=sct --set-switch)`
- [x] `opam install -y core ppx_jane base_quickcheck expect_test_helpers_core yojson ppx_yojson_conv`
      → **`core` v0.17.2 installed cleanly, including `base_bigstring` v0.17.0** — the exact
      package marked `available: os != "win32"` that killed the native Windows attempt.
      The toolchain reversal is vindicated here.
- [x] `opam install -y js_of_ocaml js_of_ocaml-ppx virtual_dom`
      → **this downgraded 55 packages to the v0.16 train** (`core` v0.17.2 → v0.16.2). See
      the decisions log: `virtual_dom` requires `core v0.16`, so v0.16 is the project's
      floor *and* ceiling. Do not bump `core` without rebuilding the UI stack.
- [x] `opam install -y bonsai`  ← **note: NOT `bonsai_web`**, which is a library inside this
      package, not a package. The importable library is `bonsai.web`. Kept as separate
      transactions so a Bonsai failure could not roll back and mask the core result.
      First attempt aborted (exit 10) on missing depexts `libffi-dev libssl-dev`, pulled in
      via `ctypes-foreign` and `async_ssl`. **Bonsai also downgraded `dune` 3.24.2 → 3.23.1.**
- [x] `opam install -y ocamlformat`; `.ocamlformat` pins `version=0.29.0` + `profile=janestreet`
- [x] **Resolved versions — these are the pinned reality of the project:**

      | package | version |
      |---|---|
      | ocaml | 5.2.0 |
      | core | v0.16.2 |
      | bonsai | v0.16.0 |
      | virtual_dom | v0.16.0 |
      | js_of_ocaml | 5.9.1 |
      | dune | 3.23.1 |
      | ocamlformat | 0.29.0 |
      | opam | 2.5.0 |

      Bonsai v0.16 is **Proc style**: `Bonsai.Computation.t` / `Bonsai.Value.t`, and
      `Start.start ~bind_to_element_with_id`. It is *not* the newer Cont style with an
      explicit `graph`. Follow `bonsai/examples/` from the v0.16.0 tag, never blog posts.
      Verified against the installed `~/.opam/sct/lib/bonsai/web/start.mli`.
- [x] `_build/` and `_opam/` gitignored; `.gitattributes` added forcing `eol=lf`

### 0.2 Prove it — ✅ ALL GREEN

- [x] `dune build` succeeds on a `lib/` + `test/` skeleton
      → `lib/symbaroum/version.{ml,mli}` (Core + `ppx_jane` deriving) and a `ppx_expect`
      test through `Expect_test_helpers_core`.
- [x] `dune runtest` green **and `dune promote` actually writes** — the check that exposed
      the `/mnt/c` problem. Never treat runtest alone as proof; promote must be exercised.
- [x] **A Bonsai hello-world builds and renders in a browser.** `web/main.ml` links
      `bonsai.web` *and* the `symbaroum` core library in one binary and interpolates values
      from the domain library into the DOM, so it proves the two coexist. Served from
      `_build/default/web/` and confirmed rendering with **no console errors**.
- [x] `dune build -p symbaroum` exits 0 — the core package really is JS-free.

**Bundle size, measured (the plan estimated ~1.5–4 MB raw / 400–900 KB gzipped):**

| profile | raw | gzip -9 |
|---|---|---|
| dev (default) | **23 MB** | 4.9 MB |
| **release** | **875 KB** | **288 KB** |

Release is *better* than the plan's estimate; dev is ~5x worse than its worst case. ⚠️ **Always
quote release numbers.** A future session that measures the dev build will conclude the bundle
is catastrophic and start cutting Core for Base — for nothing.

### 0.3 Exit criterion — ✅ MET, no fallback needed

**Phase 0 is complete.** All four checks green together:

```
dune build @fmt && dune build -p symbaroum && dune runtest && dune build
```

The fallbacks below were never needed and are kept only as history — WSL2 restored the plan
as approved, so `Core` and `Bonsai` are both in play.

~~Do not start Phase 1 until 0.2 is green or a fallback is chosen and recorded here.~~

**0.2 is green. Phase 1 is unblocked.**

Fallbacks, in order of preference:

- **A — recommended if Bonsai fails.** Core builds locally; `web/` builds only in GitHub
  Actions or an `ocaml/opam:debian-ocaml-5.2` container. Bonsai is never needed on Windows —
  edit, push, CI builds. Slow UI feedback loop, but Phases 1–5 are entirely headless anyway.
- **B.** Drop Bonsai, keep `js_of_ocaml` + `virtual_dom`. Much smaller dependency surface,
  `lib/` untouched, keeps most of the signal.
- **C.** Ship core + CLI; leave React on `master` as the UI.
- **D.** WSL2 (`\wsl --install -d Ubuntu`, ~20 min). Ruled out by the user; last resort only
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

## Phase 1 — Scalars and ids  ⏱ 1–2 days — ✅ COMPLETE (2026-08-23)

The most idiom-dense code in the repo, and the part a reviewer reads first. Each type kills
a specific illegal state that [`src/types.ts`](src/types.ts) permits.

**Landed: 17 modules, all with `.mli`s, and 10 test files.** All four checks green.

- [x] `ids.ml` — `Character_id`, `Combatant_id`, `Bestiary_id`, `Snapshot_id`, each a
      generative application of **`Core.String_id.Make`** (see the decisions log: the plan
      said `Identifiable.Make`, but Core already ships exactly this). `Map`/`Set`/`Table`
      come free, the empty string and edge whitespace are rejected, and the four types are
      genuinely distinct rather than four aliases of `string`.
      The `is_builtin` replacement for `CharacterCard.tsx:112` belongs to `Character.t` in
      **Phase 3** — an id carries no data, which is the whole point. `test_ids.ml` records
      that the smuggled property is gone.
- [x] `bounded_int.ml` — **not in the plan.** The functor behind the four bounded ints.
- [x] `attribute.ml` — the 8 attributes as a variant with `Map`/`Set`, plus the wire keys
      (`acc`, `cun`, …) and UI labels (`ACC`, …)
- [x] `attribute_value.ml` — `private int` bounded `1..20`, with `modifier t = 10 - raw`
- [x] `attributes.ml` — *key-total* `Attribute_value.t option Attribute.Map.t`.
      **`normalizeAttributes`, `cloneAttributes` and `areAttributesEqual` in
      [`combatLogic.ts`](src/utils/combatLogic.ts) all vanish** — `empty` is the one
      spelling of "nothing known", copying is free, and `equal` is derived. Pinned by
      `test_attributes.ml`.
- [x] `dice.ml` — `{ count; sides; modifier }`, total parser, `to_string`, bounds, `mean`,
      exact `distribution` by convolution, and `roll` over `Splittable_random`.
      The 2d6 closed-form anchor (11 outcomes, 1/36 … 6/36 … 1/36) is in `test_dice.ml`.
- [x] `armor.ml` — `private { text; reduction }` with a **total** parser; `reduction = None`
      is the plan's `Unparsed`. Parses every spelling in the shipped data: `""`, `"0"`,
      integers, `1D4`/`1D8`, and the parenthesised PC form `Light (d4)`. See the decisions
      log for why the raw text is kept.
- [x] `defense.ml` — `private int` in `1..20`, storing the **absolute target**, with
      `of_target` and `of_modifier` both exposed so a call site must say which spelling it
      is reading. The Phase 2 reconciliation is still open — see below.
- [x] `toughness.ml` — `private { current; max }` with `0 <= current <= max`.
      `damage` and `heal` return the amount **actually** applied, which is what the pain
      threshold and the model both need.
- [x] `pain_threshold.ml` — `No_threshold | Every_hit | At_least of int`, and
      `is_exceeded ~damage` taking post-armour damage rather than the raw number typed into
      the box. Bug-ledger row `test_pain_threshold_uses_damage_dealt` lives here.
- [x] `resistance.ml` — **not in the plan**, and it has **6** bands, not 4
- [x] `attack_profile.ml` — carries `source : From_data | Estimated_from_resistance of
      Resistance.t`, and `damage_prior` states the estimate in one place
- [x] `monster_type.ml`, `name.ml` (the plan called the latter `names.ml`)
- [x] `round.ml` — `private int >= 1`, with `prev` flooring at 1. The `succ`/`prev`
      asymmetry is asserted rather than left as folklore.
- [x] `npc_count.ml`, `adjust_amount.ml`
- [x] `Base_quickcheck` generators for every scalar, routed **through the smart
      constructors** so only legal values are generated
- [x] `dune runtest` green

### Properties proven in Phase 1

`modifier = 10 - raw` · a generated attribute block is always key-total · a dice
distribution sums to 1 and spans exactly `min_roll .. max_roll` · a roll always lands
inside those bounds · `Armor.parse` is total on arbitrary strings · `of_modifier` inverts
`to_modifier` · `0 <= current <= max` survives any sequence of damage and healing, and
`max` never moves · `prev (succ r) = r` everywhere, and `succ (prev r) = r` except at the
floor, where the exception is asserted explicitly.

**Exit:** ~15 modules with full `.mli`s, generators, tests green. ✅

---

## Phase 2 — Data port + normalization  ⏱ 1 day — ✅ COMPLETE (2026-08-23)

- [x] `monster_preset.ml` + `.mli` — plus `caveat.ml` and `initiative.ml`, neither in the plan
- [x] Generate `monster_presets_data.ml` from [`src/data/defaultMonsters.ts`](src/data/defaultMonsters.ts)
      (**86** presets) via [`scripts/gen_monster_presets.py`](scripts/gen_monster_presets.py),
      with the hand-written `monster_presets.ml` as the seam that normalizes them
- [x] Port [`src/data/defaultCharacters.ts`](src/data/defaultCharacters.ts) → `default_roster.ml`,
      which needed `character.ml` brought forward from Phase 3
- [x] **Golden expect test dumping all 86 normalized presets in one `[%expect]`** —
      [`test/test_monster_presets.ml`](test/test_monster_presets.ml). Each row reads
      `stored -> target (how)`, so the Defense reconciliation is a line-by-line diff.
- [x] `dune runtest` green

### The two data problems — RESOLVED

**1. The `defense` field is a modifier.** Ruled by the human, and the data agrees. See the
decisions log for the full argument; the short version is that `target = 10 - defense` is
legal for 74 of the 79 presets that carry the field, and it is the *only* reading under which
the four shipped player characters are legal at all.

| reading | count |
|---|---|
| `Stored_modifier` — the stored number used as-is | 74 |
| `Derived_from_quick` — stored number illegal (5) or absent (7) | 12 |
| `Unknown` — neither available | 0 |

**2. Damage dice are still estimated**, from the `resistance` band, tagged
`Estimated_from_resistance`, and surfaced as `Caveat.Damage_die_estimated`. Unchanged from the
plan except that the estimate now reaches **all 86** presets rather than 79 — see the third
decisions-log row above; every preset has a complete attribute block, so every preset gets an
Accurate score. **7** presets remain unmodellable, blocked solely by a missing `toughness`.

## Phase 3 — Encounter, commands, undo  ⏱ 2–3 days — ✅ COMPLETE (2026-08-23)

Stands alone as a portfolio piece: a headless combat engine with a transcript test and the
full bug ledger.

- [x] `character.ml`, `roster.ml`, `combatant.ml` — `character.ml` landed early, in Phase 2
- [x] `turn_order.ml` — **nonempty zipper** `{ before; current; after }`. `move` tracks the
      cursor arithmetically rather than by `phys_equal`, so it stays correct when two entries
      compare equal — see [`test_turn_order.ml`](test/aggregates/test_turn_order.ml)
- [x] `name_counter.ml` — high-water marks per monster type, **stored in the encounter**
- [x] `encounter.ml` — the type that matters most, exactly as sketched below
- [x] `Invariant.S` implemented for `Encounter.t` **and** for `World.t`, whose extra clause is
      the cross-store one: a combatant may not point at a roster entry that is gone
- [x] `bestiary.ml`, `bounded_list.ml`, `encounter_archive.ml`
- [x] `npc_draft.ml`, `member_patch.ml`, `character_patch.ml`
- [x] ~~`command.ml`~~ **`action.ml`** — 17 transitions, currently closures in
      [`src/App.tsx`](src/App.tsx). Renamed because `Core.Command` shadows it; see the
      decisions log
- [x] `event.ml` — `Pain_threshold_exceeded | Combatant_downed | Round_completed | Encounter_archived | Encounter_restored | Data_normalized | Rejected`
- [x] `world.ml` — `World.apply : t -> Action.t -> t * Event.t list`, **pure and total**.
      Effects are *arguments*: an action that needs a fresh id or the clock carries them
- [x] `undo_history.ml` — bounded zipper backed by `Fdeque`, with `push ~key` for coalescing
- [x] **Combat transcript expect test** — [`test_world.ml`](test/transitions/test_world.ml).
      Three shipped PCs against two Robbers off the preset list, thirteen actions, printed
      state and events after each. It reads like a combat log, which was the criterion
- [x] Every bug-ledger row that belongs to this phase — all six
- [x] `dune runtest` green

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
**no `slice(-50)`**, so ping-pong grows it unboundedly; and the dedupe at line 83 is JS
*reference* equality, which never fires for a fresh object literal — so every keystroke in a
note field burns a slot and 50 entries evaporate in one sentence.

### Properties proven in Phase 3

Generated as **scripts, not states**: [`test_generators.ml`](test/test_generators.ml) produces
an `Action.t list` drawn against small fixed id pools, and the properties fold it over
`World.initial`. That sidesteps the question of how to generate a `private` type with no public
constructor, and it asks the question that matters — not "is this world consistent" but "does it
stay consistent after anything a user can do". Ids come from a small pool on purpose: freely
generated ids produce a script that is almost entirely `Rejected`, which exercises the rejection
path thoroughly and everything else not at all.

| where | property |
|---|---|
| [`test_world_properties.ml`](test/transitions/test_world_properties.ml) | `World.invariant` holds after **every** step, not merely at the end |
| " | `Encounter.current` is `None` exactly when the fight is empty; the turn index is always in range |
| " | no combatant id appears twice; auto-generated names are pairwise distinct |
| " | `0 <= current <= max` after any sequence of adjustments |
| " | only `Next_turn`/`Prev_turn` move the round, by at most one, and it is never below 1 |
| " | `Prev_turn ∘ Next_turn = id`, **except** at `(round 1, index 0)` where the floor bites — asserted explicitly rather than left as folklore |
| " | `Move_member` changes neither the cast nor whose turn it is |
| " | `Sort_by_initiative` keeps the cast and the round, and leaves initiative descending |
| " | a `Rejected` action leaves the world exactly as it was |
| [`test_turn_order.ml`](test/aggregates/test_turn_order.ml) | the cursor is always a real position, and `to_list` agrees with `current` at it |
| " | `prev ∘ next = id` **everywhere** — the zipper itself has no floor; the floor is `Round.prev` |
| " | `next` wraps exactly when it returns to index 0 |
| " | `move` permutes and preserves whose turn it is; removing someone else keeps the turn |
| [`test_undo_history.ml`](test/transitions/test_undo_history.ml) | `depth` never exceeds capacity under any push/undo/redo interleaving |
| " | `redo ∘ undo = id`; `can_undo`/`can_redo` agree with `undo`/`redo`; an uncoalesced push is undone by exactly one undo |

The generated keys are drawn from a set of three rather than being free strings, because with
free strings the same key twice in a row essentially never happens and the coalescing path would
go untested **while looking tested**.

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
All six Phase 3 rows live in one file, [`test_bug_ledger.ml`](test/test_bug_ledger.ml), so the
README table can be lifted from it directly.

| ✓ | test | bug |
|---|---|---|
| [x] | `test_npc_naming_survives_removal` | live count → duplicate "Goblin 3" ([App.tsx:231](src/App.tsx:231)) |
| [x] | `test_npc_preset_attributes_are_kept` | `addNpc` silently drops `attributes` ([App.tsx:246](src/App.tsx:246)) |
| [x] | `test_sort_preserves_round` | [App.tsx:340](src/App.tsx:340) resets round to 1 |
| [x] | `test_delete_character_repairs_cursor` | [App.tsx:114](src/App.tsx:114) prunes members, leaves `turnIndex` |
| [x] | `test_redo_respects_capacity` | `redo` never slices `past` ([usePersistentHistory.ts:112](src/hooks/usePersistentHistory.ts:112)) |
| [x] | `test_typing_a_note_costs_one_undo` | reference-identity dedupe ([usePersistentHistory.ts:83](src/hooks/usePersistentHistory.ts:83)) |
| [ ] | `test_import_rejects_unknown_version` | `version` never compared to 1 ([exportImport.ts:44](src/utils/exportImport.ts:44)) |
| [ ] | `test_import_repairs_out_of_range_turn_index` | blind cast after the version check |
| [ ] | `test_difficulty_with_zero_defense_party` | `npcDefense / pcDefense` → `Infinity` ([EncounterPanel.tsx:19](src/components/panels/EncounterPanel.tsx:19)) |
| [x] | `test_pain_threshold_uses_damage_dealt` | compares raw input, ignoring armour ([App.tsx:411](src/App.tsx:411)). Landed in Phase 1 as [`test/test_pain_threshold.ml`](test/test_pain_threshold.ml); see the decisions log for why the threshold uses post-armour, pre-clamp damage. |

**On the ninth row** — the divide-by-zero is reachable with stock data but narrower than it
first looks. The four default PCs have defense 8, 3, 0, 0, averaging to 2.75 → `Math.round` → 3,
so a **full party never triggers it**. It fires when the PCs *in the encounter* round to 0
average defense — e.g. adding only Vigoi and/or Ymma. **Write the test to that case.**

---

## Illegal-state table  → becomes the README table in Phase 8

| TypeScript state that is representable today | OCaml type that deletes it | Test |
|---|---|---|
| `{members: [], turnIndex: 5, round: 0}` | `Encounter.t` = `Empty \| Active` with a nonempty `Turn_order.t` zipper | ✅ [`test_bug_ledger.ml`](test/test_bug_ledger.ml) — and the quickcheck cursor-validity property |
| Sort silently resets `round` to 1 | `Round.t` lives outside `Turn_order.t`, so `sort_by` cannot reach it | ✅ [`test_bug_ledger.ml`](test/test_bug_ledger.ml) — and a property saying only the turn commands move the round |
| `{source:'npc', refId:'pc_x'}` | `Allegiance = Player_character of Character_id.t \| Non_player of {...}` | ✅ (compile-time) plus [`test_bug_ledger.ml`](test/test_bug_ledger.ml), where the total record forces the dropped `attributes` to be supplied |
| "no attributes" spelled `undefined` / `null` / `{}` | key-total `Attribute_value.t option Attribute.Map.t` | ✅ [`test_attributes.ml`](test/scalars/test_attributes.ml) — deletes `normalizeAttributes`, `cloneAttributes` and `areAttributesEqual` |
| `painThreshold: 0` vs `null` meaning different things | `No_threshold \| Every_hit \| At_least of int` | ✅ [`test_pain_threshold.ml`](test/scalars/test_pain_threshold.ml) |
| `toughness` is current and max at once; unclamped on import | `private { current; max }` with `0 <= current <= max` | ✅ [`test_toughness.ml`](test/scalars/test_toughness.ml) — quickcheck over any damage/heal sequence |
| `Partial<Combatant>` shallow-merges any field to any value | `Member_patch.t` explicit variant | ✅ (compile-time) — and `field` is what makes undo coalescing possible at all |
| `armor: string` never parsed | `private { text; reduction : Reduction.t option }`, total parser | ✅ [`test_armor.ml`](test/scalars/test_armor.ml) — totality property over arbitrary strings |
| Duplicate combatant ids | `Combatant.t Combatant_id.Map.t` | ✅ [`test_encounter.ml`](test/aggregates/test_encounter.ml) — the import path renames rather than drops, and a property says no id is ever in the fight twice |
| Four different identities all typed `string` | four generative `Core.String_id.Make` applications | ✅ (compile-time) [`test_ids.ml`](test/scalars/test_ids.ml) |
| `round: 0`, produced by the empty state and every import path | `Round.t = private int >= 1` | ✅ [`test_round.ml`](test/scalars/test_round.ml) |
| Attribute scores unbounded; `defense`, NPC count and adjustment bounds enforced only by input widgets | `Bounded_int.Make` — the bound is a property of the type | ✅ [`test_bounds.ml`](test/scalars/test_bounds.ml) |
| An estimated damage die indistinguishable from recorded data | `Attack_profile.Source.t = From_data \| Estimated_from_resistance of Resistance.t` | ✅ [`test_attack_profile.ml`](test/scalars/test_attack_profile.ml) |
| `version: 7` accepted and blind-cast | explicit version dispatch, error on unknown | `test_import_rejects_unknown_version` |
| `damageInputs` grows without bound | `Bonsai.assoc` per-row state | (structural; note in README) |
| An unbounded `past` after undo/redo ping-pong | capacity travels with the `Undo_history.t`, and one private `trim` is the only writer | ✅ [`test_bug_ledger.ml`](test/test_bug_ledger.ml) — and a property over any interleaving |
| Every keystroke burns an undo slot (reference-identity dedupe) | `push ~equal ~key` — structural equality, and a key naming the field | ✅ [`test_bug_ledger.ml`](test/test_bug_ledger.ml) |
| `id.startsWith('pc_default_')` as a data property | `is_builtin : bool` field on the record; ids are `Core.String_id` and carry nothing | ✅ landed with `character.ml` in Phase 2; [`test_ids.ml`](test/scalars/test_ids.ml) records why an id carries nothing |

---

## Testing strategy

**`ppx_expect` for anything a human should read the output of.** Use
`Expect_test_helpers_core.print_s [%sexp (x : t)]`.

**Golden dumps:**
- All 86 normalized presets in one `[%expect]` (Defense reconciliation as a reviewable diff)
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
- [x] **Preset `defense` semantics — RULED 2026-08-23. Closed.** The field is a **modifier**;
      the target is `10 - defense`. Applied uniformly to presets, player characters and the
      UI defaults. See the decisions log and Phase 2 above.

      The 2026-08-22 analysis that reported "29 unexplained" was asking the wrong question. It
      measured the stored number against `10 - qui` and against `10 - qui + armor` and counted
      residuals. But the port does not need `defense` to *agree* with `qui` — it needs
      `10 - defense` to be a legal roll-under target. It is, for 74 of the 79 presets that
      have the field. Kept here because the mistake is the instructive part: a residual
      analysis answers "is this consistent with my model of how it was written", which is a
      historical question, when the question that mattered was "is this usable".

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
