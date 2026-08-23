(** Past, present and future, with a bound on the past.

    {{:src/hooks/usePersistentHistory.ts} [usePersistentHistory.ts]} has two bugs
    that this type is shaped to make unreachable.

    {b The bound is enforced in three of four places.} [setState] slices [past]
    to the last 50; [redo] (line 112) appends to it and does not. So undo/redo
    ping-pong grows the past without limit, and since the whole thing is
    serialised into [localStorage], it grows the saved blob too. Here the
    capacity travels with the value -- see {!Symbaroum.Bounded_list} for the same
    argument -- so there is no fourth call site to forget.

    {b The deduplication never fires.} Line 83 is
    [if (newPresent === prev.present) return prev], a JavaScript {i reference}
    comparison against a freshly built object literal, which is never equal.
    Every keystroke in a note field therefore burns an undo slot, and a sentence
    of typing evaporates all fifty. {!push} takes an [equal] so the comparison is
    structural, and a [key] so that a run of edits to the same field collapses
    into one entry rather than fifty. *)

open! Core

type 'a t [@@deriving compare, equal, sexp_of]

(** Fifty, as [MAX_HISTORY] in the React hook. *)
val default_capacity : int

val create : ?capacity:int -> 'a -> 'a t
val present : 'a t -> 'a

(** [push t next ~equal ~key] records [next] as the new present.

    - If [equal] says [next] is the present, nothing happens at all: no entry, no
      cleared future.
    - If [key] is [Some k] and the previous push carried the same key, [next]
      {i replaces} the present rather than pushing it, so a run of edits to one
      field costs one undo. [None] never coalesces.
    - Otherwise the present moves into the past, the oldest entry is dropped if
      the past is full, and the future is cleared. *)
val push : 'a t -> 'a -> equal:('a -> 'a -> bool) -> key:string option -> 'a t

val undo : 'a t -> 'a t option
val redo : 'a t -> 'a t option
val can_undo : 'a t -> bool
val can_redo : 'a t -> bool

(** How many entries the past holds. Never more than the capacity, under any
    sequence of pushes, undos and redos -- which is the property test. *)
val depth : 'a t -> int

val future_depth : 'a t -> int
val capacity : 'a t -> int

(** Present and past, newest first, for persistence. The future is deliberately
    dropped: a redo stack that survives a page reload is a promise the app
    cannot keep, since the state it would redo into was never saved. *)
val to_persistable : 'a t -> keep_past:int -> 'a * 'a list

val of_persisted : ?capacity:int -> 'a -> past:'a list -> 'a t
val map : 'a t -> f:('a -> 'b) -> 'b t
