(** A combatant as the model needs it, with every gap in the data filled in once and written down. *)

open! Core

type t = private
  { name : Name.t
  ; order : int (** where this combatant sits in the encounter *)
  ; initiative : int
  ; toughness : int (** current, and at least 1 *)
  ; defense : Defense.t
  ; flanked : bool
  ; prone : bool (** at the moment the question is asked *)
  ; pain_threshold : Pain_threshold.t
  ; accurate : Attribute_value.t
  ; weapon : Pmf.t (** damage before the defender's armour *)
  ; armor : Pmf.t
  ; caveats : Caveat.t list
  }
[@@deriving compare, equal, sexp_of]

(** [None] for a combatant who is already down. *)
val of_combatant : Combatant.t -> order:int -> t option

(** The Accurate assumed for a combatant that records none. *)
val assumed_accurate : Attribute_value.t

(** The damage die assumed for a combatant that records none: the [Ordinary]
    prior, since a combatant with no resistance band has no better one. *)
val assumed_weapon : Dice.t

(** [damage_against attacker ~defender] is the exact distribution of
    [max 0 (weapon - armour)], convolved rather than sampled. *)
val damage_against : t -> defender:t -> Pmf.t

(** The chance [attacker] lands a blow on [defender], given whether the defender
    is on the ground. All the rules live in {!Symbaroum.Hit_chance}. *)
val hit_chance : t -> defender:t -> defender_prone:bool -> float
