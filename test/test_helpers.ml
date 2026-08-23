(** Shared fixtures and printers.

    Everything here is deterministic. Ids are spelled out rather than generated,
    and the clock is the epoch, because {!Symbaroum.World.apply} takes both as
    arguments -- which is the whole reason a combat transcript can be an expect
    test at all. *)

open! Core
open! Symbaroum

(* {1 Constructors} *)

let cid = Ids.Combatant_id.of_string
let chid = Ids.Character_id.of_string
let sid = Ids.Snapshot_id.of_string
let bid = Ids.Bestiary_id.of_string
let mt = Monster_type.of_string
let name = Name.of_string
let at = Time_ns.of_int_ns_since_epoch 0

let tough ?current max =
  Toughness.create_exn ~current:(Option.value current ~default:max) ~max
;;

let defense modifier = Or_error.ok_exn (Defense.of_modifier modifier)
let amount n = Adjust_amount.of_int_exn n
let initiative n = Initiative.of_int_exn n

let preset n =
  Option.value_exn (Monster_presets.find (mt n)) ~message:[%string "no preset %{n}"]
;;

(** A combatant with everything spelled out, for tests that do not care where it
    came from. *)
let combatant
      ?(allegiance = Combatant.Allegiance.Non_player None)
      ?(toughness = tough 10)
      ?(pain_threshold = Pain_threshold.no_threshold)
      ?(armor = Armor.unarmored)
      ?(prone = false)
      ?(attributes = Attributes.empty)
      ~id
      ~name:n
      ~initiative:init
      ()
  =
  { Combatant.id = cid id
  ; allegiance
  ; name = name n
  ; initiative = initiative init
  ; toughness
  ; defense = defense 0
  ; armor
  ; pain_threshold
  ; prone
  ; flanked = false
  ; attributes
  ; attack = None
  ; note = ""
  }
;;

(* {1 Printers} *)

let member_line ~current (c : Combatant.t) =
  let marker = if current then ">" else " " in
  let flags =
    List.filter_opt
      [ (if c.prone then Some "prone" else None)
      ; (if Combatant.is_down c then Some "DOWN" else None)
      ]
  in
  let flags =
    if List.is_empty flags then "" else " [" ^ String.concat flags ~sep:" " ^ "]"
  in
  let side =
    match c.allegiance with
    | Player_character _ -> "PC "
    | Non_player None -> "NPC"
    | Non_player (Some monster_type) -> Monster_type.to_string monster_type
  in
  sprintf
    "  %s %-14s %-8s T%d/%d%s"
    marker
    (Name.to_string c.name)
    side
    c.toughness.current
    c.toughness.max
    flags
;;

let print_encounter encounter =
  match Encounter.is_empty encounter with
  | true -> print_endline "  (no combatants)"
  | false ->
    let round = Round.to_int (Encounter.round encounter) in
    let index = Option.value_exn (Encounter.turn_index encounter) + 1 in
    let total = Encounter.length encounter in
    printf "  round %d, turn %d/%d\n" round index total;
    let current = Encounter.current_id encounter in
    List.iter (Encounter.members encounter) ~f:(fun c ->
      print_endline
        (member_line
           ~current:
             (Option.value_map current ~default:false ~f:(Ids.Combatant_id.equal c.id))
           c))
;;

(** One line of English for an action, resolving ids against the world it is
    about to be applied to.

    This lives here rather than in {!Symbaroum.Action} on purpose. The library
    owes the UI a way to {i perform} an action, not a way to narrate one, and
    nothing outside these tests wants this rendering; putting it in the library
    would be inventing a requirement to justify a function. *)
let describe_action (world : World.t) (action : Action.t) =
  let member id =
    match Encounter.find world.encounter id with
    | Some c -> Name.to_string c.name
    | None -> Ids.Combatant_id.to_string id
  in
  let character id =
    match Roster.find world.roster id with
    | Some c -> Name.to_string c.name
    | None -> Ids.Character_id.to_string id
  in
  match action with
  | Add_character { id } -> sprintf "new character %s" (Ids.Character_id.to_string id)
  | Update_character { id; patch } ->
    sprintf "edit %s: %s" (character id) (Character_patch.field patch)
  | Delete_character { id } -> sprintf "delete %s from the roster" (character id)
  | Add_player_characters { characters } ->
    sprintf
      "send %s into the fight"
      (String.concat ~sep:", " (List.map characters ~f:(fun (id, _) -> character id)))
  | Add_npcs { draft; ids; _ } ->
    sprintf
      "add %d %s"
      (List.length ids)
      (Option.value_map draft.monster_type ~f:Monster_type.to_string ~default:"NPC")
  | Update_member { id; patch } ->
    sprintf "set %s on %s" (Member_patch.field patch) (member id)
  | Adjust { id; amount; mode } ->
    sprintf
      "%s %s for %d"
      (match mode with
       | `Hurt -> "hit"
       | `Heal -> "heal")
      (member id)
      (Adjust_amount.to_int amount)
  | Remove_member { id } -> sprintf "remove %s from the fight" (member id)
  | Move_member { id; direction } ->
    sprintf
      "move %s %s the order"
      (member id)
      (match direction with
       | `Up -> "up"
       | `Down -> "down")
  | Sort_by_initiative -> "sort by initiative"
  | Next_turn -> "next turn"
  | Prev_turn -> "back one turn"
  | Clear_encounter _ -> "clear the encounter"
  | Restore_encounter { id } ->
    sprintf "restore the encounter saved as %s" (Ids.Snapshot_id.to_string id)
  | Delete_snapshot { id } -> sprintf "delete snapshot %s" (Ids.Snapshot_id.to_string id)
  | Delete_bestiary_entry { id } ->
    sprintf "forget bestiary entry %s" (Ids.Bestiary_id.to_string id)
  | Sync_members_from_roster -> "sync the fight with the roster"
;;

(** Applies a script and prints what each step did, which is the closest thing
    this repo has to a demo. *)
let transcript ?(world = World.initial) actions =
  List.fold actions ~init:world ~f:(fun world action ->
    printf "\n$ %s\n" (describe_action world action);
    let world, events = World.apply world action in
    World.invariant world;
    List.iter events ~f:(fun event -> printf "  ! %s\n" (Event.to_string_hum event));
    print_encounter world.encounter;
    world)
;;
