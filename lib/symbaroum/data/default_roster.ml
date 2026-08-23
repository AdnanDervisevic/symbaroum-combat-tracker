open! Core

(* [defense] here is the number on the character sheet -- the target the GM
   reads off and rolls under -- not the modifier a monster entry prints. The
   two spellings are [10 - x] apart, and [Defense] keeps the target. *)
let character ~id ~name ~role ~toughness ~defense ~armor ~note =
  { Character.id = Ids.Character_id.of_string id
  ; name = Name.of_string name
  ; role
  ; initiative = Initiative.zero
  ; toughness = Toughness.create_exn ~current:toughness ~max:toughness
  ; defense = Or_error.ok_exn (Defense.of_target defense)
  ; armor = Armor.parse armor
  ; pain_threshold = Pain_threshold.no_threshold
  ; attributes = Attributes.empty
  ; note
  ; is_builtin = true
  }
;;

let all =
  [ character
      ~id:"pc_default_cassimei"
      ~name:"Cassimei"
      ~role:"Bard"
      ~toughness:10
      ~defense:8
      ~armor:"Light (d4)"
      ~note:"Charming storyteller"
  ; character
      ~id:"pc_default_thalia"
      ~name:"Thalia"
      ~role:"Wizard"
      ~toughness:10
      ~defense:3
      ~armor:"Light (d4)"
      ~note:"Mystic scholar"
  ; character
      ~id:"pc_default_vigoi"
      ~name:"Vigoi"
      ~role:"Warrior"
      ~toughness:10
      ~defense:13
      ~armor:"Medium (d8)"
      ~note:"Placeholder stats"
  ; character
      ~id:"pc_default_ymma"
      ~name:"Ymma"
      ~role:"Goblin"
      ~toughness:10
      ~defense:13
      ~armor:"Light (d4)"
      ~note:"Placeholder stats"
  ]
;;

let ids = List.map all ~f:Character.id
