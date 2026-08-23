(** Past, present and future, with a bound on the past. *)

open! Core

type 'a t [@@deriving compare, equal, sexp_of]

(** Fifty, as [MAX_HISTORY] in the React hook. *)
val default_capacity : int

val create : ?capacity:int -> 'a -> 'a t
val present : 'a t -> 'a

(** [push t next ~equal ~key] records [next] as the new present.

    - If [equal] says [next] is the present, nothing happens at all: no entry, no
      cleared future.
    - If [key] is [Some k] and the previous push carried the same key, [next]
      {i replaces} the present rather than pushing it, so a run of edits to one
      field costs one undo. [None] never coalesces.
    - Otherwise the present moves into the past, the oldest entry is dropped if
      the past is full, and the future is cleared. *)
val push : 'a t -> 'a -> equal:('a -> 'a -> bool) -> key:string option -> 'a t

val undo : 'a t -> 'a t option
val redo : 'a t -> 'a t option
val can_undo : 'a t -> bool
val can_redo : 'a t -> bool

(** How many entries the past holds. Never more than the capacity, under any
    sequence of pushes, undos and redos -- which is the property test. *)
val depth : 'a t -> int

val future_depth : 'a t -> int
val capacity : 'a t -> int

(** Present and past, newest first, for persistence. The future is deliberately
    dropped: a redo stack that survives a page reload is a promise the app
    cannot keep, since the state it would redo into was never saved. *)
val to_persistable : 'a t -> keep_past:int -> 'a * 'a list

val of_persisted : ?capacity:int -> 'a -> past:'a list -> 'a t
val map : 'a t -> f:('a -> 'b) -> 'b t
