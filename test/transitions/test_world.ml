(** The reducer, and the combat transcript that demonstrates it.

    {!Symbaroum.World.apply} is pure and total: no clock, no id generator, no
    toast fired from inside a state updater. Everything it needs is an argument
    and everything it wants to say is a return value, which is what makes the
    first test in this file possible -- a whole fight, replayed from a list of
    actions, printed. *)

open! Core
open! Symbaroum
open Expect_test_helpers_core
open Test_helpers

let combatant_id character_id = cid ("cmb_" ^ Ids.Character_id.to_string character_id)

let party =
  List.map [ "pc_default_cassimei"; "pc_default_vigoi"; "pc_default_ymma" ] ~f:(fun id ->
    let id = chid id in
    id, combatant_id id)
;;

let robbers = [ cid "cmb_r1"; cid "cmb_r2" ]

let robber_draft =
  { (Npc_draft.of_preset (preset "Robber")) with count = Npc_count.of_int_exn 2 }
;;

(* Three of the shipped player characters against two robbers off the preset
   list. The Robber has 11 toughness and a pain threshold of 6, so the seven
   points below are the blow that puts one on the ground -- and the event that
   says so comes back from [apply] rather than being fired from inside it. *)
let%expect_test "a fight, from the top" =
  let world =
    transcript
      [ Action.Add_player_characters { characters = party }
      ; Add_npcs
          { draft = robber_draft; ids = robbers; bestiary_id = bid "bst_robber"; at }
      ; Sort_by_initiative
      ; Adjust { id = cid "cmb_r1"; amount = amount 7; mode = `Hurt }
      ; Next_turn
      ; Next_turn
      ; Adjust
          { id = combatant_id (chid "pc_default_vigoi"); amount = amount 4; mode = `Hurt }
      ; Next_turn
      ; Next_turn
      ; Next_turn
      ; Adjust { id = cid "cmb_r1"; amount = amount 9; mode = `Hurt }
      ; Adjust
          { id = combatant_id (chid "pc_default_vigoi"); amount = amount 3; mode = `Heal }
      ; Remove_member { id = cid "cmb_r1" }
      ; Clear_encounter { snapshot_id = sid "snap_ambush"; at }
      ]
  in
  [%expect
    {|
    $ send Cassimei, Vigoi, Ymma into the fight
      round 1, turn 1/3
      > Cassimei       PC       T10/10
        Vigoi          PC       T10/10
        Ymma           PC       T10/10

    $ add 2 Robber
      round 1, turn 1/5
      > Cassimei       PC       T10/10
        Vigoi          PC       T10/10
        Ymma           PC       T10/10
        Robber 1       Robber   T11/11
        Robber 2       Robber   T11/11

    $ sort by initiative
      round 1, turn 1/5
      > Robber 1       Robber   T11/11
        Robber 2       Robber   T11/11
        Cassimei       PC       T10/10
        Vigoi          PC       T10/10
        Ymma           PC       T10/10

    $ hit Robber 1 for 7
      ! Robber 1 takes 7 damage and exceeds Pain Threshold
      round 1, turn 1/5
      > Robber 1       Robber   T4/11 [prone]
        Robber 2       Robber   T11/11
        Cassimei       PC       T10/10
        Vigoi          PC       T10/10
        Ymma           PC       T10/10

    $ next turn
      round 1, turn 2/5
        Robber 1       Robber   T4/11 [prone]
      > Robber 2       Robber   T11/11
        Cassimei       PC       T10/10
        Vigoi          PC       T10/10
        Ymma           PC       T10/10

    $ next turn
      round 1, turn 3/5
        Robber 1       Robber   T4/11 [prone]
        Robber 2       Robber   T11/11
      > Cassimei       PC       T10/10
        Vigoi          PC       T10/10
        Ymma           PC       T10/10

    $ hit Vigoi for 4
      round 1, turn 3/5
        Robber 1       Robber   T4/11 [prone]
        Robber 2       Robber   T11/11
      > Cassimei       PC       T10/10
        Vigoi          PC       T6/10
        Ymma           PC       T10/10

    $ next turn
      round 1, turn 4/5
        Robber 1       Robber   T4/11 [prone]
        Robber 2       Robber   T11/11
        Cassimei       PC       T10/10
      > Vigoi          PC       T6/10
        Ymma           PC       T10/10

    $ next turn
      round 1, turn 5/5
        Robber 1       Robber   T4/11 [prone]
        Robber 2       Robber   T11/11
        Cassimei       PC       T10/10
        Vigoi          PC       T6/10
      > Ymma           PC       T10/10

    $ next turn
      ! Round 1 complete - All 5 combatants standing
      round 2, turn 1/5
      > Robber 1       Robber   T4/11 [prone]
        Robber 2       Robber   T11/11
        Cassimei       PC       T10/10
        Vigoi          PC       T6/10
        Ymma           PC       T10/10

    $ hit Robber 1 for 9
      ! Robber 1 is down
      round 2, turn 1/5
      > Robber 1       Robber   T0/11 [prone DOWN]
        Robber 2       Robber   T11/11
        Cassimei       PC       T10/10
        Vigoi          PC       T6/10
        Ymma           PC       T10/10

    $ heal Vigoi for 3
      round 2, turn 1/5
      > Robber 1       Robber   T0/11 [prone DOWN]
        Robber 2       Robber   T11/11
        Cassimei       PC       T10/10
        Vigoi          PC       T9/10
        Ymma           PC       T10/10

    $ remove Robber 1 from the fight
      round 2, turn 1/4
      > Robber 2       Robber   T11/11
        Cassimei       PC       T10/10
        Vigoi          PC       T9/10
        Ymma           PC       T10/10

    $ clear the encounter
      ! Encounter saved - Round 2 - 3 PCs, 1 NPC
      (no combatants) |}];
  (* The two stores the fight also wrote, which the React app updates in separate
     [setState] calls -- so there is a window where they disagree, and undo
     covers one of them. *)
  print_s
    [%message
      ""
        ~bestiary:
          (List.map (Bestiary.to_list world.bestiary) ~f:(fun (e : Bestiary.Entry.t) ->
             Monster_type.to_string e.monster_type)
           : string list)
        ~archive:
          (List.map
             (Encounter_archive.to_list world.archive)
             ~f:Encounter_archive.Entry.label
           : string list)];
  [%expect
    {|
    ((bestiary (Robber))
     (archive  ("Round 2 - 3 PCs, 1 NPC"))) |}]
