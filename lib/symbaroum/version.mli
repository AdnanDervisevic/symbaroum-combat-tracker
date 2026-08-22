(** Build identity for the OCaml port.

    This module exists so the Phase 0 toolchain spike has something real to
    compile: a [.ml]/[.mli] pair, a [Core] dependency, and a [ppx_jane]
    derivation. If this builds, the toolchain is sound. *)

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
