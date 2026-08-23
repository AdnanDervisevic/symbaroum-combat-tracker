(** When a blow knocks a combatant prone. *)

open! Core

type t = private
  | No_threshold
  | Every_hit
  | At_least of int
[@@deriving compare, equal, hash, sexp_of, quickcheck]

val no_threshold : t
val every_hit : t

(** [at_least n] is {!every_hit} for [n <= 0], since a threshold of zero or less
    is met by any blow. *)
val at_least : int -> t

(** The React spelling: [None] is {!no_threshold}, [Some 0] is {!every_hit}. *)
val of_int_option : int option -> t

val to_int_option : t -> int option

(** [damage] is the damage {i dealt}, after armour and after clamping. *)
val is_exceeded : t -> damage:int -> bool
