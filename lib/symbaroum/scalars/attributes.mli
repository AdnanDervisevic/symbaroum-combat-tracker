(** A creature's full attribute block: a {i key-total} map from {!Symbaroum.Attribute} to an optional score. *)

open! Core

type t [@@deriving compare, equal, sexp_of, quickcheck]

(** Every attribute present as a key, every value [None]. *)
val empty : t

(** [is_empty t] iff no attribute has a score. This is the [normalizeAttributes]
    convention -- a block of eight [None]s is indistinguishable from "no
    attributes", so it is the same value. *)
val is_empty : t -> bool

val find : t -> Attribute.t -> Attribute_value.t option
val set : t -> Attribute.t -> Attribute_value.t option -> t

(** [of_alist] is [Error] on a duplicate key. Attributes absent from the list
    are [None]; the result is key-total regardless. *)
val of_alist : (Attribute.t * Attribute_value.t option) list -> t Or_error.t

(** Always eight pairs, in [Attribute.all] order. *)
val to_alist : t -> (Attribute.t * Attribute_value.t option) list

(** Only the attributes that have a score. *)
val to_known_alist : t -> (Attribute.t * Attribute_value.t) list

val to_map : t -> Attribute_value.t option Attribute.Map.t

(** How many attributes have a score, in [0 .. 8]. *)
val count_known : t -> int