;;

let%expect_test "and it can be brought back" =
  let world =
    fst
      (World.apply_all
         World.initial
         [ Add_player_characters { characters = party }
         ; Clear_encounter { snapshot_id = sid "snap_ambush"; at }
         ])
  in
  let world = transcript ~world [ Restore_encounter { id = sid "snap_ambush" } ] in
  World.invariant world;
  [%expect
    {|
    $ restore the encounter saved as snap_ambush
      ! Encounter restored - Round 1 - 3 PCs, 0 NPCs
      round 1, turn 1/3
      > Cassimei       PC       T10/10
        Vigoi          PC       T10/10
        Ymma           PC       T10/10 |}]
;;

(* Restoring can bring back a combatant whose roster entry was deleted in the
   meantime, so the cross-store invariant is re-established on the way out rather
   than assumed. Without this the world invariant fails, which is the point of
   having one. *)
let%expect_test "a restored fight drops combatants whose character is gone" =
  let world =
    fst
      (World.apply_all
         World.initial
         [ Add_player_characters { characters = party }
         ; Clear_encounter { snapshot_id = sid "snap_ambush"; at }
         ; Delete_character { id = chid "pc_default_vigoi" }
         ; Restore_encounter { id = sid "snap_ambush" }
         ])
  in
  World.invariant world;
  print_encounter world.encounter;
  [%expect
    {|
    round 1, turn 1/2
    > Cassimei       PC       T10/10
      Ymma           PC       T10/10 |}]
;;

(* A roster edit and the combatant it belongs to are one transition here. The
   React app does the roster write in [updateCharacter] and the encounter write
   in a [useEffect] that watches it, so for one render the combatant shows the
   old name. *)
