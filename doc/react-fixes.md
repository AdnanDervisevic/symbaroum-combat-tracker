# Fixes for the React app

Everything below was found by porting this app to OCaml on the `ocaml-port`
branch and writing about 4,900 lines of tests against it. The original has none,
so nothing here was found by reading — each item is a behaviour some test or type
refused to accept. Every file and function reference has been checked against the
current `master` source.

**This file is written to be used as a prompt.** Hand it to a coding agent working
in this repository, or work through it by hand. Items are ordered by what will
bite you at the table first. Each one states what is wrong, where, what actually
happens, and what the fix is.

---

## Part 1 — Bugs you will hit while running a session

### 1. NPC auto-numbering repeats a name after you remove one

**Where:** `src/App.tsx`, `addNpc`, the `existingTypeCount` line.

```ts
const existingTypeCount = monsterType
  ? prev.members.filter((m) => m.monsterType === monsterType).length
  : 0;
```

It counts the monsters **currently alive in the encounter**, so numbering reuses
names. Add three Goblins, remove Goblin 2, add one more: you now have two
combatants called "Goblin 3". They are separate rows with separate toughness, and
you will damage the wrong one.

**Fix:** store a high-water mark per monster type on the encounter itself — e.g.
`nameCounter: Record<string, number>` — and allocate from it rather than counting
live members. Never decrement it when a member is removed. When loading a save
that has no counter, rebuild it from the largest numeric suffix already present
among the member names of that type.

**Verify:** add 3 Goblins, remove Goblin 2, add 1 → the new one is Goblin 4.

---

### 2. Adding an NPC from a preset silently drops its attributes

**Where:** `src/App.tsx`, `addNpc` — both the `newMembers.push({...})` literal and
the `BestiaryEntry` literal below it.

Neither object includes `attributes`. The preset carries them, the dialog reads
them, and then the combatant is built without them, so they are gone. Nothing
errors because `attributes` is optional on the type.

**Fix:** carry `attributes` through into both literals. Then make the type stop
allowing the omission — see item 15.

**Verify:** add an NPC from a preset that has attributes, then open its editor and
confirm the attributes are there.

---

### 3. Sorting by initiative resets the round counter to 1

**Where:** `src/App.tsx`, `sortByInitiative`.

```ts
turnIndex: prev.members.length ? 0 : 0,
round: prev.members.length ? 1 : prev.round,
```

Sort in round 5 and you are back in round 1. Nothing warns you, and undo is the
only way back. (The `turnIndex` line is the same expression on both branches,
which is the tell that this block was written in a hurry.)

**Fix:** sorting reorders `members` and resets `turnIndex` to 0. It must not touch
`round` at all:

```ts
members: [...prev.members].sort((a, b) => (b.initiative || 0) - (a.initiative || 0)),
turnIndex: 0,
```

**Verify:** step to round 3, sort, confirm it still says round 3.

---

### 4. Deleting a character leaves the turn cursor pointing past the end

**Where:** `src/App.tsx`, `deleteCharacter`.

```ts
setEncounter((prev) => ({
  ...prev,
  members: prev.members.filter((m) => m.refId !== id),
}));
```

`members` shrinks and `turnIndex` is left alone. If the deleted character was at
or before the cursor, the highlighted combatant shifts to the wrong row; if the
cursor was near the end, it now points past the array and **no row is
highlighted at all** until you step the turn.

**Fix:** after filtering, clamp and adjust:

- remember the id of the current member before filtering;
- after filtering, set `turnIndex` to that member's new index if it survived;
- otherwise clamp `turnIndex` into `[0, members.length - 1]`, and set it to 0 when
  the encounter is now empty.

Do the same in **every** path that removes members — `removeMember`,
`handleImport` and `restoreEncounter` all have this shape.

**Verify:** four members, step to the last one, delete the first character → the
same combatant stays highlighted.

---

### 5. Number inputs cannot be cleared and fight you while typing

**Where:** every `type="number"` input in `src/components/cards/CharacterCard.tsx`,
`src/components/cards/CombatantCard.tsx` and
`src/components/modals/AddCombatantModal.tsx`. The pattern is:

```tsx
value={character.initiative}
onChange={(e) => onUpdate(character.id, { initiative: Number(e.target.value) || 0 })}
```

