(** A headless front end, so the engine can be driven without a browser.

    Its real job is the Phase 4 verification step: export a save from the
    deployed React app, run [symbaroum read] over it, and check that the printed
    world matches what the UI shows and that every reported correction is
    explainable. A UI cannot be that check, because a UI is the thing under
    test. *)

open! Core
open! Symbaroum

let print_normalizations normalizations =
  match (normalizations : Normalization.t list) with
  | [] -> ()
  | normalizations ->
    printf "\n%d correction(s) applied on the way in:\n" (List.length normalizations);
    List.iter normalizations ~f:(fun n ->
      printf "  - %s\n" (Normalization.to_string_hum n))
;;

let print_errors errors =
  eprintf "This file could not be read (%d problem(s)):\n" (List.length errors);
  List.iter errors ~f:(fun e -> eprintf "  - %s\n" (Json_decoder.Error.to_string_hum e))
;;

let print_combatant ~current (c : Combatant.t) =
  let side =
    match c.allegiance with
    | Player_character _ -> "PC"
    | Non_player None -> "NPC"
    | Non_player (Some monster_type) -> Monster_type.to_string monster_type
  in
  let flags =
    List.filter_opt
      [ Option.some_if c.prone "prone"
      ; Option.some_if c.flanked "flanked"
      ; Option.some_if (Combatant.is_down c) "DOWN"
      ; Option.some_if (Armor.is_unparsed c.armor) "armour not understood"
      ; Option.some_if
          (Option.exists c.attack ~f:(fun a ->
             Attack_profile.Source.is_estimated a.source))
          "damage estimated"
      ]
  in
  printf
    "  %s %-18s %-12s T%2d/%-2d  def %2d  %s%s\n"
    (if current then ">" else " ")
    (Name.to_string c.name)
    side
    c.toughness.current
    c.toughness.max
    (Defense.to_int c.defense)
    c.armor.text
    (if List.is_empty flags then "" else "  [" ^ String.concat flags ~sep:", " ^ "]")
;;

let print_world (world : World.t) =
  printf "Roster (%d)\n" (Roster.length world.roster);
  List.iter (Roster.to_list world.roster) ~f:(fun (c : Character.t) ->
    printf
      "  %-18s %-12s T%-3d def %-3d %s\n"
      (Name.to_string c.name)
      c.role
      c.toughness.max
      (Defense.to_int c.defense)
      c.armor.text);
  printf "\nEncounter\n";
  (match Encounter.is_empty world.encounter with
   | true -> printf "  (no combatants)\n"
   | false ->
     printf
       "  round %d, turn %d of %d\n"
       (Round.to_int (Encounter.round world.encounter))
       (Option.value_exn (Encounter.turn_index world.encounter) + 1)
       (Encounter.length world.encounter);
     let current = Encounter.current_id world.encounter in
     List.iter (Encounter.members world.encounter) ~f:(fun c ->
       print_combatant
         ~current:
           (Option.value_map current ~default:false ~f:(Ids.Combatant_id.equal c.id))
         c));
  printf "\nBestiary (%d)\n" (Bestiary.length world.bestiary);
  List.iter (Bestiary.to_list world.bestiary) ~f:(fun (e : Bestiary.Entry.t) ->
    printf "  %s\n" (Monster_type.to_string e.monster_type));
  printf "\nArchived encounters (%d)\n" (Encounter_archive.length world.archive);
  List.iter
    (Encounter_archive.to_list world.archive)
    ~f:(fun (e : Encounter_archive.Entry.t) -> printf "  %s\n" e.label)
;;

let read_command =
  Command.basic
    ~summary:"read a save file and print the world it describes"
    ~readme:(fun () ->
      "Accepts version 1 (what the deployed React app writes) and version 2 (what this\n\
       port writes). Corrections applied on the way in are listed; a file that cannot be\n\
       read at all produces one line per problem, with a JSON path.")
    (let%map_open.Command path = anon ("FILE" %: Filename_unix.arg_type) in
     fun () ->
       match Codec.decode_string (In_channel.read_all path) with
       | Error errors ->
         print_errors errors;
         exit 1
       | Ok { world; normalizations } ->
         print_world world;
         print_normalizations normalizations)
;;

let convert_command =
  Command.basic
    ~summary:"read a save file and write it back out as version 2"
    (let%map_open.Command path = anon ("FILE" %: Filename_unix.arg_type) in
     fun () ->
       match Codec.decode_string (In_channel.read_all path) with
       | Error errors ->
         print_errors errors;
         exit 1
       | Ok { world; normalizations = _ } -> print_endline (Codec.encode_string world))
;;

let demo_command =
  Command.basic
    ~summary:"run a scripted fight and print it, with no file involved"
    ~readme:(fun () ->
      "The same script as the combat transcript test. Useful for seeing the engine work\n\
       without having a save to hand.")
    (Command.Param.return (fun () ->
       let at = Time_ns.of_int_ns_since_epoch 0 in
       let party =
         List.map Default_roster.ids ~f:(fun id ->
           id, Ids.Combatant_id.of_string ("cmb_" ^ Ids.Character_id.to_string id))
       in
       let draft =
         match Monster_presets.find (Monster_type.of_string "Robber") with
         | None -> Npc_draft.default
         | Some preset ->
           { (Npc_draft.of_preset preset) with count = Npc_count.of_int_exn 3 }
       in
       let world, events =
         World.apply_all
           World.initial
           [ Add_player_characters { characters = party }
           ; Add_npcs
               { draft
               ; ids =
                   List.map [ "r1"; "r2"; "r3" ] ~f:(fun s ->
                     Ids.Combatant_id.of_string ("cmb_" ^ s))
               ; bestiary_id = Ids.Bestiary_id.of_string "bst_robber"
               ; at
               }
           ; Sort_by_initiative
           ; Adjust
               { id = Ids.Combatant_id.of_string "cmb_r1"
               ; amount = Adjust_amount.of_int_exn 7
               ; mode = `Hurt
               }
           ; Next_turn
           ]
       in
       print_world world;
       if not (List.is_empty events)
       then (
         printf "\nEvents\n";
         List.iter events ~f:(fun e -> printf "  - %s\n" (Event.to_string_hum e)))))
;;

let () =
  Command_unix.run
    (Command.group
       ~summary:"Symbaroum combat tracker, without the browser"
       [ "read", read_command; "convert", convert_command; "demo", demo_command ])
;;
