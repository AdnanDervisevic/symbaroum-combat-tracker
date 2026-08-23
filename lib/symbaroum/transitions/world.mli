(** All four stores, and the one function that moves between them.

    The React app keeps [characters], [encounter], [bestiary] and
    [encounterHistory] in four separate hooks, and several transitions have to
    write two of them. [addNpc] writes the encounter and the bestiary in two
    [setState] calls; [clearEncounter] writes the encounter and the history. Two
    calls means a render can land between them with the stores disagreeing, and
    it means undo -- which wraps only the encounter -- covers half the change.
    One record and one {!apply} makes each transition atomic and makes undo cover
    all of it.

    {!apply} is {b pure and total}. Every command produces a world and a list of
    events; nothing raises, nothing reads a clock, nothing allocates an id. A
    command that cannot be carried out returns the world unchanged and an
    {!Symbaroum.Event.Rejected} saying so, which is a thing a test can read. *)

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
