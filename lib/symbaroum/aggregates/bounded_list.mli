(** A list that keeps only its most recent [capacity] entries. *)

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
