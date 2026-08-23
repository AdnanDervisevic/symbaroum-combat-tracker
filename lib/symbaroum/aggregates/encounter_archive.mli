(** The last few cleared encounters, newest first, so a fight cleared by mistake
    can be brought back.

    The capacity is a property of the value rather than of the one call site that
    remembers to slice -- see {!Symbaroum.Bounded_list}. *)

open! Core

module Entry : sig
  type t =
    { id : Ids.Snapshot_id.t
    ; at : Time_ns.Alternate_sexp.t
    ; label : string
    ; encounter : Encounter.t
    }
  [@@deriving compare, equal, fields ~getters, sexp_of]

  (** ["Round 3 - 4 PCs, 6 NPCs"], the label
      [clearEncounter] ({{:src/App.tsx} [App.tsx:352]}) builds. *)
  val label_for : Encounter.t -> string
end

type t [@@deriving compare, equal, sexp_of]

(** Ten, as [MAX_HISTORY_ENTRIES] in {{:src/App.tsx} [App.tsx:79]}. *)
val capacity : int

val empty : t
val of_list : Entry.t list -> t

(** Newest first. *)
val to_list : t -> Entry.t list

val add : t -> Entry.t -> t
val find : t -> Ids.Snapshot_id.t -> Entry.t option
val remove : t -> Ids.Snapshot_id.t -> t
val length : t -> int
