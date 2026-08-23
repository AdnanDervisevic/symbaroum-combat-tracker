(** One edit to one combatant.

    [updateMember] ({{:src/App.tsx} [App.tsx:291]}) takes a
    [Partial<Combatant>] and shallow-merges it, which means it can set {i any}
    field to {i any} value of that field's type -- including [source], including
    a negative [toughness], including an [id] that collides with another
    member's. The type says "some of a combatant"; the code means "one of these
    nine things". Writing down which nine costs a variant and buys the
    difference. *)

open! Core

type t =
  | Set_name of Name.t
  | Set_initiative of Initiative.t
  | Set_toughness of Toughness.t
  | Set_max_toughness of int
  | Set_defense of Defense.t
  | Set_armor of Armor.t
  | Set_pain_threshold of Pain_threshold.t
  | Set_prone of bool
  | Set_flanked of bool
  | Set_note of string
  | Set_attribute of Attribute.t * Attribute_value.t option
  | Set_attack of Attack_profile.t option
[@@deriving compare, equal, sexp_of, quickcheck]

val apply : Combatant.t -> t -> Combatant.t

(** Which field this touches. Two edits to the same field of the same combatant
    collapse into one undo entry -- see {!Symbaroum.Undo_history.push}. *)
val field : t -> string
