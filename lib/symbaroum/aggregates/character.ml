open! Core

type t =
  { id : Ids.Character_id.t
  ; name : Name.t
  ; role : string
  ; initiative : Initiative.t
  ; toughness : Toughness.t
  ; defense : Defense.t
  ; armor : Armor.t
  ; pain_threshold : Pain_threshold.t
  ; attributes : Attributes.t
  ; note : string
  ; is_builtin : bool
  }
[@@deriving compare, equal, fields ~getters, sexp_of, quickcheck]

let create_new ~id =
  { id
  ; name = Name.of_string "New PC"
  ; role = ""
  ; initiative = Initiative.zero
  ; toughness = Toughness.create_exn ~current:10 ~max:10
  ; defense = Or_error.ok_exn (Defense.of_modifier 0)
  ; armor = Armor.parse "Light (d4)"
  ; pain_threshold = Pain_threshold.no_threshold
  ; attributes = Attributes.empty
  ; note = ""
  ; is_builtin = false
  }
;;

let defense_modifier t = Defense.to_modifier t.defense
