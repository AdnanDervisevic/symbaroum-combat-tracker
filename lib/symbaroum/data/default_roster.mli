(** The four player characters a fresh install starts with. *)

open! Core

val all : Character.t list

(** ["pc_default_cassimei"] and the other three. Only these four have
    {!Symbaroum.Character.is_builtin} set. *)
val ids : Ids.Character_id.t list
