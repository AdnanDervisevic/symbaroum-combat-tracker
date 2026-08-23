(** Every rule the model knows about hitting, in one function.

    {v
      target = Accurate_attacker + (10 - Defence_defender) + situation
      p(hit) = clamp target to [1, 19] / 20
    v}

    The rules are a {b reconstruction}. Keeping them in one function is what
    makes correcting one a one-line diff; [doc/model.md] says which parts are
    confident and which are guesses. *)

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
