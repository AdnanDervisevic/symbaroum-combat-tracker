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

let apply (combatant : Combatant.t) t =
  match t with
  | Set_name name -> { combatant with name }
  | Set_initiative initiative -> { combatant with initiative }
  | Set_toughness toughness -> { combatant with toughness }
  | Set_max_toughness max ->
    (* Out of range leaves the combatant alone. A patch is applied inside the
       reducer, where there is nobody to report an error to; the UI is what
       stops an illegal number from getting this far. *)
    { combatant with
      toughness =
        Option.value
          (Or_error.ok (Toughness.with_max combatant.toughness max))
          ~default:combatant.toughness
    }
  | Set_defense defense -> { combatant with defense }
  | Set_armor armor -> { combatant with armor }
  | Set_pain_threshold pain_threshold -> { combatant with pain_threshold }
  | Set_prone prone -> { combatant with prone }
  | Set_flanked flanked -> { combatant with flanked }
  | Set_note note -> { combatant with note }
  | Set_attribute (attribute, value) ->
    { combatant with attributes = Attributes.set combatant.attributes attribute value }
  | Set_attack attack -> { combatant with attack }
;;

let field = function
  | Set_name _ -> "name"
  | Set_initiative _ -> "initiative"
  | Set_toughness _ -> "toughness"
  | Set_max_toughness _ -> "max_toughness"
  | Set_defense _ -> "defense"
  | Set_armor _ -> "armor"
  | Set_pain_threshold _ -> "pain_threshold"
  | Set_prone _ -> "prone"
  | Set_flanked _ -> "flanked"
  | Set_note _ -> "note"
  | Set_attribute (attribute, _) -> "attribute." ^ Attribute.to_key attribute
  | Set_attack _ -> "attack"
;;
