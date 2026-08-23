(** A distribution over small non-negative integers, held as a [float array] indexed by the value. *)

open! Core

type t = private float array [@@deriving compare, equal, sexp_of]

(** All the mass on one value. *)
val dirac : int -> t

val of_dice : Dice.t -> t

(** [Unarmored] is {!dirac} [0], so armour is always something to subtract and
    there is no special case downstream. *)
val of_reduction : Armor.Reduction.t -> t

(** One past the largest value with any mass. *)
val length : t -> int

val prob : t -> int -> float

(** Should be [1.] up to rounding; the property test pins it to 1e-12. *)
val total : t -> float

val mean : t -> float
val to_alist : t -> (int * float) list

(** [sub_clamped damage armor] is the distribution of [max 0 (d - a)] for
    independent [d] and [a]. Every negative outcome lands on zero rather than
    being dropped, so the result still sums to one -- a blow that fails to get
    through armour is a blow that happened and did nothing, not a blow that did
    not happen. *)
val sub_clamped : t -> t -> t

(** The probability that a value drawn from [t] satisfies [f]. Used for "does
    this blow exceed the pain threshold". *)
val probability : t -> f:(int -> bool) -> float

(** A draw from this distribution. Used by {!Symbaroum.Combat_sim}, so that the
    oracle and the DP are sampling and summing {i the same} distribution -- which
    is what makes their agreement evidence about the DP rather than about two
    different models. *)
val sample : t -> Splittable_random.State.t -> int
