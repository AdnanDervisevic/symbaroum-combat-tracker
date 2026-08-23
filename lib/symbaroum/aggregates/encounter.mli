(** The fight: who is in it, whose turn it is, and which round it is.

    This is the type that matters most in the port, because it deletes two of the
    app's real bugs by construction rather than by fixing them.

    {1 There is no such thing as an out-of-range turn}

    [EncounterState] in {{:src/types.ts} [types.ts]} is
    [{ members: Combatant[]; turnIndex: number; round: number }], so
    [{members: [], turnIndex: 5, round: 0}] typechecks. It is not hypothetical:
    four paths produce it -- [handleImport], [restoreEncounter],
    [deleteCharacter] (which prunes members and leaves the index where it was)
    and any hand-edited [localStorage]. Splitting the type into {!Empty} and
    {!Active}, and putting the cursor inside a nonempty
    {!Symbaroum.Turn_order.t}, removes the pairing that could disagree.

    {1 Sorting cannot reset the round}

    [sortByInitiative] ({{:src/App.tsx} [App.tsx:340]}) sets
    [round: prev.members.length ? 1 : prev.round], so sorting mid-fight silently
    throws the round away. The fix here is not a corrected line: [round] lives in
    this type, {i outside} {!Symbaroum.Turn_order.t}, and sorting is
    {!Symbaroum.Turn_order.sort_by}, which has no round in scope to reset. The
    bug is unreachable rather than repaired.

    {1 Round normalization happens here and nowhere else}

    {!create} is the single place a turn index or a round number is range-checked
    -- not in the decoder, not in the migration, not in the UI. Everything it
    repairs comes back as a {!Symbaroum.Normalization.t}. *)

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

(** Appends, in order. Ids already present are skipped. The counter is passed in
    because the caller is the one that took the numbers out of it. *)
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
