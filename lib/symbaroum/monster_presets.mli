(** The 86 shipped monster presets, normalized.

    The data itself lives in [monster_presets_data.ml], which is generated from
    {{:src/data/defaultMonsters.ts} [defaultMonsters.ts]} and holds nothing but
    wire-typed transcription. This module is the seam where that becomes domain
    values, so every interpretation of the file happens in exactly one place --
    {!Symbaroum.Monster_preset.of_raw} -- and is pinned by a golden test that
    prints all 86 entries.

    {!all} is forced at module initialization, so malformed generated data fails
    the whole build rather than one code path. That is deliberate: the data is
    static and checked in, so a failure here is a transcription bug, and
    [test/test_monster_presets.ml] is what will name it. *)

open! Core

(** In file order, which is the order the add-combatant dialog shows. *)
val all : Monster_preset.t list

val find : Monster_type.t -> Monster_preset.t option

(** Grouped for the dialog's headings, categories in alphabetical order and
    presets in file order within each. *)
val by_category : (Monster_preset.Category.t * Monster_preset.t list) list

(** The presets {!Symbaroum.Difficulty} can use -- see
    {!Symbaroum.Monster_preset.is_modellable}. *)
val modellable : Monster_preset.t list
