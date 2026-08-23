(** Build identity for the OCaml port. *)

open! Core

(** The port's own version, independent of the React app's [package.json]. *)
val port_version : string

(** Which upstream React revision the port targets. *)
type upstream =
  { branch : string
  ; app : string
  }
[@@deriving sexp_of, compare, equal]

val upstream : upstream
