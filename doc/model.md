# The combat probability model

This document derives what `Symbaroum.Difficulty.analyze` computes, states what it
assumes, and — where an assumption is load-bearing — measures what the assumption costs
rather than asserting that it is small.

It replaces the heuristic at
[`EncounterPanel.tsx:5-35`](../src/components/panels/EncounterPanel.tsx), which combines a
toughness ratio, a defence ratio and a headcount ratio with weights of 0.5, 0.3 and 0.2.
Those weights are derived from nothing. The defence ratio also divides by the party's
average defence, which rounds to zero for a party of the two shipped characters whose
notes read "Placeholder stats" — so the heuristic returns `Infinity` with stock data.

---

## What it answers

Given an encounter, the model returns:

| field | meaning |
|---|---|
| `p_party_wins` | probability the party is the side still standing |
| `p_bounds` | an interval **containing** that probability; see [the error bound](#the-error-bound-is-a-proof) |
| `expected_party_casualties` | party members reduced to zero, in expectation |
| `round_quantiles` | by which round the fight is over, at the 50th and 90th percentile |
| `method_` | exact or sampled, with the numbers needed to judge it |
| `caveats` | everything the analysis had to guess |

**Read the casualties before the probability.** Parties do not fight to the last member;
they retreat, or they lose someone and the fight changes. The shipped roster against three
Robbers comes out at `Trivial — 99% win, expect 1.3 casualties, median 9 rounds`. The
label and the cost disagree, and the cost is the useful half.

---

## The reduction

The honest state of a fight is the whole toughness vector. Four player characters and six
NPCs at 10 toughness each is 11¹⁰ ≈ 2.6 × 10¹⁰ states. That is not a computation.

**Under focus fire the vector collapses to two integers per side.** If each side attacks
its enemies in a fixed order, then at any moment the enemies before the current target are
dead and the ones after it are untouched — at whatever toughness they had when the
question was asked. So the party's entire state is `(i, h)`: the index of the first living
member, and what that member has left.

Prone is nearly free. Only the current target can be knocked down, so tracking it costs a
factor of four rather than 2^(n_A + n_B). That means the app's signature mechanic is
modelled **exactly** rather than dropped.

```
state = (i, h_A, prone_A, j, h_B, prone_B)
```

Measured state counts, from
[`test_attrition_dp.ml`](../test/model/test_attrition_dp.ml):

| encounter | states |
|---|---|
| 4 PCs (T=10) vs 6 NPCs (T=10) | 9,801 |
| 5 PCs (T=15) vs 8 NPCs (T=15) | 36,391 |
| 8 PCs (T=20) vs 20 NPCs (T=20) | 257,121 — over budget |

The budget is 250,000 states; above it the model switches to Monte Carlo.

### Toughness is where the fight is now

`h` starts from each combatant's **current** toughness, not its maximum. A GM asking "how
does this go" is asking from the middle of a fight. This costs the reduction nothing: it
needs later members to be at their *starting* value, and their starting value is whatever
they have when the question is asked. A combatant already at zero is not in the fight at
all and is dropped from both sides.

---

## The transition

Every rule about hitting lives in one function,
[`Hit_chance.of_matchup`](../lib/symbaroum/model/hit_chance.ml). Nothing else in the model
knows how a roll works, so a rules correction is a one-line diff rather than a search.

```
target  = Accurate_attacker + (10 - Defence_defender) + situation
p(hit)  = clamp target to [1, 19] / 20
```

`Defense.t` stores the absolute roll-under value, so `10 - Defence` is exactly
`Defense.to_modifier`. The clamp is the rule that a natural 1 always hits and a natural 20
always misses, so **no matchup is ever certain in either direction** — which is why the
closed-form anchor below is 0.952381 rather than 1.

Damage is convolved, not sampled:

```
D_net = max(0, weapon_roll - armour_roll)
```

with all the mass at or below zero collapsed onto zero — armour cannot heal you, and a
blow that fails to get through is a blow that happened and did nothing. The support is
tiny (1d8 against 1d4 armour is eight outcomes), so exactness is free.

The pain check uses the damage **dealt**, not the number rolled: a nine-point swing
against three remaining toughness deals three. This is the same rule the engine applies in
`Combatant.hurt`, and getting it wrong in one of the two places is exactly the sort of
divergence the DP-versus-simulation check catches.

### Within a round, resolution is exact

A round is the composition of one operator per combatant in initiative order, not a
simultaneous approximation. Two things follow:

- "Does a combatant that dies before its turn still act?" is a modelled fact rather than
  an artefact. It does not.
- Mutual annihilation cannot happen, so `p_wins + p_wiped = 1` exactly. The mirror-image
  test asserts this: the same fight with initiative swapped gives 0.575469 and 0.424531,
  summing to 1 within the convergence tolerance.

---

## Solving it

Power iteration over a flat `Bigarray.Array1` of float64, applied out-of-place into a
scratch buffer. Power iteration rather than solving `(I − Q)x = b` because:

- **No BLAS**, so the core stays pure OCaml with zero C stubs — which is what lets the
  same code compile to JavaScript *and* build anywhere. A hard constraint, not a
  preference. (`Bigarray` matters here too: js_of_ocaml maps it to a `Float64Array`,
  where a plain `float array` becomes a boxed JS array.)
- **The round distribution comes free**, and "median 4 rounds, 90th percentile 9" is more
  use to a GM than a bare probability.

### The error bound is a proof

After `k` rounds, the probability mass that has not yet been absorbed is an **exact** upper
bound on how far `p_party_wins` can still move: every unabsorbed path must eventually land
in one of the two absorbing sets, and at worst all of it lands in the party's. So the
returned interval is `[p, p + residual]`, and that is a theorem rather than a heuristic.

The iteration stops at a residual below 1e-9 or after 200 rounds.

---

## Validation

### Closed-form anchors

From [`test_attrition_dp.ml`](../test/model/test_attrition_dp.ml):

- **1v1, both lethal on any hit, party first.** The recurrence is
  `p = p_hit / (1 − (1 − p_hit)²)`, and with the clamped target of 19 that is
  0.95 / 0.9975 = **0.952381**. The DP returns 0.952381.
- **An enemy who cannot get through the party's armour** returns exactly **1.000000**,
  which is also the test that the damage convolution really floors at zero.
- **Mirror images** sum to 1 (see above).

### The simulation agrees with the exact answer

[`Combat_sim`](../lib/symbaroum/model/combat_sim.ml) runs the full rules with matched
assumptions — same targeting, same hit chances, and damage drawn from *the very same*
`Pmf` the DP sums over, so a disagreement is about the fight and not about the weapon.
40,000 samples, fixed seed:

| encounter | exact | sampled | diff | 4·se |
|---|---|---|---|---|
| one on one | 0.5755 | 0.5778 | 0.0023 | 0.0099 |
| three on one, the one is big | 0.3149 | 0.3148 | 0.0001 | 0.0093 |
| two on four | 0.4966 | 0.4975 | 0.0009 | 0.0100 |
| pain thresholds on both sides | 0.0208 | 0.0201 | 0.0007 | 0.0028 |
| a foe line that is already hurt | 0.4144 | 0.4131 | 0.0013 | 0.0098 |

Expected casualties agree to three decimal places on every row.

### Monotonicity

Property tests over generated encounters assert that adding a foe, raising a foe's
toughness, or raising a foe's Accurate all **weakly decrease** the party's chances. These
are genuine theorems about the model rather than facts about any one fight, and an index
slip in the DP breaks them almost immediately.

---

## The assumption that costs something

**Focus fire is load-bearing.** It is what makes exactness possible at all, and it is
defensible — focusing is the optimal attrition strategy for both sides, so assuming it
symmetrically is an equilibrium assumption rather than a convenience. But "the bias is
small" is worth measuring.

`Combat_sim` carries no state-space constraint, so it can run the alternatives. Same
fights, same seed, 40,000 samples each:

| encounter | focus in order | uniform random | weakest first |
|---|---|---|---|
| one on one | 0.5778 | 0.5798 | 0.5778 |
| three on one, the one is big | 0.3148 | 0.3688 | 0.3148 |
| two on four | 0.4975 | 0.4988 | 0.4975 |
| pain thresholds on both sides | 0.0201 | 0.0152 | 0.0201 |
| a foe line that is already hurt | 0.4131 | 0.4240 | **0.5216** |

Two things to read off it.

Uniform targeting moves the answer by up to about 5 points, and not always in the same
direction: it helps the party in "three on one" (spreading the troll's damage across three
PCs wastes it) and hurts the party where pain thresholds matter (spreading blows around
knocks fewer enemies down).

`Weakest_first` equals `Focus_in_order` on every row where both sides start at full
health, and for a reason worth stating: focusing in order makes the current target the
weakest one anyway. The two policies only diverge when a side starts the fight already
hurt — the last row, where finishing off the two wounded Robbers first is worth **11
points** to the party. **This is the largest known bias in the model**, and it applies
exactly to the case a GM asks about most: a fight already in progress.

### Why the exact method cannot simply drop the assumption

Under uniform targeting the state is the *multiset* of toughness values per side. For 20
NPCs over 11 toughness values that is C(30,10) = **30,045,015** states, before multiplying
by the party side — against 400 under focus fire. The choice was computed, not assumed.

---

## Assumptions, stated

**Included in the model:** initiative-ordered sequential resolution; one attack per
combatant per round; d20 roll-under modified by Defence; exact damage-minus-armour
convolution floored at zero; death removes a combatant; pain threshold → prone → lose the
next action → stand; fight to the last combatant; each side's current toughness at the
moment the question is asked.

**Excluded:** healing, mystical powers, morale and retreat, multi-attacks, initiative
re-rolls, criticals, and any effect that changes a combatant's statistics mid-fight.

**Modelled approximately:**

- *Prone combatants who are not the current target* are treated as standing. Only the
  current target's prone state is tracked, because only the current target can be knocked
  down. The cost is at most one lost action for a combatant the GM has flagged prone
  before the analysis runs.
- *Flanking* is a static per-combatant flag the GM sets, not something the model works
  out, so it is a property of a defender rather than part of the fight's state.

**Not verified against the core book.** The shape of the to-hit formula is reasonably
confident. The two situational modifiers are guesses:

| modifier | value | status |
|---|---|---|
| prone defender | +2 to the attacker's target | **unverified** |
| flanked defender | +2 to the attacker's target | **unverified** |

They are named constants in `Hit_chance` precisely so that a reader can see their size and
change them in one place.

---

## Two data problems, stated honestly

### The app records no weapon data at all

Not for anybody. All 86 monster presets carry an Accurate score, so the to-hit side is
grounded, but **no combatant in the app has a weapon**. The four shipped player characters
have `attributes: null` as well, so they have no Accurate either.

A model that refused to guess would report that every party loses every fight — not a
cautious answer, a useless one. So:

- a missing damage die becomes the creature's resistance-band prior (`Weak → 1d6`,
  `Ordinary → 1d8`, `Challenging → 1d10`, `Strong → 1d12`, `Mighty → 1d12+1`,
  `Legendary → 1d12+2`), and for a combatant with no band at all, `1d8`;
