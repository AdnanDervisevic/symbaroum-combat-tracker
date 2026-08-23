open! Core

let builtin_prefix = "pc_default_"

(* The v1 [defense] field has two readings, and which one applies depends on
   whose sheet the number came from. A player character's is the target the GM
   reads off the sheet and rolls under. A monster's is the modifier the preset
   table prints, which is [10 - target]. They are the same quantity written two
   ways, so v2 keeps one of them -- the target -- and the choice happens here,
   at the only place that still knows which kind of row it is looking at.

   Out of range is not this module's problem; [Domain_conv] clamps and reports
   it. That matters for the four shipped characters, two of which v1 stored as
   [0] while their sheets were still blank. *)
let of_pc_sheet target = target
let of_npc_table modifier = 10 - modifier

(* The three spellings of "no attributes" -- missing, [null] and [{}] -- collapse
   here into the one value the domain has. *)
let attributes (a : Wire_v1.Attributes.t option) : Wire_v2.Attributes.t =
  match a with
  | None -> Wire_v2.Attributes.empty
  | Some { acc; cun; dis; per; qui; res; str; vig } ->
    { acc; cun; dis; per; qui; res; str; vig }
;;

let character (c : Wire_v1.Character.t) : Wire_v2.Character.t =
  { id = c.id
  ; name = c.name
  ; role = c.role
  ; initiative = c.initiative
  ; toughness = { current = c.toughness; max = c.toughness }
  ; defense = of_pc_sheet c.defense
  ; armor = c.armor
  ; pain_threshold = c.pain_threshold
  ; attributes = attributes c.attributes
  ; note = c.note
  ; is_builtin = String.is_prefix c.id ~prefix:builtin_prefix
  }
;;

let allegiance (c : Wire_v1.Combatant.t) : Wire_v2.Combatant.Allegiance.t =
  match c.source, c.ref_id with
  | "pc", Some ref_id -> Player_character ref_id
  (* [{source: 'pc'}] with no [refId] is a state the React type permits and
     nothing produces on purpose. It has no character to point at, so it is an
     NPC. *)
  | _, _ -> Non_player c.monster_type
;;

let combatant ~full_health (c : Wire_v1.Combatant.t) : Wire_v2.Combatant.t =
  let allegiance = allegiance c in
  let max =
    (* Never below what the combatant currently has, or the pair is illegal. *)
    Int.max c.toughness (Option.value (full_health allegiance) ~default:c.toughness)
  in
  { id = c.id
  ; allegiance
  ; name = c.name
  ; initiative = c.initiative
  ; toughness = { current = c.toughness; max }
  ; defense =
      (match allegiance with
       | Player_character _ -> of_pc_sheet c.defense
       | Non_player _ -> of_npc_table c.defense)
  ; armor = c.armor
  ; pain_threshold = c.pain_threshold
  ; prone = c.prone
  ; flanked = c.flanked
  ; attributes = attributes c.attributes
  ; attack = None (* v1 records no weapon data at all *)
  ; note = c.note
  }
;;

let encounter ~full_health (e : Wire_v1.Encounter.t) : Wire_v2.Encounter.t =
  { members = List.map e.members ~f:(combatant ~full_health)
  ; turn_index = e.turn_index
  ; round = e.round
  ; (* v1 has no counter at all, which is what [None] says and what tells
       [Domain_conv] to rebuild one from the names present. *)
    name_counter = None
  }
;;

let bestiary_entry (e : Wire_v1.Bestiary_entry.t) : Wire_v2.Bestiary_entry.t =
  { id = e.id
  ; monster_type = e.monster_type
  ; initiative = e.initiative
  ; toughness = { current = e.toughness; max = e.toughness }
  ; defense = of_npc_table e.defense
  ; armor = e.armor
  ; pain_threshold = e.pain_threshold
  ; (* The React bestiary entry stores no attributes, so the round trip
       preset -> encounter -> bestiary -> encounter silently loses the stat
       block. There is nothing here to recover it from; v2 keeps it from now
       on. *)
    attributes = Wire_v2.Attributes.empty
  ; attack = None
  ; note = e.note
  ; updated_at_ms = e.updated_at_ms
  }
;;

let v1_to_v2 (t : Wire_v1.t) : Wire_v2.t =
  (* The two places a combatant's lost maximum can be recovered from. *)
  let roster_max =
    String.Map.of_alist_reduce
      (List.map t.characters ~f:(fun (c : Wire_v1.Character.t) -> c.id, c.toughness))
      ~f:(fun first _ -> first)
  in
  let bestiary_max =
    String.Map.of_alist_reduce
      (List.map t.bestiary ~f:(fun (e : Wire_v1.Bestiary_entry.t) ->
         e.monster_type, e.toughness))
      ~f:(fun first _ -> first)
  in
  let full_health : Wire_v2.Combatant.Allegiance.t -> int option = function
    | Player_character id -> Map.find roster_max id
    | Non_player (Some monster_type) -> Map.find bestiary_max monster_type
    | Non_player None -> None
  in
  { version = Wire_v2.version
  ; characters = List.map t.characters ~f:character
  ; encounter = encounter ~full_health t.encounter
  ; bestiary = List.map t.bestiary ~f:bestiary_entry
  ; archive =
      List.map t.history ~f:(fun (e : Wire_v1.History_entry.t) ->
        { Wire_v2.Archive_entry.id = e.id
        ; at_ms = e.timestamp_ms
        ; label = e.label
        ; encounter = encounter ~full_health e.encounter
        })
  }
;;
