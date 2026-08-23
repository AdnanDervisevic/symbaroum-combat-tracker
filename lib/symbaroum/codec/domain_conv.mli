(** The one place a {!Symbaroum.World.t} is built from outside data.

    The plan called this [Wire_v2.to_domain]. It is its own module because it has
    its own job: {!Symbaroum.Wire_v2} knows JSON and knows nothing about
    invariants, this knows invariants and nothing about JSON, and keeping them
    apart is what lets a malformed file fail in one and a legal-but-wrong file
    fail in the other.

    {1 Normalization is total and reported}

    Nothing here rejects. Every value that cannot be what it claims to be is
    repaired and the repair is handed back as a {!Symbaroum.Normalization.t}: a
    toughness outside its range is clamped, a defence outside its range is
    clamped, an unparseable armour string is kept verbatim as free text, a
    combatant pointing at a character that is gone becomes an NPC, a duplicate id
    is renamed, a missing name counter is rebuilt.

    That is what turns "we clamp somewhere" into a specification. The import
    dialog can say "Loaded -- 3 corrections applied", and a test can assert
    exactly which three. The React app clamps in three view-layer places and
    {i nowhere at all} on the import path, which is how a save with
    [turnIndex: 5] and no members gets in.

    {b Turn index and round are not repaired here.} They are repaired in
    {!Symbaroum.Encounter.create}, which is the only function in the library
    allowed to do it, and its normalizations are passed through. *)

open! Core

val to_domain : Wire_v2.t -> World.t * Normalization.t list

(** Total, and the inverse of {!to_domain} on anything {!to_domain} produced --
    which is the round-trip property, and the only thing holding the derived
    writer and the hand-written reader together. *)
val of_domain : World.t -> Wire_v2.t
