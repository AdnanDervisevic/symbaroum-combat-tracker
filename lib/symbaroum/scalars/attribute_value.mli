(** An attribute score: the raw number on the character sheet, [1 .. 20].

    Symbaroum rolls d20 {i under} an attribute, so the raw score doubles as a
    roll-under target. Applied as a bonus or penalty elsewhere it appears as
    {!modifier}, which is [10 - raw]: a score of 13 gives [-3]. That
    relationship is why the preset [defense] field in
    {{:src/data/defaultMonsters.ts} [defaultMonsters.ts]} holds [-3] for a
    creature with Quick 13 and [15] for one with Quick 15 -- the same quantity
    in two spellings. See {!Symbaroum.Defense}. *)

open! Core
include Bounded_int.S

(** [modifier t = 10 - to_int t]. *)
val modifier : t -> int
