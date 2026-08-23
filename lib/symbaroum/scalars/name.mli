(** A display name.

    Non-empty by construction, which the React app does not guarantee: an
    imported combatant with an empty name renders as a blank card. *)

open! Core
include String_id.S

(** [numbered ~base n] is ["Goblin 3"], the form the NPC adder produces. *)
val numbered : base:Monster_type.t -> int -> t
