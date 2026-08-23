open! Core

type t =
  { monster_type : Monster_type.t option
  ; name : Name.t option
  ; count : Npc_count.t
  ; initiative : Initiative.t
  ; toughness : Toughness.t
  ; defense : Defense.t
  ; armor : Armor.t
  ; pain_threshold : Pain_threshold.t
  ; attributes : Attributes.t
  ; attack : Attack_profile.t option
  ; note : string
  }
[@@deriving compare, equal, fields ~getters, sexp_of, quickcheck]

let default =
  { monster_type = None
  ; name = None
  ; count = Npc_count.of_int_exn 1
  ; initiative = Initiative.zero
  ; toughness = Toughness.create_exn ~current:10 ~max:10
  ; defense = Or_error.ok_exn (Defense.of_modifier 0)
  ; armor = Armor.parse "Light (d4)"
  ; pain_threshold = Pain_threshold.no_threshold
  ; attributes = Attributes.empty
  ; attack = None
  ; note = ""
  }
;;

let of_preset (preset : Monster_preset.t) =
  { default with
    monster_type = Some preset.name
  ; initiative = Monster_preset.initiative preset
  ; toughness = Option.value preset.toughness ~default:default.toughness
  ; defense = Option.value preset.defense ~default:default.defense
  ; armor = preset.armor
  ; pain_threshold = preset.pain_threshold
  ; attributes = preset.attributes
  ; attack = preset.attack
  }
;;

let of_bestiary_entry (entry : Bestiary.Entry.t) =
  { default with
    monster_type = Some entry.monster_type
  ; initiative = entry.initiative
  ; toughness = entry.toughness
  ; defense = entry.defense
  ; armor = entry.armor
  ; pain_threshold = entry.pain_threshold
  ; attributes = entry.attributes
  ; attack = entry.attack
  ; note = entry.note
  }
;;

let naming_key t = Option.value t.monster_type ~default:Name_counter.anonymous

let names t ~name_counter =
  let count = Npc_count.to_int t.count in
  match t.name with
  | Some base ->
    (* A hand-typed name does not go through the counter, exactly as in the React
       original: it is the GM overriding the naming, not extending it. *)
    ( name_counter
    , if count = 1
      then [ base ]
      else
        List.init count ~f:(fun i -> Name.of_string [%string "%{base#Name} %{i + 1#Int}"])
    )
  | None ->
    let key = naming_key t in
    let name_counter, numbers = Name_counter.next_n name_counter key count in
    name_counter, List.map numbers ~f:(fun n -> Name.numbered ~base:key n)
;;

let to_combatants t ~ids ~names =
  List.map2_exn ids names ~f:(fun id name ->
    { Combatant.id
    ; allegiance = Non_player t.monster_type
    ; name
    ; initiative = t.initiative
    ; toughness = t.toughness
    ; defense = t.defense
    ; armor = t.armor
    ; pain_threshold = t.pain_threshold
    ; prone = false
    ; flanked = false
    ; attributes = t.attributes
    ; attack = t.attack
    ; note = t.note
    })
;;

let to_bestiary_entry t ~id ~at =
  Option.map t.monster_type ~f:(fun monster_type ->
    { Bestiary.Entry.id
    ; monster_type
    ; initiative = t.initiative
    ; toughness = t.toughness
    ; defense = t.defense
    ; armor = t.armor
    ; pain_threshold = t.pain_threshold
    ; attributes = t.attributes
    ; attack = t.attack
    ; note = t.note
    ; updated_at = at
    })
;;
