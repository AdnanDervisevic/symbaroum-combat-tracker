(** What a combatant hits with. *)

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
