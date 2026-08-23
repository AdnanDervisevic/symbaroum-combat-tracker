(** Defence, held as the {i absolute roll-under target} an attacker must beat. *)

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
