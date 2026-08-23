(** Defence, held as the {i absolute roll-under target} an attacker must beat.

    This is the scalar the Phase 2 data problem lives in, so it is worth being
    precise. Symbaroum expresses a creature's defence two ways, and the preset
    file uses both in the same [number]-typed field:

    - as a {b modifier} applied to the attacker's Accurate, equal to [10 - Quick]
      -- Spring Elf has [qui: 13, defense: -3];
    - as an {b absolute target}, equal to Quick itself -- Servant Daemon has
      [qui: 15, defense: 15].

    They are the same quantity in two spellings, related by [10 - x]. Nothing in
    the React app reads [defense] except a ratio in the difficulty heuristic, so
    today the inconsistency is invisible. The moment defence becomes a to-hit
    target it decides every roll.

    This module stores the target form and offers both constructors, which forces
    the question open at the point of construction: {!of_modifier} on [-3] and
    {!of_target} on [13] both give the same value, and a caller must say which
    spelling it has. The reconciliation of the 86 presets is a Phase 2 golden
    test, so it lands as a reviewable diff rather than a silent rewrite. *)

open! Core
include Bounded_int.S

(** An alias for {!of_int}, named so that a call site has to say which of the two
    spellings it is reading. *)
val of_target : int -> t Or_error.t

(** The attacker's effective target is their Accurate plus this, which is
    [10 - target]. *)
val to_modifier : t -> int

(** [of_modifier m = of_int (10 - m)]. *)
val of_modifier : int -> t Or_error.t

(** Defence derived from the Quick attribute, which is the rules default. *)
val of_quick : Attribute_value.t -> t
