(** The eight Symbaroum attributes. *)

open! Core

type t =
  | Accurate
  | Cunning
  | Discreet
  | Persuasive
  | Quick
  | Resolute
  | Strong
  | Vigilant
[@@deriving enumerate, of_sexp, quickcheck]

(** [to_string] is [to_key], so sexps and [Map] keys print as the wire keys. *)
include Identifiable.S_plain with type t := t

(** The three-letter key used by the JSON wire format and by [ATTRIBUTE_FIELDS]
    in {{:src/utils/combatLogic.ts} [combatLogic.ts]}: ["acc"], ["cun"], .... *)
val to_key : t -> string

val of_key : string -> t option

(** The uppercase label the UI renders: ["ACC"], ["CUN"], .... *)
val to_label : t -> string
