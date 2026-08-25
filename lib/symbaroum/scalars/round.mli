(** The combat round counter, [1] or greater. *)

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
