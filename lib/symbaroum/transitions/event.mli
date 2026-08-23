(** Something worth telling the user about, returned by
    {!Symbaroum.World.apply} rather than fired from inside it.

    This deletes the ugliest code in the React app. [applyAdjustment]
    ({{:src/App.tsx} [App.tsx:398]}) needs to raise a toast when a blow exceeds a
    pain threshold, but the only place it knows that is inside the [members.map]
    callback of a [setEncounter] updater -- which must be pure, and which React
    may call twice. So it declares a mutable ref outside, writes to it from
    inside the mapper, reads it after [setEncounter] returns, and schedules the
    flash through [setTimeout(..., 0)] to dodge a batching problem.

    Returning the events instead makes the reducer pure, makes the toast text
    something a test can assert, and removes the timer. Which is the point worth
    making about it: the fix is not "be careful with the ref", it is a different
    signature. *)

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
