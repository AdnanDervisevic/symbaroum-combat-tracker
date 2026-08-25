(** Something the analysis had to guess, or could not use at all. *)

open! Core

type t =
  | No_toughness
  (** The creature has no maximum toughness, so "down" is undefined for it. *)
  | Defense_derived_from_quick of int option
  (** The stored [defense] field was absent, or was not a legal modifier, so
          defence came from the Quick attribute instead. The argument is what was
          stored, kept so the substitution is visible rather than silent. *)
  | Armor_unparsed of string
  (** {!Symbaroum.Armor.parse} could not read this text, so the model treats
          the creature as unarmoured. *)
  | Damage_die_estimated of Resistance.t
  (** The damage die was invented from the creature's resistance band. See
          {!Symbaroum.Attack_profile.damage_prior}. *)
  | No_attack_profile
  (** The combatant records no weapon, which is every player character in
          the shipped roster and every shipped preset. *)
[@@deriving compare, equal, sexp, quickcheck]

(** A sentence for the UI. *)
val to_string_hum : t -> string
