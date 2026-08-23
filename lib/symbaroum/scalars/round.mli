(** The combat round counter, [1] or greater.

    [round: 0] is representable in the React app and is actually produced: the
    empty encounter starts there and every import path can restore it.

    Note the deliberate asymmetry in {!prev}: it floors at {!first} rather than
    failing, so stepping back from round 1 is a no-op. That makes
    [prev (succ t) = t] hold everywhere, while [succ (prev first)] is not
    [first]. The property test asserts that exception explicitly rather than
    leaving it as folklore. *)

open! Core

type t = private int [@@deriving compare, equal, hash, sexp_of, quickcheck]

val first : t
val of_int : int -> t Or_error.t
val of_int_exn : int -> t

(** Saturating at {!first}. Used by the import path, which reports the repair. *)
val of_int_clamped : int -> t

val to_int : t -> int
val succ : t -> t

(** Floors at {!first}. *)
val prev : t -> t