- a missing Accurate becomes 10, the average score;

**and every substitution appears in `caveats`.** A number computed from an invented weapon
is not the same kind of number as one computed from a statblock, and the difference has to
survive all the way to the reader of the verdict. That is the entire purpose of
`Caveat.t`.

### The preset `defense` field is a modifier, uniformly

Resolved in Phase 2 and recorded in `PORT_TODO.md`; the short version is that the stored
number is `10 − Defence`, so the roll-under target is `10 − stored`. Under that reading
the two placeholder characters' `defense: 0` becomes a target of exactly 10, the average —
which is the right meaning for a placeholder, and the reading under which they are legal
at all.

The consequence worth flagging: Cassimei stores `defense: 8`, which under this reading is
a target of **2** — very easy to hit. That is a fact about placeholder data rather than
about the model, but it shows up in every analysis of the shipped party and is worth
recognising rather than being surprised by.

---

## A consequence of focus fire worth knowing

Focus fire produces Lanchester square-law dynamics: concentrated fire makes numerical
advantage compound, so headcount matters more here than it feels like it does at a table.
From the difficulty ladder in [`test_difficulty.ml`](../test/model/test_difficulty.ml),
with otherwise identical combatants:

| encounter | verdict |
|---|---|
| 4 PC vs 4 even | Balanced — 68.7%, 2.3 casualties |
| 4 PC vs 6 even | Overwhelming — 5.1%, 3.9 casualties |
| 2 PC vs 4 even | Overwhelming — 0.8%, 2.0 casualties |
| 6 PC vs 4 even | Trivial — 99.7%, 1.0 casualties |

A 50% numerical advantage takes the fight from "close" to "hopeless". That is real for
focused fire, and it is steeper than most GMs expect, so it is the number to be
sceptical about first if the model ever disagrees with a table.

---

## Labels

| probability the party wins | label |
|---|---|
| ≥ 0.95 | Trivial |
| 0.85 – 0.95 | Easy |
| 0.60 – 0.85 | Balanced |
| 0.35 – 0.60 | Hard |
| 0.15 – 0.35 | Deadly |
| < 0.15 | Overwhelming |

Pinned at the boundaries by an expect test. They are deliberately **not** calibrated
against the old heuristic: continuity with a broken baseline is not a goal.

---

## Reproducing any of this

```bash
dune exec -- bin/symbaroum_cli.exe analyze doc/samples/v1-export.json
```

Every table in this document is the output of an expect test under
[`test/model/`](../test/model), so it cannot drift from the code without the build going
red. Monte Carlo runs take their seed as an argument and never as a default, so a printed
number is always reproducible.