Two things go wrong. Selecting the contents and deleting them produces `""`,
`Number("")` is `0`, so the field immediately snaps back to `0` instead of going
empty — you can never start from a blank field. And `|| 0` turns any
partially-typed value into a hard zero, so the state churns while you type.

**Fix:** hold the *typed text* in local state, not the number. Write one small
component and use it everywhere:

```tsx
function NumberField({ value, onCommit, min, max }: {
  value: number; onCommit: (n: number) => void; min?: number; max?: number;
}) {
  const [draft, setDraft] = useState<string>(String(value));
  const [focused, setFocused] = useState(false);
  useEffect(() => { if (!focused) setDraft(String(value)); }, [value, focused]);

  return (
    <input
      type="number"
      inputMode="numeric"
      value={focused ? draft : String(value)}
      onFocus={(e) => { setFocused(true); setDraft(String(value)); e.currentTarget.select(); }}
      onChange={(e) => {
        setDraft(e.target.value);
        const n = Number(e.target.value);
        if (e.target.value !== "" && Number.isFinite(n)) onCommit(clamp(n, min ?? 0, max ?? 999));
      }}
      onBlur={() => { setFocused(false); if (draft === "") onCommit(value); }}
    />
  );
}
```

The `e.currentTarget.select()` on focus is what removes the other daily
annoyance: tapping a field showing `0` and typing no longer leaves you editing
around the zero.

Note that `painThreshold` in `CombatantCard.tsx` already does the right thing —
`value={member.painThreshold ?? ""}` with an explicit `=== ""` check — so the
pattern to copy is already in the codebase.

**Verify:** clear a toughness field completely, type `12`, tab away → 12. Clear it
and tab away without typing → the old value comes back, not 0.

---

### 6. The pain threshold fires on the number you typed, not the damage dealt

**Where:** `src/App.tsx`, `applyAdjustment`.

```ts
const nextToughness = clamp(member.toughness + delta, 0, 999);
...
if (threshold !== null && amount >= threshold) { updated.prone = true; ... }
```

It compares `amount` — the raw contents of the damage box — against the
threshold, while the toughness change is clamped separately. A combatant on 2
toughness hit for 20 takes 2 and is dead, but the threshold check sees 20. Armour
is not subtracted anywhere at all, so a d8 armour value never reduces anything.

**Fix:** decide the quantity and use it in both places. The port settled on
**damage that got through armour, before the clamp to zero** — a combatant
reduced to zero is *down*, not prone, so clamping first would change no outcome
while making the rule harder to state. Compute `dealt` once, apply it to
toughness, and test the threshold against it.

Also handle the two meanings of the field explicitly, because right now they live
only in your head:

| `painThreshold` | means |
|---|---|
| `null` | this creature never goes prone |
| `0` | every hit that lands prones it |
| `n > 0` | prone when the damage dealt is at least `n` |

The current guard `threshold !== null && amount >= threshold` gets `0` right only
because `amount === 0` returns early. Make it a real three-case check.

**Verify:** a combatant on 2 toughness with threshold 5, hit for 20 → dead, and
no "exceeds Pain Threshold" toast.

---

### 7. Every keystroke in a note costs one undo slot

**Where:** `src/hooks/usePersistentHistory.ts`, `setState`.

```ts
if (newPresent === prev.present) return prev;
```

That is JavaScript **reference** equality, and every caller builds a fresh object
literal, so it never fires. `MAX_HISTORY` is 50, so typing one sentence into a
note field evaporates the entire undo stack — the thing you actually wanted to
undo is gone before you reach for it.

**Fix:** two changes.

1. Compare structurally before pushing (a cheap `JSON.stringify` comparison is
   fine at this size), so a no-op edit costs nothing.
2. Add **coalescing**: give `setState` an optional key like
   `"note:cmb_123"` or `"toughness:cmb_123"`. If the previous entry was pushed
   with the same non-null key, replace it instead of pushing a new one. Field
   edits pass a key; structural actions (add, remove, sort, next turn) pass none.

Then typing a sentence is one undo entry, and changing a different field starts a
new one.

**Verify:** type 20 characters into a note, press undo once → the whole note edit
reverts and the earlier history is intact.

