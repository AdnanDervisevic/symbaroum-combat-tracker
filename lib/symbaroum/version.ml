open! Core

let port_version = "0.1.0-dev"

type upstream =
  { branch : string
  ; app : string
  }
[@@deriving sexp_of, compare, equal]

let upstream = { branch = "master"; app = "symbaroum-combat-tracker" }
