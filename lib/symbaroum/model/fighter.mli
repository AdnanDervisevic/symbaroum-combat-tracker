(** A combatant as the model needs it, with every gap in the data filled in once
    and written down.

    {1 The app records no weapons}

    Not for anybody. The four shipped player characters have
    [attributes: null] and no weapon at all, so a model that refused to guess
    would report that every party loses every fight -- which is not a cautious
    answer, it is a useless one. So a missing Accurate becomes 10, the average
    score, and a missing damage die becomes the [Ordinary] prior, {b and the
    substitution goes in {!caveats}}. A number computed from an invented weapon
    is not the same kind of number as one computed from a statblock, and the
    difference has to survive all the way to the reader of the verdict.

    {1 Toughness is where the fight is now, not where it started}

    {!toughness} is the combatant's {i current} value. A GM asking "how does this
    go" is asking from the middle of a fight, with half the party already hurt.
    This costs the model nothing: the focus-fire reduction needs later members to
    be at their {i starting} value, not at full health, and their starting value
    is whatever they have when the question is asked.

    A combatant already at zero is not a fighter at all and is dropped by
    {!of_combatant}. *)

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
