(** One edit to one roster entry. The same argument as
    {!Symbaroum.Member_patch}: [updateCharacter]
    ({{:src/App.tsx} [App.tsx:104]}) takes a [Partial<Character>], which is a
    type that says less than the code means. *)

open! Core

type t =
  | Set_name of Name.t
  | Set_role of string
  | Set_initiative of Initiative.t
  | Set_toughness of Toughness.t
  | Set_max_toughness of int
  | Set_defense of Defense.t
  | Set_armor of Armor.t
  | Set_pain_threshold of Pain_threshold.t
  | Set_note of string
  | Set_attribute of Attribute.t * Attribute_value.t option
[@@deriving compare, equal, sexp_of, quickcheck]

val apply : Character.t -> t -> Character.t
val field : t -> string
