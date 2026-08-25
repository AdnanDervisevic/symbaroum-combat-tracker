(** A display name. *)

open! Core
include String_id.S

(** [numbered ~base n] is ["Goblin 3"], the form the NPC adder produces. *)
val numbered : base:Monster_type.t -> int -> t
