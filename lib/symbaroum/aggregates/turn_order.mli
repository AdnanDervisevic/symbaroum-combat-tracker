(** A nonempty list with a cursor: who is up, who is before them, who is after. *)

open! Core

type 'a t = private
  { before : 'a list (** nearest first, so the head is the previous turn *)
  ; current : 'a
  ; after : 'a list
  }
[@@deriving compare, equal, sexp_of]

val singleton : 'a -> 'a t

(** [None] on the empty list. This is the only way in, so a caller has to say
    what an empty encounter means to it. *)
val of_list : 'a list -> 'a t option

(** [focus] is clamped into range, and the clamp is reported. This is the one
    place turn-index repair happens. *)
val of_list_with_focus : 'a list -> focus:int -> ('a t * Normalization.t list) option

val to_list : 'a t -> 'a list
val current : 'a t -> 'a
val length : 'a t -> int

(** Zero-based position of {!current}. *)
val index : 'a t -> int

(** Advances, wrapping. The flag says whether the wrap happened, which is what
    tells {!Symbaroum.Encounter} to advance the round. *)
val next : 'a t -> 'a t * [ `Wrapped | `Same_round ]

(** Steps back, wrapping. The flag says whether it wrapped backwards past the
    first combatant. *)
val prev : 'a t -> 'a t * [ `Wrapped | `Same_round ]

(** Puts the cursor on the first element satisfying [f], or leaves it alone. *)
val focus : 'a t -> f:('a -> bool) -> 'a t

(** Removes the first element satisfying [f]. [None] if that was the only
    element. If it was the current one, the cursor moves to the next element, or
    to the new last if there is none -- which is the React behaviour, minus the
    case where it left the index dangling. *)
val remove : 'a t -> f:('a -> bool) -> 'a t option

(** Moves the element satisfying [f] one place up or down. A no-op at the edges.
    {!current} keeps pointing at the same {i element}, not the same index. *)
val move : 'a t -> f:('a -> bool) -> [ `Up | `Down ] -> 'a t

(** Appends, keeping the cursor where it is. *)
val add_last : 'a t -> 'a -> 'a t

(** A stable sort that puts the cursor back on the first element. Cannot touch
    anything outside this type -- see the note above. *)
val sort_by : 'a t -> compare:('a -> 'a -> int) -> 'a t

val map : 'a t -> f:('a -> 'b) -> 'b t
val exists : 'a t -> f:('a -> bool) -> bool
