(** Every rule the model knows about hitting, in one function.

    That is the whole design of this module. The Symbaroum rules used here are a
    {b reconstruction}, and a reconstruction is going to be wrong somewhere, so
    the thing that matters is that correcting it is a one-line diff rather than a
    search. Nothing else in {!Symbaroum.Attrition_dp} or
    {!Symbaroum.Combat_sim} knows how a roll works.

    {1 The rule as modelled}

    Symbaroum rolls a d20 {i under} a target. An attack's target is the
    attacker's Accurate, shifted by the defender's Defence expressed as a
    modifier:

    {v
      target  = Accurate_attacker + (10 - Defence_defender) + situation
      p(hit)  = clamp target to [1, 19] / 20
    v}

    {!Symbaroum.Defense} stores the absolute roll-under value, so
    [10 - Defence] is exactly {!Symbaroum.Defense.to_modifier}. The clamp is what
    makes a natural 1 always hit and a natural 20 always miss, so no matchup is
    ever certain in either direction.

    {1 What is confident and what is not}

    The shape of the formula is reasonably confident. The two situational
    modifiers below are {b not verified against the core book} and are stated as
    guesses in [doc/model.md]; they are named constants here so that a reader can
    see their size and change them without reading any other file. *)

open! Core

(** How much easier a prone defender is to hit. {b Unverified.} *)
val prone_bonus : int

(** How much easier a flanked defender is to hit. {b Unverified.} Flanking is a
    per-combatant flag the GM sets, not something the model works out, so it is a
    static property of a defender rather than part of the fight's state. *)
val flanked_bonus : int

(** A natural 1 always hits and a natural 20 always misses, so the target is
    clamped into [min_target .. max_target]. *)
val min_target : int

val max_target : int

(** The clamped roll-under target, for a test or a UI that wants to show the
    number rather than the probability. *)
val target
  :  attacker_accurate:Attribute_value.t
  -> defender_defense:Defense.t
  -> defender_prone:bool
  -> defender_flanked:bool
  -> int

val of_matchup
  :  attacker_accurate:Attribute_value.t
  -> defender_defense:Defense.t
  -> defender_prone:bool
  -> defender_flanked:bool
  -> float
