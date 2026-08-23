(** What a combatant hits with.

    The app records {i no weapon or damage data whatsoever}. The to-hit side is
    grounded -- 79 of the 86 presets carry an Accurate score -- but the damage
    die is a guess, derived from the creature's {!Symbaroum.Resistance} band.

    {!Source.t} is the reason this module exists as a record rather than a pair.
    An estimate that cannot be told apart from data is worse than no estimate:
    the analysis has to surface it as a caveat, and the UI has to let the GM
    correct it. Marking the provenance in the type is what makes forgetting to
    do either of those a compile-time question. *)

open! Core

module Source : sig
  type t =
    | From_data
    | Estimated_from_resistance of Resistance.t
  [@@deriving compare, equal, sexp_of, quickcheck]

  val is_estimated : t -> bool
end

type t = private
  { accurate : Attribute_value.t
  ; damage : Dice.t
  ; source : Source.t
  }
[@@deriving compare, equal, sexp_of, quickcheck]

val create : accurate:Attribute_value.t -> damage:Dice.t -> source:Source.t -> t

(** The prior: [Weak] and below swing a d6, [Legendary] a d12+2. Stated here in
    one place so that {!doc/model.md} can quote it and a reviewer can disagree
    with it in one edit. *)
val damage_prior : Resistance.t -> Dice.t

(** The profile used when the only thing known about a creature is its band. *)
val estimate : accurate:Attribute_value.t -> resistance:Resistance.t -> t
