# Symbaroum Combat Tracker - Improvement Plan

## Progress Summary

| Tier | Total | Done | In Progress | Remaining |
|------|-------|------|-------------|-----------|
| Critical (1) | 4 | 4 | 0 | 0 |
| High (2) | 3 | 3 | 0 | 0 |
| Medium (3) | 2 | 2 | 0 | 0 |
| Nice to Have (4) | 5 | 5 | 0 | 0 |
| **TOTAL** | **14** | **14** | **0** | **0** |

### Status Key
- `[ ]` Not started
- `[~]` In progress
- `[x]` Completed
- `[!]` Blocked

---

## Currently Working On

_All tasks complete!_

---

## Recently Completed

- **Persistent encounter history** (save/restore past encounters from Manage modal)
- **Encounter difficulty calculator** (PC vs NPC stat comparison with rating)
- **Combat round recap** (toast notification on round transition)
- **Undo/redo system** (usePersistentHistory hook, EncounterPanel buttons)
- **Dark mode refinements** (theme toggle, button colors, remove delete on defaults, remove localStorage text)
- **#9** Add localStorage Versioning
- **#8** Fix Damage Input Max Limit
- **#7** Add Escape Key to Close Modals
- **#6** Extract Business Logic to Utils
- **#5** Implement Export/Import Functionality
- **#1** Split App.tsx into Components (893 → 467 lines)
- **#4** Fix Pain Threshold / Prone Reset on Heal
- **#3** Fix Turn Index Logic on Member Removal
- **#2** Fix Non-Deterministic Default Character IDs

---

## TIER 1: Critical

### 1. [x] Split App.tsx into Components
**Current**: 885 lines in single component
**Target**: Extract into logical components

- [x] Create `src/components/` directory structure
- [x] Extract `CharactersPanel` - Character roster management
- [x] Extract `EncounterPanel` - Initiative tracker and combat
- [x] Extract `HelpPanel` - Help content
- [x] Extract `CombatantCard` - Individual combatant in encounter
- [x] Extract `CharacterCard` - Character in roster
- [x] Extract `AddCombatantModal` - Modal for adding NPCs/PCs to encounter
**DONE**: App.tsx reduced from 893 to 467 lines. Created 6 components in src/components/

### 2. [x] Fix Non-Deterministic Default Character IDs
**File**: `src/data/defaultCharacters.ts`
**Problem**: `uid('pc')` called at runtime generates new IDs on each load
**Fix**: Use static string IDs like `'pc_default_cassimei'`
**DONE**: Replaced with static IDs for all 4 default characters

### 3. [x] Fix Turn Index Logic on Member Removal
**File**: `src/App.tsx:257-275`
**Problem**: When removing active member, turnIndex can point to wrong member
**Fix**: Track active member by ID, recalculate index after removal
**DONE**: Now tracks activeId and correctly adjusts turnIndex based on which member was removed

### 4. [x] Fix Pain Threshold / Prone Reset on Heal
**File**: `src/App.tsx:333-350`
**Problem**: Prone is set when damage >= painThreshold, but never cleared on heal
**Fix**: When healing brings toughness above (max - painThreshold), clear prone status
**DONE**: Healing now clears prone status

---

## TIER 2: High Priority

### 5. [x] Implement Export/Import Functionality
**Status**: `ExportPayload` type exists in types.ts but unused
- [x] Create `src/utils/exportImport.ts`
- [x] Add "Export" button to save encounter/characters as JSON
- [x] Add "Import" button to load saved data
- [x] Validate imported data against types
**DONE**: Export/Import buttons in Characters panel, downloads JSON file with version/characters/encounter

### 6. [x] Extract Business Logic to Utils
**Target**: Move from App.tsx to `src/utils/combatLogic.ts`
- [x] `syncMemberFromPc()` - Sync encounter member with PC changes
- [x] `characterToCombatant()` - Convert PC to encounter member
- [x] `normalizeAttributes()` - Clean attribute objects
- [x] `cloneAttributes()` - Deep clone attributes
- [x] `buildNewCharacter()` - Create new character with defaults
- [x] `areAttributesEqual()` - Compare attribute objects
- [x] `ATTRIBUTE_FIELDS` - Attribute field definitions
**DONE**: Created src/utils/combatLogic.ts with all shared logic

### 7. [x] Add Escape Key to Close Modals
**File**: `src/App.tsx` modal section
**Fix**: Add `useEffect` with keydown listener for Escape key
**DONE**: Added useEffect in AddCombatantModal to listen for Escape key

---

## TIER 3: Medium Priority

### 8. [x] Fix Damage Input Max Limit
**File**: `src/App.tsx:334`
**Current**: Capped at 99
**Fix**: Increase to 999 or remove limit
**DONE**: Changed from 99 to 999 in App.tsx and CombatantCard.tsx

### 9. [x] Add localStorage Versioning
**File**: `src/hooks/usePersistentState.ts`
**Current**: Keys like `sct.characters`
**Fix**: Add version prefix `sct.v1.characters` for future migrations
**DONE**: Added STORAGE_VERSION, auto-migrates from old keys to versioned keys (sct.v1.xxx)

---

## TIER 4: Nice to Have (Future)

- [x] Undo/redo system (history stack)
  - Created usePersistentHistory hook with undo/redo/canUndo/canRedo
  - Added undo/redo buttons to EncounterPanel with ↶/↷ icons
  - Persists to localStorage while maintaining history
- [x] Combat round recap/summary
  - Detects round transitions, shows toast with standing/down combatant counts
- [x] Encounter difficulty calculator
  - Compares PC vs NPC toughness, numbers, and defense
  - Displays difficulty rating (Trivial/Easy/Balanced/Hard/Deadly/Overwhelming)
- [x] Persistent encounter history
  - Saves encounters to localStorage when cleared (up to 10)
  - Shows past encounters in Manage Combatants modal with restore/delete
- [x] Dark mode refinements
  - Fixed theme toggle icon visibility (now uses accent color)
  - Fixed button colors in light mode (consolidated CSS rules)
  - Removed delete button from default characters
  - Removed localStorage info text

---

## Bugs to Fix Along the Way

| Bug | Location | Severity |
|-----|----------|----------|
| Unsafe type assertions | App.tsx:660 | Low |
| Optional chaining inconsistency | Throughout | Low |
| Unused ExportPayload type | types.ts:51-55 | Low (fixed by #5) |
| No exhaustiveness check on tabs | App.tsx:404-413 | Low |

---

## Suggested Component Structure

```
src/
  components/
    panels/
      CharactersPanel.tsx
      EncounterPanel.tsx
      HelpPanel.tsx
    cards/
      CharacterCard.tsx
      CombatantCard.tsx
    modals/
      AddCombatantModal.tsx
  hooks/
    usePersistentState.ts
  utils/
    combatLogic.ts
    exportImport.ts
  data/
    defaultCharacters.ts
  types.ts
  App.tsx (orchestration only)
  App.css
  index.css
  main.tsx
```
