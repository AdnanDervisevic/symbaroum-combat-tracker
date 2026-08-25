(** One test per bug the port fixes, with the old behaviour written down.

    This file is the README table. Every row names a real defect in the React
    app, shows what it does, and shows what the OCaml types do instead --
    including, for three of them, the fact that there was no fix to write because
    the shape of the type left nowhere for the bug to live.

    The pain-threshold row landed in Phase 1 and lives in
    [test/scalars/test_pain_threshold.ml]. The import rows land in Phase 4. *)

open! Core
open! Symbaroum
open Expect_test_helpers_core
open Test_helpers

let goblin_draft ?(count = 1) () =
  { Npc_draft.default with
    monster_type = Some (mt "Goblin")
  ; count = Npc_count.of_int_exn count
  }
;;

let add_goblins world ~count ~ids =
  fst
    (World.apply
       world
       (Add_npcs
          { draft = goblin_draft ~count ()
          ; ids = List.map ids ~f:cid
          ; bestiary_id = bid "bst_goblin"
          ; at
          }))
;;

let names world =
  List.map (Encounter.members world.World.encounter) ~f:(fun c -> Name.to_string c.name)
;;

(* BUG: [addNpc] (App.tsx:231) numbers the next goblin by counting the goblins
   *currently in the encounter*. Add three, remove Goblin 2, add one more, and
   React produces a second "Goblin 3". The count is a fact about the live roster;
   the name needs a fact about the encounter's history. *)
let%expect_test "test_npc_naming_survives_removal" =
  let world = add_goblins fixture_world ~count:3 ~ids:[ "c1"; "c2"; "c3" ] in
  print_s [%sexp (names world : string list)];
  [%expect {| ("Goblin 1" "Goblin 2" "Goblin 3") |}];
  let world = fst (World.apply world (Remove_member { id = cid "c2" })) in
  let world = add_goblins world ~count:1 ~ids:[ "c4" ] in
  (* React: (Goblin 1) (Goblin 3) (Goblin 3) *)
  print_s [%sexp (names world : string list)];
  [%expect {| ("Goblin 1" "Goblin 3" "Goblin 4") |}]
;;

(* BUG: [addNpc] (App.tsx:246) builds its combatant as a record literal and
   simply omits [attributes], so a preset's stat block is dropped on the way into
   the encounter -- and the stat block is exactly what the probability model
   reads. Here the record is total, so the compiler asked for a value. *)
let%expect_test "test_npc_preset_attributes_are_kept" =
  let draft = Npc_draft.of_preset (preset "Spring Elf") in
  let world =
    fst
      (World.apply
         fixture_world
         (Add_npcs { draft; ids = [ cid "c1" ]; bestiary_id = bid "bst_elf"; at }))
  in
  let member = List.hd_exn (Encounter.members world.encounter) in
  print_s
    [%message
      ""
        ~name:(Name.to_string member.name : string)
        ~attributes:
          (Attributes.to_known_alist member.attributes
           : (Attribute.t * Attribute_value.t) list)
        ~attack:(member.attack : Attack_profile.t option)];
  [%expect
    {|
    ((name "Spring Elf 1")
     (attributes (
       (Accurate   10)
       (Cunning    10)
       (Discreet   15)
       (Persuasive 9)
       (Quick      13)
       (Resolute   7)
       (Strong     5)
       (Vigilant   11)))
     (attack ((
       (accurate 10)
       (damage (
         (count    1)
         (sides    6)
         (modifier 0)))
       (source (Estimated_from_resistance Weak)))))) |}]
;;

(* BUG: [sortByInitiative] (App.tsx:340) writes
   [round: prev.members.length ? 1 : prev.round], so sorting mid-fight throws the
   round away. There is no corrected line here: [Round.t] lives in
   [Encounter.t], outside [Turn_order.t], and sorting is [Turn_order.sort_by],
   which has no round in scope to reset. *)
let%expect_test "test_sort_preserves_round" =
  let world =
    add_goblins fixture_world ~count:3 ~ids:[ "c1"; "c2"; "c3" ]
    |> Fn.flip World.apply_all [ Next_turn; Next_turn; Next_turn; Next_turn ]
    |> fst
  in
  printf "before sort: round %d\n" (Round.to_int (Encounter.round world.encounter));
  let world = fst (World.apply world Sort_by_initiative) in
  (* React: round 1 *)
  printf "after sort:  round %d\n" (Round.to_int (Encounter.round world.encounter));
  [%expect
    {|
    before sort: round 2
    after sort:  round 2 |}]
;;

(* BUG: [deleteCharacter] (App.tsx:112) filters the members and leaves
   [turnIndex] pointing wherever it was, so deleting a character while a later
   combatant is up leaves the cursor past the end -- [members[turnIndex]] is
   [undefined] and the encounter has nobody whose turn it is. The cursor here is
   a position inside a nonempty zipper, so there is no index to leave dangling.
   Note that the *same* combatant keeps its turn, which is the behaviour the
   React code was reaching for. *)
let%expect_test "test_delete_character_repairs_cursor" =
  let ids = List.map fixture_ids ~f:(fun id -> id, cid (Ids.Character_id.to_string id)) in
  let world =
    fst (World.apply fixture_world (Add_player_characters { characters = ids }))
  in
  let world = fst (World.apply_all world [ Next_turn; Next_turn; Next_turn ]) in
  printf "before: ";
  print_s
    [%sexp
      (Option.map (Encounter.current world.encounter) ~f:Combatant.name : Name.t option)];
  let world = fst (World.apply world (Delete_character { id = chid "pc_bravo" })) in
  printf "after:  ";
  print_s
    [%sexp
      (Option.map (Encounter.current world.encounter) ~f:Combatant.name : Name.t option)];
  World.invariant world;
  print_encounter world.encounter;
  [%expect
    {|
    before: (Delta)
    after:  (Delta)
      round 1, turn 3/3
        Alpha          PC       T10/10
        Charlie        PC       T10/10
      > Delta          PC       T12/12 |}]
;;

(* BUG: [redo] (usePersistentHistory.ts:112) appends to [past] with no
   [.slice(-MAX_HISTORY)], which the three other writers all have. So undo/redo
   ping-pong grows the past without bound -- and it is serialised into
   localStorage, so the saved blob grows with it. Here the trim is inside the one
   function both [push] and [redo] go through. *)
let%expect_test "test_redo_respects_capacity" =
  let equal = Int.equal in
  let history =
    List.fold (List.range 1 12) ~init:(Undo_history.create ~capacity:5 0) ~f:(fun h n ->
      Undo_history.push h n ~equal ~key:None)
  in
  printf "after 11 pushes, capacity 5: depth %d\n" (Undo_history.depth history);
  let history =
    List.fold (List.range 0 40) ~init:history ~f:(fun h i ->
      let stepped = if i % 2 = 0 then Undo_history.undo h else Undo_history.redo h in
      Option.value stepped ~default:h)
  in
  (* React: 5 + 20 = 25 and climbing *)
  printf "after 40 undo/redo steps:    depth %d\n" (Undo_history.depth history);
  [%expect
    {|
    after 11 pushes, capacity 5: depth 5
    after 40 undo/redo steps:    depth 5 |}]
;;

(* BUG: the deduplication at usePersistentHistory.ts:83 is
   [newPresent === prev.present], a JavaScript *reference* comparison against a
   freshly built object literal. It never fires. Every keystroke in a note field
   burns an undo slot, so one sentence evaporates all fifty. [push] takes a
   structural [equal], and a [key] so a run of edits to one field is one entry --
   and editing a *different* field starts a new one. *)
let%expect_test "test_typing_a_note_costs_one_undo" =
  let world = add_goblins fixture_world ~count:1 ~ids:[ "c1" ] in
  let type_into_note history text =
    let action =
      Action.Update_member { id = cid "c1"; patch = Member_patch.Set_note text }
    in
    let next, _ = World.apply (Undo_history.present history) action in
    Undo_history.push history next ~equal:World.equal ~key:(Action.coalesce_key action)
  in
  let history =
    String.foldi "a wounded champion" ~init:(Undo_history.create world) ~f:(fun i h _ ->
      type_into_note h (String.prefix "a wounded champion" (i + 1)))
  in
  (* React: 18 *)
  printf "18 keystrokes in one note: depth %d\n" (Undo_history.depth history);
  let history =
    Undo_history.push
      history
      (fst
         (World.apply
            (Undo_history.present history)
            (Update_member { id = cid "c1"; patch = Set_prone true })))
      ~equal:World.equal
      ~key:(Action.coalesce_key (Update_member { id = cid "c1"; patch = Set_prone true }))
  in
  printf "then one edit to a different field: depth %d\n" (Undo_history.depth history);
  let undone = Option.value_exn (Undo_history.undo history) in
  printf
    "one undo restores the whole sentence: note = %s\n"
    (Option.value_exn (Encounter.find (Undo_history.present undone).encounter (cid "c1")))
      .note;
  [%expect
    {|
    18 keystrokes in one note: depth 1
    then one edit to a different field: depth 2
    one undo restores the whole sentence: note = a wounded champion |}]
;;

(* BUG: the port itself, not React. The [defense] field was read as a modifier
   everywhere, including on player characters, because the four shipped
   characters store [0] and zero is not a legal roll-under target -- so a
   modifier looked like the only reading under which they were legal at all.

   That inference was backwards. A [0] on a character sheet means nobody has
   filled it in. Reading it as a modifier turned an unfilled sheet into a
   confident target of exactly 10 and threw away the fact that anything was
   missing. It surfaced when the GM wrote real numbers onto two of those sheets
   and the build stopped: [defense: 13] as a modifier is a target of -3.

   Both readings survive, one per side, and a v1 save exercises both at once. *)
let%expect_test "test_v1_defense_reads_by_side" =
  let v1 =
    {|{ "version": 1
      , "characters":
          [ { "id": "pc_1", "name": "Sheet", "toughness": 10, "defense": 3
            , "armor": "", "painThreshold": null, "note": "" } ]
      , "encounter":
          { "members":
              [ { "id": "c1", "source": "pc", "refId": "pc_1", "name": "Sheet"
                , "toughness": 10, "defense": 3, "armor": "", "painThreshold": null
                , "prone": false, "flanked": false }
              , { "id": "c2", "source": "npc", "monsterType": "Goblin"
                , "name": "Goblin 1", "toughness": 10, "defense": 3, "armor": ""
                , "painThreshold": null, "prone": false, "flanked": false }
              ]
          , "turnIndex": 0, "round": 1 }
      }|}
  in
  let { Codec.world; normalizations } =
    Or_error.ok_exn
      (Result.map_error (Codec.decode_string v1) ~f:(fun errors ->
         Error.create_s [%sexp (errors : Json_decoder.Error.t list)]))
  in
  (* The same stored 3, on two sides of the same fight. React: both 7. *)
  List.iter (Encounter.members world.encounter) ~f:(fun (c : Combatant.t) ->
    printf
      "  %-10s %-4s stored 3 -> rolls under %d\n"
      (Name.to_string c.name)
      (match c.allegiance with
       | Player_character _ -> "PC"
       | Non_player _ -> "NPC")
      (Defense.to_int c.defense));
  List.iter normalizations ~f:(fun n -> printf "  ~ %s\n" (Normalization.to_string_hum n));
  [%expect
    {|
    Sheet      PC   stored 3 -> rolls under 3
    Goblin 1   NPC  stored 3 -> rolls under 7
    ~ Rebuilt the auto-naming counter from Goblin 1. |}]
;;

(* And the unfilled sheet the old reading hid: it is repaired to the lowest legal
   defence and *reported*, rather than silently becoming an average one. *)
let%expect_test "test_v1_blank_character_sheet_is_reported" =
  let v1 =
    {|{ "version": 1
      , "characters":
          [ { "id": "pc_1", "name": "Unfilled", "toughness": 10, "defense": 0
            , "armor": "", "painThreshold": null, "note": "" } ]
      , "encounter": { "members": [], "turnIndex": 0, "round": 1 }
      }|}
  in
  let { Codec.world; normalizations } =
    Or_error.ok_exn
      (Result.map_error (Codec.decode_string v1) ~f:(fun errors ->
         Error.create_s [%sexp (errors : Json_decoder.Error.t list)]))
  in
  List.iter (Roster.to_list world.roster) ~f:(fun (c : Character.t) ->
    (* React: a target of 10, stated with total confidence. *)
    printf "  %s rolls under %d\n" (Name.to_string c.name) (Defense.to_int c.defense));
  List.iter normalizations ~f:(fun n -> printf "  ~ %s\n" (Normalization.to_string_hum n));
  [%expect
    {|
    Unfilled rolls under 1
    ~ characters[0].defense (as a roll-under target) 0 is out of range; clamped to 1. |}]
;;
