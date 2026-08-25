(** Armour, as the GM typed it, together with whatever the parser could make of it. *)

open! Core

module Reduction : sig
  (** How much damage the armour absorbs. *)
  type t =
    | Unarmored
    | Fixed of int
    | Rolled of Dice.t
  [@@deriving compare, equal, sexp_of, quickcheck]

  val min_value : t -> int
  val max_value : t -> int

  (** What the probability model uses. Damage is convolved against the full
      distribution, not against this; [mean] is for display. *)
  val mean : t -> float
end

type t = private
  { text : string (** exactly what the user typed, stripped of edge whitespace *)
  ; reduction : Reduction.t option (** [None] when {!text} could not be parsed *)
  }
[@@deriving compare, equal, sexp_of, quickcheck]

(** Note that this compares {!text}, not {!Reduction}: ["0"] and [""] are both
    unarmoured but are not the same armour, because they are not the same thing
    to show the user. Compare [reduction] directly for the rules question. *)

val unarmored : t
val parse : string -> t

(** [parse] of a missing or [null] JSON field. Equivalent to [parse ""]. *)
val none : t

val is_unparsed : t -> bool
