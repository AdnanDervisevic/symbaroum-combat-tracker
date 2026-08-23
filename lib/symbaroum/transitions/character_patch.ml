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

let apply (character : Character.t) t =
  match t with
  | Set_name name -> { character with name }
  | Set_role role -> { character with role }
  | Set_initiative initiative -> { character with initiative }
  | Set_toughness toughness -> { character with toughness }
  | Set_max_toughness max ->
    { character with
      toughness =
        Option.value
          (Or_error.ok (Toughness.with_max character.toughness max))
          ~default:character.toughness
    }
  | Set_defense defense -> { character with defense }
  | Set_armor armor -> { character with armor }
  | Set_pain_threshold pain_threshold -> { character with pain_threshold }
  | Set_note note -> { character with note }
  | Set_attribute (attribute, value) ->
    { character with attributes = Attributes.set character.attributes attribute value }
;;

let field = function
  | Set_name _ -> "name"
  | Set_role _ -> "role"
  | Set_initiative _ -> "initiative"
  | Set_toughness _ -> "toughness"
  | Set_max_toughness _ -> "max_toughness"
  | Set_defense _ -> "defense"
  | Set_armor _ -> "armor"
  | Set_pain_threshold _ -> "pain_threshold"
  | Set_note _ -> "note"
  | Set_attribute (attribute, _) -> "attribute." ^ Attribute.to_key attribute
;;
