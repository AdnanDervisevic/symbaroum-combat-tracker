(** A monster preset's difficulty band. *)

open! Core

type t =
  | Weak
  | Ordinary
  | Challenging
  | Strong
  | Mighty
  | Legendary
[@@deriving enumerate, of_sexp, quickcheck]

include Identifiable.S_plain with type t := t
