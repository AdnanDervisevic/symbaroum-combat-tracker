open! Core

type t =
  { roster : Roster.t
  ; encounter : Encounter.t
  ; bestiary : Bestiary.t
  ; archive : Encounter_archive.t
  }
[@@deriving compare, equal, sexp_of]

let empty =
  { roster = Roster.empty
  ; encounter = Encounter.empty
  ; bestiary = Bestiary.empty
  ; archive = Encounter_archive.empty
  }
;;

let initial = { empty with roster = Roster.default }

let invariant t =
  Invariant.invariant [%here] t [%sexp_of: t] (fun () ->
    Encounter.invariant t.encounter;
    (* The cross-store one, and the reason [Delete_character] has to touch the
       encounter: a combatant may not point at a roster entry that is gone. *)
    List.iter (Encounter.members t.encounter) ~f:(fun (member : Combatant.t) ->
      match Combatant.Allegiance.character_id member.allegiance with
      | None -> ()
      | Some id ->
        [%test_result: bool]
          ~message:"a combatant points at a character that is not in the roster"
          (Roster.mem t.roster id)
          ~expect:true))
;;

let sync_members t =
  { t with
    encounter =
      Encounter.map_members t.encounter ~f:(fun member ->
        match Combatant.Allegiance.character_id member.allegiance with
        | None -> member
        | Some id ->
          (match Roster.find t.roster id with
           | None -> member
           | Some character -> Combatant.sync_from_character member character))
  }
;;

let rejected t reason = t, [ Event.Rejected { reason } ]