---

### 8. Undo/redo ping-pong grows history without bound

**Where:** `src/hooks/usePersistentHistory.ts`, `redo`.

```ts
past: [...prev.past, prev.present],
```

No `.slice(-MAX_HISTORY)`. `setState` slices, `undo` does not need to, and `redo`
forgot. Press undo and redo alternately and `past` grows forever — and it is
serialised to localStorage on every change, so this is also a slow leak into disk
and into the save file.

**Fix:** apply the same `.slice(-MAX_HISTORY)` in `redo`. Better: make one private
helper that constructs the history record and trims, and route all three of
`setState`, `undo` and `redo` through it so no fourth writer can forget again.

**Verify:** press undo/redo 200 times, then inspect `past.length` → still 50.

---

## Part 2 — Data safety

### 9. Any `version` number is accepted and then blind-cast

**Where:** `src/utils/exportImport.ts`, `validateImportData`.

```ts
if (typeof payload.version !== 'number') {
  return { success: false, error: 'Missing or invalid version' };
}
```

`version` is checked for being a number and **never compared to `1`**. A file
claiming `version: 7` is accepted and cast to the current shape, so a future
format — or a corrupted file — is read as though it were the current one.

**Fix:** dispatch explicitly. `version === 1` is the only shape this code
understands; anything else is refused by name: `Unsupported save version 7; this
app reads version 1.`

**Verify:** edit an export to `"version": 7`, import it → a clear refusal, no
state change.

---

### 10. The importer validates shape but never repairs the encounter cursor

**Where:** `src/utils/exportImport.ts`, `validateImportData`, and `handleImport`
in `src/App.tsx`.

The validator checks that `characters` and `encounter.members` are arrays and that
each character has an `id` and a `name`. It does not look at `turnIndex` or
`round` at all, so `{"members": [], "turnIndex": 5, "round": 0}` imports cleanly
and leaves the app in a state its own UI cannot produce. Hand-edited
localStorage lands here too.

**Fix:** repair rather than reject, and say what you repaired. Clamp `turnIndex`
into range (0 when there are no members), floor `round` at 1, and rename or drop
duplicate member ids. Collect a list of what was changed and show it: *"Loaded — 3
corrections applied"*, with the list available. A silent repair and a silent
acceptance look identical to the user, which is the actual problem.

**Verify:** import a file with `turnIndex: 99` → loads, cursor at a real member,
and the UI says it corrected something.

---

### 11. Toughness is current and maximum at the same time

**Where:** `src/types.ts` — `toughness: number` on both `Character` and
`Combatant`.

There is one number, so a wounded combatant's maximum is simply not recorded.
The clamp to `[0, 999]` appears in three view-layer places
(`App.tsx`, `CombatantCard.tsx`, `CharacterCard.tsx`) and in **zero** places on
the import path. It is also why nothing can show "6 / 10".

**Fix:** make it `toughness: { current: number; max: number }`, with a migration
that reads an old numeric `toughness` as `{ current: n, max: n }` — and for
combatants, recovers `max` from the linked roster character or bestiary entry when
one exists. Clamp in one function that both damage and healing go through.

**Verify:** damage a combatant, reload the page → it still shows the maximum it
started with.

---

### 12. localStorage failures are swallowed

**Where:** `src/hooks/usePersistentHistory.ts`, the save effect.

```ts
} catch (err) {
  console.warn('Failed to save to localStorage', err);
}
```

A `QuotaExceededError` — which is reachable, since `past` is serialised too and
item 8 makes it grow — means your session silently stops persisting. You find out
when you reload.

**Fix:** surface it. Show a toast on the first failure and keep a flag so it is
not repeated on every keystroke. Reduce the pressure at the same time: persist
`present` plus a truncated `past` (20 entries is plenty), and skip persisting
`past` entirely if the serialised payload is over ~1 MB.

**Verify:** fill localStorage from the console, make an edit → a visible warning.

---

## Part 3 — Worth doing, not urgent

### 13. Delete the difficulty score

**Where:** `src/components/panels/EncounterPanel.tsx`, lines 5–35.

```ts
const score = (toughnessRatio * 0.5) + (numbersRatio * 0.3) + (defenseRatio * 0.2);
```

