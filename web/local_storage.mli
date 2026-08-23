(** [window.localStorage], with the failures made explicit. *)

open! Core

(** [None] when the key is absent {i or} when there is no store. *)
val find : string -> string option

val set : string -> data:string -> unit Or_error.t
val remove : string -> unit

(** Whether there is a store at all, for a UI that wants to say so once rather
    than failing quietly on every write. *)
val is_available : unit -> bool
