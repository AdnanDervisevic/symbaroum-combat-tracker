(** A list that keeps only its most recent [capacity] entries.

    Two things in this app are "the last N of something" -- the encounter archive
    (10) and the undo stack (50) -- and in the React app both enforce that at the
    call site, with a [.slice(-MAX)] that one of the four writers forgot. See
    {{:src/hooks/usePersistentHistory.ts} [usePersistentHistory.ts:112]}: [redo]
    appends to [past] without slicing, so undo/redo ping-pong grows it without
    bound. Making the capacity a property of the value means there is no call
    site left to forget. *)

open! Core

type 'a t = private
  { capacity : int
  ; items : 'a list (** newest first, at most {!capacity} of them *)
  }
[@@deriving compare, equal, sexp_of]

(** [capacity] is clamped to at least 1. *)
val create : capacity:int -> 'a t

val of_list : capacity:int -> 'a list -> 'a t

(** Drops the oldest entry when full. *)
val add : 'a t -> 'a -> 'a t

val to_list : 'a t -> 'a list
val length : 'a t -> int
val is_empty : 'a t -> bool
val filter : 'a t -> f:('a -> bool) -> 'a t
val find : 'a t -> f:('a -> bool) -> 'a option
val map : 'a t -> f:('a -> 'b) -> 'b t
