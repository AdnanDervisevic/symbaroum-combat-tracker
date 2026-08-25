(** A dice expression: [count] dice of [sides] faces plus a flat [modifier]. *)

open! Core

type t = private
  { count : int
  ; sides : int
  ; modifier : int
  }
[@@deriving compare, equal, hash, sexp_of, quickcheck]

val min_count : int
val max_count : int
val min_sides : int
val max_sides : int
val create : count:int -> sides:int -> modifier:int -> t Or_error.t
val create_exn : count:int -> sides:int -> modifier:int -> t

(** [d n] is a single [n]-sided die with no modifier. *)
val d : int -> t

(** Total in the sense that it never raises: [None] means "not a dice
    expression", which is a fact the caller has to represent rather than
    discard. Accepts ["1D4"], ["d8"], ["2d6+1"], ["2d6 - 1"], case and space
    insensitive. *)
val parse : string -> t option

val to_string : t -> string
val min_roll : t -> int
val max_roll : t -> int
val mean : t -> float

(** The exact distribution of the total, as [(value, probability)] pairs in
    ascending order of value, summing to [1.]. Computed by convolution, not
    sampling. *)
val distribution : t -> (int * float) list

val roll : t -> Splittable_random.State.t -> int
