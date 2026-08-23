# Symbaroum Combat Tracker — OCaml port

[![CI](https://github.com/AdnanDervisevic/symbaroum-combat-tracker/actions/workflows/ci.yml/badge.svg?branch=ocaml-port)](https://github.com/AdnanDervisevic/symbaroum-combat-tracker/actions/workflows/ci.yml)

An initiative and combat tracker for the [Symbaroum](https://frialigan.se/en/games/symbaroum/)
RPG, ported from React + TypeScript to **OCaml + Bonsai**, compiled to JavaScript
with js_of_ocaml.

The React original is on [`master`](../../tree/master) and is live at
[symbaroum-combat-tracker.vercel.app](https://symbaroum-combat-tracker.vercel.app/).
This branch is the same app with two things added that a transcription would not
have: **a real probability model in place of a made-up difficulty heuristic**, and
**a type design that deletes about twenty states the TypeScript version can
represent** — several of which it actually produces.

---

## The probability model

The original rates encounter difficulty like this
([`EncounterPanel.tsx:5-35`](../../blob/master/src/components/panels/EncounterPanel.tsx)):

```ts
const score = (toughnessRatio * 0.5) + (numbersRatio * 0.3) + (defenseRatio * 0.2);
```

Those weights are derived from nothing. Worse, `defenseRatio` divides by the
party's average defence, which rounds to zero for a party of the two shipped
characters whose notes read "Placeholder stats" — so with stock data the
heuristic returns `Infinity`.

The replacement computes the **exact probability that the party is the side left
standing**, by absorbing-state analysis:

```
$ dune exec -- bin/symbaroum_cli.exe analyze doc/samples/v1-export.json
...
Difficulty
  Easy -- 92% win, expect 0.4 casualties, median 6 rounds (1 caveat(s))
  p(party wins) 0.9181, in [0.9181, 0.9181]
  50% of fights end by round 6
  90% of fights end by round 10
  method: exact, over 1845 states in 38 rounds (unresolved mass 6.9e-10)
  caveats:
    - No weapon recorded for this combatant; an average attack was assumed.
```

**The trick is the state reduction.** The honest state of a fight is the whole
toughness vector — 4 PCs and 6 NPCs at 10 toughness each is 11¹⁰ ≈ 2.6 × 10¹⁰
states. Under focus fire it collapses to two integers per side, because the
enemies before the current target are dead and the ones after it are untouched:

```
state = (i, h_A, prone_A, j, h_B, prone_B)          9,801 states
```

Prone costs a factor of four rather than 2^(n_A+n_B), so the app's signature
mechanic is modelled **exactly** rather than dropped.

Three things about it worth more than the number itself:

- **The error bar is a proof, not a heuristic.** Power iteration means the mass
  not yet absorbed after *k* rounds is an exact upper bound on how far the answer
  can still move, so the returned interval is a theorem.
- **The load-bearing assumption is measured, not asserted.** Focus fire is what
  makes exactness possible. A Monte Carlo oracle runs the same fights under
  uniform and weakest-first targeting to say what it costs: up to **11 points**,
  and largest exactly for a fight already in progress. That number is in the doc
  rather than a claim that the bias is small.
- **Everything it had to guess is attached to the answer.** The app records no
  weapon data for anybody, so damage dice are estimated from the creature's
  resistance band — and every verdict carries a `Caveat.t list` saying so. A
  number computed from an invented die is not the same kind of number as one
  computed from a statblock.

**→ [`doc/model.md`](doc/model.md)** derives all of it: the reduction, the rules
reconstruction (including which parts are *not* verified against the core book),
the closed-form anchors, and the DP-versus-simulation agreement table.

---

## Illegal states the TypeScript permits, and the types that delete them

This is the other half of the point. Each row is a state
[`src/types.ts`](../../blob/master/src/types.ts) can represent; most are states
the app actually produces.

| Representable in TypeScript | The OCaml type that deletes it | Test |
|---|---|---|
| `{members: [], turnIndex: 5, round: 0}` — produced by four separate paths | `Encounter.t = Empty \| Active` with a nonempty `Turn_order.t` zipper: the cursor is a position *in* the structure | [`test_bug_ledger.ml`](test/test_bug_ledger.ml) + a cursor-validity property |
| Sorting by initiative silently resets `round` to 1 | `Round.t` lives *outside* `Turn_order.t`, so `sort_by` has no round in scope to reset | [`test_bug_ledger.ml`](test/test_bug_ledger.ml) |
| `{source: 'npc', refId: 'pc_x'}` — needs a runtime guard | `Allegiance = Player_character of Character_id.t \| Non_player of Monster_type.t option` | compile-time; the total record also *forces* the dropped `attributes` fix |
| "no attributes" spelled `undefined`, `null` **and** `{}` | key-total `Attribute_value.t option Attribute.Map.t` | [`test_attributes.ml`](test/scalars/test_attributes.ml) — deletes `normalizeAttributes` and `areAttributesEqual` outright |
| `painThreshold: 0` and `null` mean opposite things, and only a comment says so | `No_threshold \| Every_hit \| At_least of int` | [`test_pain_threshold.ml`](test/scalars/test_pain_threshold.ml) |
| `toughness: number` is current *and* maximum; clamped in three view-layer places and none on the import path | `private { current; max }` with `0 <= current <= max` | [`test_toughness.ml`](test/scalars/test_toughness.ml) — quickcheck over any damage/heal sequence |
| `Partial<Combatant>` shallow-merges *any* field to *any* value | `Member_patch.t`, an explicit variant | compile-time; its `field` is also what makes undo coalescing possible |
| `armor: string`, never parsed anywhere | `private { text; reduction : Reduction.t option }` with a total parser | [`test_armor.ml`](test/scalars/test_armor.ml) — totality over arbitrary strings |
| Duplicate combatant ids | `Combatant.t Combatant_id.Map.t` | [`test_encounter.ml`](test/aggregates/test_encounter.ml) — import renames rather than drops |
| Four different identities all typed `string` | four generative `Core.String_id.Make` applications | compile-time, [`test_ids.ml`](test/scalars/test_ids.ml) |
| `round: 0`, produced by the empty state and every import path | `Round.t = private int >= 1` | [`test_round.ml`](test/scalars/test_round.ml) |
| Attribute scores unbounded; NPC count and adjustment bounds enforced by input widgets only | `Bounded_int.Make` — the bound is a property of the type | [`test_bounds.ml`](test/scalars/test_bounds.ml) |
| An estimated damage die indistinguishable from recorded data | `Attack_profile.Source.t = From_data \| Estimated_from_resistance of _` | [`test_attack_profile.ml`](test/scalars/test_attack_profile.ml) |
| `version: 7` accepted and blind-cast (`version` is never compared to `1`) | explicit version dispatch; unknown versions are refused by name | [`test_codec.ml`](test/codec/test_codec.ml) |
| An import that fails reports one problem and stops | an applicative decoder: both halves of every `apply` run, so errors concatenate | [`test_codec.ml`](test/codec/test_codec.ml) — one file, four problems, four JSON paths |
| Undo/redo ping-pong grows `past` without bound (three of four writers slice it) | capacity travels with the value; one private `trim` is the only writer | [`test_bug_ledger.ml`](test/test_bug_ledger.ml) + a property over any interleaving |
| Every keystroke burns an undo slot — the dedupe is JS *reference* equality against a fresh object literal, so it never fires | `push ~equal ~key`: structural equality, and a key naming the field | [`test_bug_ledger.ml`](test/test_bug_ledger.ml) |
| `damageInputs` leaks an entry for every combatant that ever existed | `Bonsai.assoc` creates and destroys row state *with* the row — there is no root-level map to leak into | structural |
| `id.startsWith('pc_default_')` — a data property smuggled into an identifier, asked on every render | an `is_builtin : bool` field; the prefix is read exactly once, at the v1 migration boundary | [`test_ids.ml`](test/scalars/test_ids.ml) |
| Difficulty divides by the party's average defence, which is `0` for the shipped placeholders | an absorption probability; `Defense.t` cannot be zero and nothing in the model is a ratio | [`test_difficulty.ml`](test/model/test_difficulty.ml) |

**[`test/test_bug_ledger.ml`](test/test_bug_ledger.ml) is one test per fixed bug,
with the React behaviour written down in a comment above the corrected
`[%expect]`.** Three of them have no corrected line to show, which is the point:
the round is not reachable from `sort_by`, there is no turn index to leave
dangling, and the capacity trim is inside the one function both `push` and `redo`
go through.

---

## What the tests found

The port is about 4,900 lines of tests against an original with none. They were
not decoration — a partial list of what they caught:

| found by | bug |
|---|---|
| a property, first run | `Encounter.add` deduplicated the incoming batch against the members already in the fight but not against itself: raised on an empty encounter, and silently corrupted a non-empty one |
| the decoder-totality property | `Json_decoder.int` accepted an integral float using `Float.to_int`, which *raises* outside the int range — `{"version": 1e287}` crashed the reader |
| the round-trip property | unparsed armour was being reported as an import *repair* when nothing had been changed, so a clean load announced corrections it had not made |
| the round-trip property | an archived encounter may legitimately hold a player character deleted afterwards; demoting it at load time was rewriting history |
| the round-trip property | `name_counter = []` meant both "no counter, rebuild it" and "the counter is empty" |
| the js_of_ocaml build | **`int` is 32 bits under js_of_ocaml**, and JavaScript epoch milliseconds are ~1.7×10¹². Every native test passed; the browser would have been silently wrong |
| running it in a browser | a `Bonsai.state` setter takes the new value, so it closes over the old one — ticking four characters quickly put one in the fight. It is a `state_machine0` now |
| measuring, not assuming | `dune build -p symbaroum` builds *every stanza in the package*, so the CLI sitting in it made the "core has no Unix or JS dependency" check green and vacuous. The CLI has its own package |

---

## Design notes worth the detour

**Effects are arguments, not results.** `World.apply : t -> Action.t -> t * Event.t list`
is pure and total: an action that needs a fresh id or the clock carries them. So a
whole fight is a `list` a test can write down, and
[`test_world.ml`](test/transitions/test_world.ml) replays one and prints it —
which reads like a combat log because it is one.

**Events are returned, not fired.** The React version needs a toast when a blow
exceeds a pain threshold, and the only place it knows is inside a `setState`
updater — which must be pure and which React may call twice. So it declares a
mutable ref outside, writes to it from inside the mapper, reads it after
`setEncounter` returns, and flushes through `setTimeout(…, 0)` to dodge a
batching problem. Returning the events makes the reducer pure, the toast text
testable, and the timer unnecessary.

**Derive the writer, hand-write the reader.** Encoding is total, decoding is
partial. More to the point, a derived `of_yojson` on the domain types would
reintroduce every illegal state above — a deriver constructs records directly, so
it cannot route through `Toughness.create` or `Encounter.create`. The trust
boundary is exactly where smart constructors matter most, so it is exactly where
derivation is wrong. The decoder is an **applicative and not a monad**, which is
what makes error accumulation possible rather than a feature bolted on:
[`json_decoder.mli`](lib/symbaroum/codec/json_decoder.mli) writes `Let_syntax`
out by hand so the *absence* of `bind` is visible in the interface.

**Normalization is total and reported.** Only structurally impossible input is an
error. Everything else is repaired and handed back as a `Normalization.t list`,
so the import can say "loaded, 3 corrections applied" *and* a test can assert
exactly which three.

**Bundle size, honestly.** 1,089 KB raw, **349 KB gzipped**. `Base` instead of
`Core` would shrink it meaningfully, but Core idiom is part of the point here, so
it stays — and the number is measured in CI rather than estimated.

---

## Layout

```
lib/symbaroum/            the domain core — no js_of_ocaml, no core_unix
  scalars/                bounded ints, dice, armour, defence, ids
  aggregates/             combatant, turn_order (the zipper), encounter, roster
  transitions/            action, event, world (the reducer), undo_history
  codec/                  json_decoder, wire_v1 (frozen), wire_v2, migrate
  model/                  pmf, hit_chance, attrition_dp, combat_sim, difficulty
  data/                   86 monster presets, generated from the TypeScript
test/                     ppx_expect + Base_quickcheck, mirroring the above
bin/symbaroum_cli.ml      read / analyze / convert / demo, without a browser
web/                      Bonsai, reusing src/App.css verbatim
doc/model.md              the derivation
PORT_TODO.md              the working ledger: decisions, and why
```

Every module has an `.mli` except the generated data. `model/` depends on the
scalars, `Combatant` and `Encounter` and on nothing in `transitions/` or
`codec/`, so the DP is testable on its own.

---

## Building it

Needs opam and OCaml 5.2. On Windows, this wants WSL2 — `dune promote` silently
no-ops on the `/mnt/c` 9p mount, which is disqualifying for a repo whose test
suite is built on expect tests.

```bash
opam switch create sct 5.2.0 && eval $(opam env --switch=sct)
```

```bash
opam install . --deps-only --with-test
```

```bash
dune build @fmt && dune build -p symbaroum && dune runtest && dune build
```

Those four are what "green" means, and CI runs exactly them. The second is a
claim rather than a convention: it proves the domain core carries no JavaScript
runtime and no C stubs.

The headless front end needs no browser:

```bash
dune exec -- bin/symbaroum_cli.exe analyze doc/samples/v1-export.json
```

And the site is four static files — nothing runs on the host:

```bash
./scripts/build_site.sh && (cd site && python3 -m http.server 8000)
```

CI publishes that to GitHub Pages. `vercel.json` is set up for the alternative,
but pointing the live URL at this branch is a deliberate step and not something
a green build should do on its own.

---

## Status

Ported and green: the domain, the codec with a v1 migration, the probability
model, and the Bonsai UI at feature parity. `master` and its live deployment are
untouched.

Known gaps are tracked in [`PORT_TODO.md`](PORT_TODO.md). The two worth naming
here: the Symbaroum to-hit reconstruction is not verified against the core book
and its prone and flanking modifiers are guesses (`doc/model.md` says so
plainly), and the v1 round-trip is exercised against a hand-built export rather
than one taken from the live site.