let%expect_test "editing a character updates the combatant in the same step" =
  let world =
    fst (World.apply World.initial (Add_player_characters { characters = party }))
  in
  let world =
    fst
      (World.apply
         world
         (Update_character
            { id = chid "pc_default_ymma"; patch = Set_name (name "Ymma Ironjaw") }))
  in
  print_encounter world.encounter;
  (* Initiative and toughness are in-fight facts and deliberately do not follow
     the roster, exactly as [syncMemberFromPc] has it. *)
  let world =
    fst
      (World.apply
         world
         (Update_character
            { id = chid "pc_default_ymma"; patch = Set_initiative (initiative 42) }))
  in
  print_s
    [%message
      ""
        ~roster:
          (Initiative.to_int
             (Option.value_exn (Roster.find world.roster (chid "pc_default_ymma")))
               .initiative
           : int)
        ~combatant:
          (Initiative.to_int
             (Option.value_exn
                (Encounter.find world.encounter (combatant_id (chid "pc_default_ymma"))))
               .initiative
           : int)];
  [%expect
    {|
      round 1, turn 1/3
      > Cassimei       PC       T10/10
        Vigoi          PC       T10/10
        Ymma Ironjaw   PC       T10/10
    ((roster    42)
     (combatant 0)) |}]
;;

let%expect_test "a character already in the fight is not added twice" =
  let world =
    fst
      (World.apply_all
         World.initial
         [ Add_player_characters { characters = party }
         ; Add_player_characters { characters = party }
         ])
  in
  printf "%d combatants\n" (Encounter.length world.encounter);
  [%expect {| 3 combatants |}]
;;

(* Every rejection in one place, because they are the whole of the error
   surface: [apply] is total, so "no such combatant" is a value, not an
   exception and not a silent no-op. *)
let%expect_test "what the reducer refuses, and what it says" =
  let world =
    fst (World.apply World.initial (Add_player_characters { characters = party }))
  in
  List.iter
    [ Action.Add_character { id = chid "pc_default_ymma" }
    ; Update_character { id = chid "nobody"; patch = Set_note "hello" }
    ; Delete_character { id = chid "nobody" }
    ; Update_member { id = cid "nobody"; patch = Set_prone true }
    ; Adjust { id = cid "nobody"; amount = amount 3; mode = `Hurt }
    ; Remove_member { id = cid "nobody" }
    ; Restore_encounter { id = sid "never_saved" }
    ; Add_npcs { draft = robber_draft; ids = [ cid "cmb_r1" ]; bestiary_id = bid "b"; at }
    ; Add_npcs
        { draft = robber_draft
        ; ids = [ cid "cmb_r1"; cid "cmb_r1" ]
        ; bestiary_id = bid "b"
        ; at
        }
    ]
    ~f:(fun action ->
      let after, events = World.apply world action in
      [%test_result: bool]
        ~message:"a rejected action changed the world"
        (World.equal after world)
        ~expect:true;
      List.iter events ~f:(fun event -> printf "%s\n" (Event.to_string_hum event)));
  [%expect
    {|
    That character id is already in the roster
    No such character
    No such character
    No such combatant
    No such combatant
    No such combatant
    That saved encounter is gone
    The number of ids does not match the number of NPCs asked for
    Two of the new NPCs were given the same id |}]
;;

(* Actions that are not part of the fight, and so are not on the undo stack. The
   list is short and worth reading, because the alternative -- deciding this at
   each call site in the UI -- is how the React app ends up with an undo that
   sometimes restores a deleted bestiary entry and sometimes does not. *)
let%expect_test "what is undoable" =
  List.iter
    [ Action.Next_turn
    ; Sort_by_initiative
    ; Adjust { id = cid "c1"; amount = amount 1; mode = `Hurt }
    ; Update_member { id = cid "c1"; patch = Set_note "a wounded champion" }
    ; Update_member { id = cid "c1"; patch = Set_prone true }
    ; Update_member { id = cid "c2"; patch = Set_note "the other one" }
    ; Delete_snapshot { id = sid "s" }
    ; Delete_bestiary_entry { id = bid "b" }
    ; Sync_members_from_roster
    ]
    ~f:(fun action ->
      printf
        "  %-32s undoable %-5b  coalesces as %s\n"
        (describe_action World.initial action)
        (Action.is_undoable action)
        (Option.value (Action.coalesce_key action) ~default:"-"));
  [%expect
    {|
    next turn                        undoable true   coalesces as -
    sort by initiative               undoable true   coalesces as -
    hit c1 for 1                     undoable true   coalesces as -
    set note on c1                   undoable true   coalesces as member:c1:note
    set prone on c1                  undoable true   coalesces as member:c1:prone
    set note on c2                   undoable true   coalesces as member:c2:note
    delete snapshot s                undoable false  coalesces as -
    forget bestiary entry b          undoable false  coalesces as -
    sync the fight with the roster   undoable false  coalesces as - |}]
;;
