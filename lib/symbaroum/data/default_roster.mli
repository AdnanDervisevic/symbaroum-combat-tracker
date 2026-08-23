(** The four player characters a fresh install starts with.

    Transcribed from {{:src/data/defaultCharacters.ts} [defaultCharacters.ts]}.
    Small enough to keep by hand, unlike the 86 monster presets.

    Their [defense] values -- [8], [3], [0], [0] -- are read as modifiers, so the
    roll-under targets are [2], [7], [10] and [10]. See
    {!Symbaroum.Monster_preset} for why that reading was chosen and applied
    everywhere. Note what it does for Vigoi and Ymma, whose notes in the source
    file say "Placeholder stats": their [0] becomes a target of exactly 10, the
    average attribute, which is the right meaning for a placeholder. Read the
    other way it would be a target of zero -- unhittable, unrepresentable in
    {!Symbaroum.Defense}, and the direct cause of the [Infinity] the old
    difficulty heuristic produces for a party of those two. *)

open! Core

val all : Character.t list

(** ["pc_default_cassimei"] and the other three. Only these four have
    {!Symbaroum.Character.is_builtin} set. *)
val ids : Ids.Character_id.t list
