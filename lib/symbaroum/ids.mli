(** The four identities in the domain, each its own type.

    All four are bare [string] in {{:src/types.ts} [types.ts]}, which is how an
    NPC pointing at a player character became representable and needed a runtime
    guard at {{:src/App.tsx} [App.tsx:453]}. [Core.String_id.Make] is generative,
    so each application below produces a genuinely distinct type: passing a
    {!Character_id.t} where a {!Combatant_id.t} is wanted no longer compiles.

    An identity carries {i no data}. The React app violates that at
    {{:src/components/cards/CharacterCard.tsx} [CharacterCard.tsx:112]}, which
    tests the id for the [pc_default_] prefix to decide whether a character is
    one of the four built-ins -- a data property smuggled into a name, and one
    that silently changes meaning as soon as an import renumbers ids. That
    question gets an [is_builtin] field on the character record instead
    (Phase 3).

    [String_id] rather than a hand-rolled [Identifiable.Make]: it already
    rejects the empty string and edge whitespace in [of_string] and [t_of_sexp],
    which is precisely the validation these ids need. Note that [of_string]
    {i raises}; the JSON decoder lifts it with [Or_error.try_with] rather than
    each module growing its own [create]. *)

open! Core

module type S = String_id.S

(** A roster entry: a player character. *)
module Character_id : S

(** A participant in the encounter. Distinct from {!Character_id} because a
    combatant may be an NPC with no roster entry at all. *)
module Combatant_id : S

(** A saved NPC stat block. *)
module Bestiary_id : S

(** An archived encounter. *)
module Snapshot_id : S