Two problems. The weights are derived from nothing. And `defenseRatio` divides by
the party's average defence, which is `0` when the PCs in the encounter are the
shipped placeholders — so it returns `Infinity` and the label is meaningless.

The port replaced this with an exact absorbing-state Markov model, and **that was
also deleted**, for a reason that applies to any replacement you might write: this
app records no weapon data for anybody, and no abilities, traits or mystical
powers. Damage is the largest single lever on how a fight goes, and it would have
to be invented. A difficulty verdict computed from toughness and defence alone
will be trusted and will be wrong.

**Fix:** remove the score. If you want something in that space, show facts rather
than a judgement — total toughness per side, number of combatants, highest and
lowest defence — and let the GM judge.

---

### 14. `defense` means two different things and the app treats it as one

A **monster statblock** prints the modifier an attacker applies. A **player
character sheet** prints the roll-under target itself. They are related by
`10 − x`, and the app stores both in the same `defense: number` field, so the
Characters tab and the monster presets are showing you two different quantities
under the same label.

Nothing in the React app consumes `defense` except the (broken) difficulty ratio,
so this changes no behaviour today. But it is misleading on screen, and it will
matter the moment anything uses the number.

**Fix:** at minimum, label them differently in the UI. Better: store the
roll-under target everywhere and convert monster presets on the way in with
`target = 10 - stored`. Note that a character sheet storing `0` means *nobody
filled this in*, not "average" — the shipped characters Vigoi and Ymma are in that
state.

---

### 15. Types that permit states the app then produces

These are the type-level versions of bugs above. Doing them prevents recurrence
rather than fixing a symptom.

| In `src/types.ts` today | Change to |
|---|---|
| `source: 'pc' \| 'npc'` with optional `refId` and `monsterType`, so `{source:'npc', refId:'pc_x'}` is legal and needs a runtime guard | one discriminated union: `{ kind: 'pc'; refId: string } \| { kind: 'npc'; monsterType?: string }` |
| `attributes?: CharacterAttributes \| null`, so "no attributes" has three spellings and each of the 8 fields has three more | a required record with `number \| null` per key. This deletes `normalizeAttributes` and `areAttributesEqual` in `src/utils/combatLogic.ts` outright — they exist only to paper over the spellings |
| `Partial<Combatant>` in `updateMember`, which shallow-merges **any** field to **any** value, including `source` and a negative toughness | an explicit patch union: `{ field: 'toughness'; value: number } \| { field: 'note'; value: string } \| …`. This is also what gives item 7 its coalescing key |
| `armor: string`, never parsed anywhere | parse it once into `{ text: string; reduction: number \| { dice: string } \| null }`, keeping the original text so free-form entries survive |
| four different identities (`Character`, `Combatant`, `BestiaryEntry`, snapshot) all typed `string` | branded types, so a character id cannot be passed where a combatant id is expected |
| `id.startsWith('pc_default_')` in `CharacterCard.tsx` — a data property smuggled into an identifier and re-asked on every render | an `isBuiltin: boolean` field, with the prefix read exactly once when migrating an old save |
| `damageInputs` is keyed by combatant id at the root and pruned only in `removeMember` | key it per row, or prune it in every path that removes a member |

---

### 16. `applyAdjustment` writes to a ref from inside a state updater

**Where:** `src/App.tsx`, `applyAdjustment`.

It declares `triggerRef`, writes to it inside `members.map` — which runs inside
the `setEncounter` updater — reads it afterwards, and then uses
`window.setTimeout(…, 0)` to dodge a batching problem. React may call an updater
twice (it does in StrictMode), so the effect can fire twice or read a stale value.

**Fix:** have the update compute both the new state **and** a list of what
happened, then act on that list outside the updater:

```ts
const { next, events } = applyDamage(encounter, memberId, mode, amount);
setEncounter(next);
for (const e of events) showToastFor(e);
```

The updater becomes pure, the toast text becomes testable, and the `setTimeout`
is unnecessary.

---

## Suggested order

1, 3, 4, 5, 7 first — those are the ones you feel in a session. Then 2, 6, 8.
Then Part 2 before you trust the save file. Part 3 whenever.
