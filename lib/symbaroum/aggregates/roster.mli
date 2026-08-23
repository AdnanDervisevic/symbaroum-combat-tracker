(** The player characters, in the order the Characters tab shows them.

    A map for lookup plus a list for order, rather than the React array. The map
    makes "is this id in the roster" and "update this one" logarithmic instead of
    a scan, makes duplicate ids unrepresentable, and is the shape
    [Bonsai.assoc] wants in Phase 6. The list is what keeps a character where the
    user put it, which a map keyed by a random id cannot. *)

open! Core

type t = private
  { by_id : Character.t Ids.Character_id.Map.t
  ; order : Ids.Character_id.t list
  }
[@@deriving compare, equal, sexp_of]

val empty : t

(** The four shipped characters. *)
val default : t

(** Later entries with an id already seen are dropped, and each is reported. *)
val of_list : Character.t list -> t * Normalization.t list

val to_list : t -> Character.t list
val find : t -> Ids.Character_id.t -> Character.t option
val mem : t -> Ids.Character_id.t -> bool
val length : t -> int

(** Appends. Replaces in place if the id is already present, which keeps the
    display order stable across an edit. *)
val add : t -> Character.t -> t

val remove : t -> Ids.Character_id.t -> t

(** A no-op if the id is absent. *)
val update : t -> Ids.Character_id.t -> f:(Character.t -> Character.t) -> t
