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

(** The prior: [Weak] and below swing a d6, [Legendary] a d12+2. The app records
    no weapon data at all, so this is the only stand-in there is -- and it is a
    guess, which is what {!Symbaroum.Caveat.Damage_die_estimated} exists to say
    out loud. *)
val damage_prior : Resistance.t -> Dice.t

(** The profile used when the only thing known about a creature is its band. *)
val estimate : accurate:Attribute_value.t -> resistance:Resistance.t -> t
