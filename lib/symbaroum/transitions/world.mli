(** All four stores, and the one function that moves between them. *)

open! Core

type t =
  { roster : Roster.t
  ; encounter : Encounter.t
  ; bestiary : Bestiary.t
  ; archive : Encounter_archive.t
  }
[@@deriving compare, equal, sexp_of]

include Invariant.S with type t := t

(** A fresh install: the four shipped characters, no fight, no bestiary. *)
val initial : t

val empty : t
val apply : t -> Action.t -> t * Event.t list

(** Folds a script, accumulating the events in order. This is what the transcript
    test and the [Action.t list] property tests run. *)
val apply_all : t -> Action.t list -> t * Event.t list
