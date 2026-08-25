# Symbaroum Combat Tracker — OCaml port

An initiative and combat tracker for the [Symbaroum](https://frialigan.se/en/games/symbaroum/)
RPG, ported from React + TypeScript to **OCaml + Bonsai**, compiled to JavaScript
with js_of_ocaml.

The React original is on [`master`](../../tree/master) and is live at
[symbaroum-combat-tracker.vercel.app](https://symbaroum-combat-tracker.vercel.app/).
This branch is the same app with **a type design that deletes about twenty states
the TypeScript version can represent** — several of which it actually produces —
and with one of the original's features deliberately removed rather than ported.

---

## The difficulty score is gone

The original rates encounter difficulty like this
([`EncounterPanel.tsx:5-35`](../../blob/master/src/components/panels/EncounterPanel.tsx)):

```ts
const score = (toughnessRatio * 0.5) + (numbersRatio * 0.3) + (defenseRatio * 0.2);
```

Those weights are derived from nothing, and `defenseRatio` divides by the party's
average defence — which rounds to zero for the shipped placeholder characters, so
with stock data the heuristic returns `Infinity`.

So the port replaced it with a real one: an absorbing-state Markov chain giving
the exact probability the party is the side left standing, solved by power
iteration, with a Monte Carlo oracle to cross-check it and to price its one
load-bearing assumption. The state reduction was the good part — the honest state
of a fight is the whole toughness vector, 11¹⁰ ≈ 2.6 × 10¹⁰ states for 4 PCs
against 6 NPCs, and under focus fire it collapses to two integers per side
because everyone before the current target is dead and everyone after is
untouched. 9,801 states, prone modelled exactly, and an error bar that is a
theorem rather than an estimate: the probability mass not yet absorbed after *k*
rounds is an exact upper bound on how far the answer can still move.

**It has been deleted, and that is the honest outcome.** Not because the
arithmetic was wrong — it was rigorous, and the tests anchored it against
closed-form cases — but because of what it was rigorous *about*. This app records
no weapon data for anybody: player characters have no attack at all, and monster
damage dice were invented from the creature's resistance band. Damage is the
single largest lever on an attrition outcome. Abilities, traits and mystical
powers — most of what actually decides a Symbaroum fight — are not recorded
either, and the type design offers nowhere to put them.

A model can state its assumptions honestly and still not belong in the product.
`Difficulty: Balanced — 70% win` is a verdict, and a GM at the table will trust it
long before they read a caveat list underneath. Precision about the arithmetic is
not the same as accuracy about the fight, and shipping the first while lacking the
second is how a tool starts lying quietly.

The derivation and the solver are in the history rather than in the tree, which
is where a piece of work like that belongs once it stops earning its place:

```bash
git show "$(git rev-list -1 HEAD -- doc/model.md)^:doc/model.md"
```

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
| the GM whose data it is | `defense` means two different things: a monster table prints the modifier an attacker applies, a character sheet prints the target the character rolls under. Reading it as a modifier everywhere turned an unfilled sheet (`0`) into a confident "average" instead of repairing it and saying so |
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

**Bundle size, honestly.** 1,067 KB raw, **342 KB gzipped**. `Base` instead of
`Core` would shrink it meaningfully, but Core idiom is part of the point here, so
it stays — and the number is measured by `scripts/build_site.sh` on every deploy
rather than estimated.

---

## Layout

```
lib/symbaroum/            the domain core — no js_of_ocaml, no core_unix
  scalars/                bounded ints, dice, armour, defence, ids
  aggregates/             combatant, turn_order (the zipper), encounter, roster
  transitions/            action, event, world (the reducer), undo_history
  codec/                  json_decoder, wire_v1 (frozen), wire_v2, migrate
  data/                   86 monster presets, generated from the TypeScript
test/                     ppx_expect + Base_quickcheck, mirroring the above
bin/symbaroum_cli.ml      read / convert / demo, without a browser
web/                      Bonsai, reusing src/App.css verbatim
PORT_TODO.md              the working ledger: decisions, and why
```

Every module has an `.mli` except the generated data. The layering runs strictly
downward — scalars, then aggregates, then transitions, then the codec — and
`dune build -p symbaroum` proves the whole core carries no JavaScript runtime and
no C stubs.

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

Those four are what "green" means, and `./scripts/check.sh` runs exactly them.
The second is a claim rather than a convention: it proves the domain core carries
no JavaScript runtime and no C stubs. GitHub Actions is not available on this
account, so `.github/workflows/ci.yml` describes those checks rather than running
them, and the script is what actually gates a commit.

The headless front end needs no browser:

```bash
dune exec -- bin/symbaroum_cli.exe read doc/samples/v1-export.json
```

And the site is four static files — nothing runs on the host:

```bash
./scripts/build_site.sh && (cd site && python3 -m http.server 8000)
```

Deploying is that build plus a push:

```bash
./scripts/deploy_vercel.sh
```

Vercel has no OCaml toolchain, so nothing here can be built *there*; the bundle is
built here and only the output travels. It travels to its own branch —
`vercel-deploy`, one orphan commit, replaced rather than appended to on each
deploy — because a megabyte of generated JavaScript in the history of the branch
someone is meant to read is precisely what `site/` is gitignored to avoid. That
commit names the source commit it was built from, so "what is live?" has an
answer. `vercel.json` turns Vercel's own build step off (`buildCommand: null`)
and turns deployments off for `ocaml-port`, so pushing source never starts a
build that could not have succeeded.

`master` and the production URL are untouched. Pointing them at this branch is a
deliberate step in the Vercel dashboard, not something a deploy script should do
on its own.

---

## Status

Ported and green: the domain, the codec with a v1 migration, and the Bonsai UI.
Feature parity with one deliberate exception — the difficulty score, which was
ported, improved, and then removed for the reason above. `master` and its live
deployment are untouched.

**What the port found is written up for the original**, as a prioritised fix
list with the file, the current behaviour and the fix for each item:
**→ [`doc/react-fixes.md`](doc/react-fixes.md)**. Sixteen items, every one of them
something a test or a type refused to accept rather than something spotted by
reading.

Known gaps are tracked in [`PORT_TODO.md`](PORT_TODO.md). The two worth naming
here: the v1 round-trip is exercised against a hand-built export rather than one
taken from the live site, and `Attack_profile` still rides along in the domain
and the v2 save format with nothing left to consume it, because removing it is a
save-format change rather than a deletion.
