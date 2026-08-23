(** The four identities in the domain, each its own type. *)

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
