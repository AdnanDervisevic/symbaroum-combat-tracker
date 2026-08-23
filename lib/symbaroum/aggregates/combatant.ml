open! Core

module Allegiance = struct
  type t =
    | Player_character of Ids.Character_id.t
    | Non_player of Monster_type.t option
  [@@deriving compare, equal, sexp_of, quickcheck]

  let is_player = function
    | Player_character _ -> true
    | Non_player _ -> false
  ;;

  let character_id = function
    | Player_character id -> Some id
    | Non_player _ -> None
  ;;

  let naming_key = function
    | Player_character _ -> None
    | Non_player None -> Some Name_counter.anonymous
    | Non_player (Some monster_type) -> Some monster_type
  ;;
end

type t =
  { id : Ids.Combatant_id.t
  ; allegiance : Allegiance.t
  ; name : Name.t
  ; initiative : Initiative.t
  ; toughness : Toughness.t
  ; defense : Defense.t
  ; armor : Armor.t
  ; pain_threshold : Pain_threshold.t
  ; prone : bool
  ; flanked : bool
  ; attributes : Attributes.t
  ; attack : Attack_profile.t option
  ; note : string
  }
[@@deriving compare, equal, fields ~getters, sexp_of, quickcheck]

let of_character (character : Character.t) ~id =
  { id
  ; allegiance = Player_character character.id
  ; name = character.name
  ; initiative = character.initiative
  ; toughness = character.toughness
  ; defense = character.defense
  ; armor = character.armor
  ; pain_threshold = character.pain_threshold
  ; prone = false
  ; flanked = false
  ; attributes = character.attributes
  ; attack = None
  ; note = character.note
  }
;;

let sync_from_character t (character : Character.t) =
  { t with
    name = character.name
  ; armor = character.armor
  ; defense = character.defense
  ; pain_threshold = character.pain_threshold
  ; attributes = character.attributes
  }
;;

let is_down t = Toughness.is_down t.toughness

let hurt t amount =
  let toughness, dealt = Toughness.damage t.toughness amount in
  let exceeded = Pain_threshold.is_exceeded t.pain_threshold ~damage:dealt in
  ( { t with toughness; prone = t.prone || exceeded }
  , `Dealt dealt
  , `Newly_prone (exceeded && not t.prone) )
;;

let heal t amount =
  let toughness, restored = Toughness.heal t.toughness amount in
  let prone = if restored > 0 then false else t.prone in
  { t with toughness; prone }, `Restored restored
;;
