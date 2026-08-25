(** A range-checked integer, for the several scalars in this domain that are "an [int], but only these ones". *)

open! Core

module type S = sig
  type t = private int [@@deriving compare, equal, hash, sexp_of, quickcheck]

  val min_value : int
  val max_value : int

  (** The only total way in. *)
  val of_int : int -> t Or_error.t

  val of_int_exn : int -> t

  (** Saturating. The import path uses this and {i reports} the repair as a
      normalization; nothing else should reach for it. *)
  val of_int_clamped : int -> t

  val to_int : t -> int
end

module type Arg = sig
  val module_name : string
  val min_value : int
  val max_value : int
end

module Make (_ : Arg) : S
