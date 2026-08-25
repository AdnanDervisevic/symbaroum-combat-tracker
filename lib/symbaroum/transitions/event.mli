(** Something worth telling the user about, returned by {!Symbaroum.World.apply} rather than fired from inside it. *)

open! Core

type t =
  | Pain_threshold_exceeded of
      { name : Name.t
      ; damage : int
      }
  | Combatant_downed of { name : Name.t }
  | Round_completed of
      { round : Round.t
      ; standing : int
      ; down : int
      }
  | Encounter_archived of { label : string }
  | Encounter_restored of { label : string }
  | Data_normalized of Normalization.t list
  | Rejected of { reason : string }
[@@deriving compare, equal, sexp_of]

(** The toast text. *)
val to_string_hum : t -> string

val severity : t -> [ `Info | `Success | `Warning | `Error ]
