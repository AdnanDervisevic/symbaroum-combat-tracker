(** Hit points: how much is left, and how much there was. *)

open! Core

type t = private
  { current : int
  ; max : int
  }
[@@deriving compare, equal, hash, sexp_of, quickcheck]

val min_max : int
val max_max : int

(** [Error] unless [0 <= current <= max] and [min_max <= max <= max_max]. *)
val create : current:int -> max:int -> t Or_error.t

val create_exn : current:int -> max:int -> t

(** Saturating on both bounds. The import path uses this and reports the
    repair. *)
val create_clamped : current:int -> max:int -> t

(** Undamaged. *)
val full : int -> t Or_error.t

(** [damage t n] floors at zero and returns how much was actually taken, which is
    less than [n] when the blow overkills. The pain threshold is checked against
    {i that} number, not against the raw input -- see
    {!Symbaroum.Pain_threshold}. *)
val damage : t -> int -> t * int

(** [heal t n] caps at [max] and returns how much was actually restored. *)
val heal : t -> int -> t * int

val is_down : t -> bool

(** Changing the maximum keeps [current] within it. *)
val with_max : t -> int -> t Or_error.t
