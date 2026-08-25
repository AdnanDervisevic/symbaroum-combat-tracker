(** The fight: who is in it, whose turn it is, and which round it is. *)

open! Core

type t = private
  | Empty of { name_counter : Name_counter.t }
  | Active of
      { members : Combatant.t Ids.Combatant_id.Map.t
      ; order : Ids.Combatant_id.t Turn_order.t
      ; round : Round.t
      ; name_counter : Name_counter.t
      }
[@@deriving compare, equal, sexp_of]

include Invariant.S with type t := t

val empty : t

(** The one place [turnIndex] and [round] are repaired.

    A member whose id is already taken gets a fresh one derived from it, rather
    than being dropped: losing a combatant out of a saved fight is worse than
    renaming one. [name_counter] is [None] for saves written before the counter
    existed, in which case it is rebuilt from the names present. *)
val create
  :  members:Combatant.t list
  -> turn_index:int
  -> round:int
  -> name_counter:Name_counter.t option
  -> t * Normalization.t list

(** In turn order. *)
val members : t -> Combatant.t list

val find : t -> Ids.Combatant_id.t -> Combatant.t option
val mem : t -> Ids.Combatant_id.t -> bool
val length : t -> int
val is_empty : t -> bool

(** [Round.first] for an empty encounter, which is what the React app shows. *)
val round : t -> Round.t

val name_counter : t -> Name_counter.t
val set_name_counter : t -> Name_counter.t -> t

(** Whose turn it is. [None] only when the encounter is empty. *)
val current : t -> Combatant.t option

val current_id : t -> Ids.Combatant_id.t option

(** Zero-based, for the UI. [None] when empty -- which is the pairing the React
    type could not express. *)
val turn_index : t -> int option

(** Appends, in order. An id already in the fight is skipped, and so is one that
    appears twice within [additions] itself -- this is total for any list, which
    is what the [Map] behind {!Active} needs and what a caller building ids from
    a counter cannot be trusted to guarantee. {!Symbaroum.World} rejects a batch
    with a repeat rather than relying on the skip, because adding two NPCs when
    three were asked for is not a silence anyone wants.

    The counter is passed in because the caller is the one that took the numbers
    out of it. *)
val add : t -> name_counter:Name_counter.t -> Combatant.t list -> t

(** Removing the combatant whose turn it is moves the cursor to the next one, or
    to the new last if there is none. Removing the last combatant leaves
    {!Empty}, which is where the round resets -- and the only place it does. *)
val remove : t -> Ids.Combatant_id.t -> t

(** Removes every combatant satisfying [f]. *)
val remove_if : t -> f:(Combatant.t -> bool) -> t

(** A no-op if the id is absent. *)
val update : t -> Ids.Combatant_id.t -> f:(Combatant.t -> Combatant.t) -> t

val map_members : t -> f:(Combatant.t -> Combatant.t) -> t

(** A no-op at the ends of the order. The combatant whose turn it is keeps its
    turn, even if it is the one that moved. *)
val move : t -> Ids.Combatant_id.t -> [ `Up | `Down ] -> t

(** Descending initiative, stable, cursor to the front. Cannot touch
    {!round} -- see the note at the top of this file. *)
val sort_by_initiative : t -> t

(** [`Wrapped] when the turn came back round to the first combatant, which is
    what advances {!round}. *)
val next_turn : t -> t * [ `Wrapped | `Same_round ]

(** Stepping back past the first combatant walks the round back too, flooring at
    {!Round.first}. *)
val prev_turn : t -> t * [ `Wrapped | `Same_round ]

(** Standing and down, for the end-of-round summary. *)
val tally : t -> [ `Standing of int ] * [ `Down of int ]