let apply t (command : Action.t) =
  match command with
  | Add_character { id } ->
    if Roster.mem t.roster id
    then rejected t "That character id is already in the roster"
    else { t with roster = Roster.add t.roster (Character.create_new ~id) }, []
  | Update_character { id; patch } ->
    if not (Roster.mem t.roster id)
    then rejected t "No such character"
    else (
      (* The React app does this in a [useEffect] that watches [characters] and
         writes the encounter afterwards, so for one render the combatant shows
         the old name. Here it is the same transition. *)
      let t =
        { t with
          roster = Roster.update t.roster id ~f:(fun c -> Character_patch.apply c patch)
        }
      in
      sync_members t, [])
  | Delete_character { id } ->
    if not (Roster.mem t.roster id)
    then rejected t "No such character"
    else
      ( { t with
          roster = Roster.remove t.roster id
        ; encounter =
            (* [deleteCharacter] ({{:src/App.tsx} [App.tsx:112]}) filters the
               members and leaves [turnIndex] pointing wherever it was, which is
               how an out-of-range cursor gets into a save. Here there is no
               cursor to leave behind. *)
            Encounter.remove_if t.encounter ~f:(fun member ->
              match Combatant.Allegiance.character_id member.allegiance with
              | None -> false
              | Some other -> Ids.Character_id.equal id other)
        }
      , [] )
  | Add_player_characters { characters } ->
    let already =
      Ids.Character_id.Set.of_list
        (List.filter_map (Encounter.members t.encounter) ~f:(fun member ->
           Combatant.Allegiance.character_id member.allegiance))
    in
    let additions =
      List.filter_map characters ~f:(fun (character_id, combatant_id) ->
        if Set.mem already character_id
        then None
        else
          Option.map (Roster.find t.roster character_id) ~f:(fun character ->
            Combatant.of_character character ~id:combatant_id))
    in
    if List.is_empty additions
    then t, []
    else
      ( { t with
          encounter =
            Encounter.add
              t.encounter
              ~name_counter:(Encounter.name_counter t.encounter)
              additions
        }
      , [] )
  | Add_npcs { draft; ids; bestiary_id; at } ->
    let wanted = Npc_count.to_int draft.count in
    if List.length ids <> wanted
    then rejected t "The number of ids does not match the number of NPCs asked for"
    else (
      let name_counter, names =
        Npc_draft.names draft ~name_counter:(Encounter.name_counter t.encounter)
      in
      let combatants = Npc_draft.to_combatants draft ~ids ~names in
      let bestiary =
        match Npc_draft.to_bestiary_entry draft ~id:bestiary_id ~at with
        | None -> t.bestiary
        | Some entry -> Bestiary.upsert t.bestiary entry
      in
      (* One transition, not the two [setState] calls the React version makes.
         There is no window in which the encounter and the bestiary disagree, and
         undo covers both. *)
      ( { t with encounter = Encounter.add t.encounter ~name_counter combatants; bestiary }
      , [] ))
  | Update_member { id; patch } ->
    if not (Encounter.mem t.encounter id)
    then rejected t "No such combatant"
    else
      ( { t with
          encounter =
            Encounter.update t.encounter id ~f:(fun m -> Member_patch.apply m patch)
        }
      , [] )
  | Adjust { id; amount; mode } ->
    (match Encounter.find t.encounter id with
     | None -> rejected t "No such combatant"
     | Some member ->
       let amount = Adjust_amount.to_int amount in
       let was_down = Combatant.is_down member in
       let updated, events =
         match mode with
         | `Hurt ->
           let updated, `Dealt dealt, `Newly_prone newly_prone =
             Combatant.hurt member amount
           in
           ( updated
           , List.concat
               [ (if newly_prone
                  then
                    [ Event.Pain_threshold_exceeded { name = member.name; damage = dealt }
                    ]
                  else [])
               ; (if Combatant.is_down updated && not was_down
                  then [ Event.Combatant_downed { name = member.name } ]
                  else [])
               ] )
         | `Heal ->
           let updated, `Restored _ = Combatant.heal member amount in
           updated, []
       in
       ( { t with encounter = Encounter.update t.encounter id ~f:(fun _ -> updated) }
       , events ))
  | Remove_member { id } ->
    if not (Encounter.mem t.encounter id)
    then rejected t "No such combatant"
    else { t with encounter = Encounter.remove t.encounter id }, []
  | Move_member { id; direction } ->
    { t with encounter = Encounter.move t.encounter id direction }, []
  | Sort_by_initiative ->
    (* The round is not reachable from here. See {!Symbaroum.Encounter}. *)
    { t with encounter = Encounter.sort_by_initiative t.encounter }, []
  | Next_turn ->
    let finished = Encounter.round t.encounter in
    let encounter, wrapped = Encounter.next_turn t.encounter in
    let events =
      match wrapped with
      | `Same_round -> []
      | `Wrapped ->
        let `Standing standing, `Down down = Encounter.tally encounter in
        [ Event.Round_completed { round = finished; standing; down } ]
    in
    { t with encounter }, events
  | Prev_turn -> { t with encounter = fst (Encounter.prev_turn t.encounter) }, []
  | Clear_encounter { snapshot_id; at } ->
    if Encounter.is_empty t.encounter
    then { t with encounter = Encounter.empty }, []
    else (
      let label = Encounter_archive.Entry.label_for t.encounter in
      let entry =
        { Encounter_archive.Entry.id = snapshot_id; at; label; encounter = t.encounter }
      in
      ( { t with
          encounter = Encounter.empty
        ; archive = Encounter_archive.add t.archive entry
        }
      , [ Event.Encounter_archived { label } ] ))
  | Restore_encounter { id } ->
    (match Encounter_archive.find t.archive id with
     | None -> rejected t "That saved encounter is gone"
     | Some entry ->
       (* Restoring can bring back a combatant whose roster entry was deleted in
          the meantime, so the world invariant has to be re-established here
          rather than assumed. *)
       let encounter =
         Encounter.remove_if entry.encounter ~f:(fun member ->
           match Combatant.Allegiance.character_id member.allegiance with
           | None -> false
           | Some character_id -> not (Roster.mem t.roster character_id))
       in
       { t with encounter }, [ Event.Encounter_restored { label = entry.label } ])
  | Delete_snapshot { id } ->
    { t with archive = Encounter_archive.remove t.archive id }, []
  | Delete_bestiary_entry { id } ->
    { t with bestiary = Bestiary.remove t.bestiary id }, []
  | Sync_members_from_roster -> sync_members t, []
;;

let apply_all t commands =
  let t, events =
    List.fold commands ~init:(t, []) ~f:(fun (t, events) command ->
      let t, new_events = apply t command in
      t, new_events :: events)
  in
  t, List.concat (List.rev events)
;;
