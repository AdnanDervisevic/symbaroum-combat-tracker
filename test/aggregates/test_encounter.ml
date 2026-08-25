(** The fight.

    Two of this module's claims are made by its {i shape} and are tested
    elsewhere, in [test_bug_ledger.ml]: sorting cannot reset the round, and a
    deletion cannot leave the cursor dangling. What is tested here is the part
    that is ordinary code and can therefore be ordinarily wrong -- {!create},
    which is the single place a turn index or a round number is repaired, and the
    cursor arithmetic around adding and removing combatants. *)

open! Core
open! Symbaroum
open Expect_test_helpers_core
open Test_helpers

let goblin ?(toughness = tough 10) ~id ~name:n ~initiative:init () =
  combatant
    ~allegiance:(Combatant.Allegiance.Non_player (Some (mt "Goblin")))
    ~toughness
    ~id
    ~name:n
    ~initiative:init
    ()
;;

let three_goblins =
  [ goblin ~id:"c1" ~name:"Goblin 1" ~initiative:5 ()
  ; goblin ~id:"c2" ~name:"Goblin 2" ~initiative:12 ()
  ; goblin ~id:"c3" ~name:"Goblin 3" ~initiative:9 ()
  ]
;;

let create ?(turn_index = 0) ?(round = 1) ?name_counter members =
  let encounter, normalizations =
    Encounter.create ~members ~turn_index ~round ~name_counter
  in
  Encounter.invariant encounter;
  print_encounter encounter;
  if not (List.is_empty normalizations)
  then
    List.iter normalizations ~f:(fun n ->
      printf "  ~ %s\n" (Normalization.to_string_hum n));
  encounter
;;

let%expect_test "an empty encounter has no turn and no round to speak of" =
  let e = Encounter.empty in
  print_s
    [%message
      ""
        ~is_empty:(Encounter.is_empty e : bool)
        ~turn_index:(Encounter.turn_index e : int option)
        ~current:(Encounter.current_id e : Ids.Combatant_id.t option)
        ~round:(Round.to_int (Encounter.round e) : int)];
  [%expect
    {|
    ((is_empty true)
     (turn_index ())
     (current    ())
     (round 1)) |}]
;;

(* [{members: [], turnIndex: 5, round: 0}] typechecks in the React app and is
   produced by four separate paths. Here it is repaired in one place and each
   repair is handed back. *)
let%expect_test "create is the one place a turn index or a round is repaired" =
  let (_ : Encounter.t) = create three_goblins ~turn_index:9 ~round:0 in
  [%expect
    {|
    round 1, turn 3/3
      Goblin 1       Goblin   T10/10
      Goblin 2       Goblin   T10/10
    > Goblin 3       Goblin   T10/10
    ~ Rebuilt the auto-naming counter from Goblin 3.
    ~ There is no turn 10; moved to turn 3.
    ~ Round 0 is not a round; set to 1. |}];
  let (_ : Encounter.t) = create three_goblins ~turn_index:(-2) ~round:7 in
  [%expect
    {|
    round 7, turn 1/3
    > Goblin 1       Goblin   T10/10
      Goblin 2       Goblin   T10/10
      Goblin 3       Goblin   T10/10
    ~ Rebuilt the auto-naming counter from Goblin 3.
    ~ There is no turn -1; moved to turn 1. |}];
  (* An empty member list has nowhere to put a turn or a round, so both are
     dropped -- and both are reported, because "your save said round 4 and this
     one says round 1" is exactly the kind of silent loss the type is for. *)
  let (_ : Encounter.t) = create [] ~turn_index:5 ~round:0 in
  [%expect
    {|
    (no combatants)
    ~ There is no turn 6; moved to turn 1.
    ~ Round 0 is not a round; set to 1. |}]
;;

(* Losing a combatant out of a saved fight is worse than renaming one, so the
   later duplicate is given a derived id rather than dropped. *)
let%expect_test "a duplicate id is renamed, not discarded" =
  let (_ : Encounter.t) =
    create
      [ goblin ~id:"c1" ~name:"Goblin 1" ~initiative:5 ()
      ; goblin ~id:"c1" ~name:"Goblin 2" ~initiative:6 ()
      ; goblin ~id:"c1" ~name:"Goblin 3" ~initiative:7 ()
      ]
  in
  [%expect
    {|
    round 1, turn 1/3
    > Goblin 1       Goblin   T10/10
      Goblin 2       Goblin   T10/10
      Goblin 3       Goblin   T10/10
    ~ Two combatants share the id c1; the later one became c1-2.
    ~ Two combatants share the id c1; the later one became c1-3.
    ~ Rebuilt the auto-naming counter from Goblin 3. |}]
;;

(* Saves written by the React app have no counter, so one is recovered from the
   names. The mark has to clear "Goblin 7" even though only two goblins are
   present, or the next one added is a second Goblin 7. *)
let%expect_test "a missing name counter is rebuilt from the names present" =
  let e =
    create
      [ goblin ~id:"c1" ~name:"Goblin 7" ~initiative:5 ()
      ; goblin ~id:"c2" ~name:"Brakk" ~initiative:6 ()
      ]
  in
  print_s
    [%sexp
      (Name_counter.to_alist (Encounter.name_counter e) : (Monster_type.t * int) list)];
  [%expect
    {|
      round 1, turn 1/2
      > Goblin 7       Goblin   T10/10
        Brakk          Goblin   T10/10
      ~ Rebuilt the auto-naming counter from Goblin 7.
    ((Goblin 7)) |}]
;;

let%expect_test "adding appends, and an id already present is skipped" =
  let e = create three_goblins in
  [%expect
    {|
    round 1, turn 1/3
    > Goblin 1       Goblin   T10/10
      Goblin 2       Goblin   T10/10
      Goblin 3       Goblin   T10/10
    ~ Rebuilt the auto-naming counter from Goblin 3. |}];
  let e =
    Encounter.add
      e
      ~name_counter:(Encounter.name_counter e)
      [ goblin ~id:"c2" ~name:"An Impostor" ~initiative:99 ()
      ; goblin ~id:"c4" ~name:"Goblin 4" ~initiative:1 ()
      ]
  in
  Encounter.invariant e;
  print_encounter e;
  [%expect
    {|
    round 1, turn 1/4
    > Goblin 1       Goblin   T10/10
      Goblin 2       Goblin   T10/10
      Goblin 3       Goblin   T10/10
      Goblin 4       Goblin   T10/10 |}]
;;

(* A port bug, not a React one, and the first thing the Phase 3 property tests
   found. [add] filtered the batch against the members already in the fight but
   not against itself, so a batch carrying the same id twice raised out of
   [Map.of_alist_exn] on an empty encounter -- and on a non-empty one did
   something quieter and worse, leaving an id in the turn order that the member
   map did not have. *)
let%expect_test "an id repeated inside one batch is skipped like any other" =
  let batch =
    [ goblin ~id:"c1" ~name:"Goblin 1" ~initiative:5 ()
    ; goblin ~id:"c1" ~name:"Goblin 2" ~initiative:6 ()
    ; goblin ~id:"c2" ~name:"Goblin 3" ~initiative:7 ()
    ]
  in
  let e = Encounter.add Encounter.empty ~name_counter:Name_counter.empty batch in
  Encounter.invariant e;
  print_encounter e;
  let e = Encounter.add e ~name_counter:Name_counter.empty batch in
  Encounter.invariant e;
  print_encounter e;
  [%expect
    {|
    round 1, turn 1/2
    > Goblin 1       Goblin   T10/10
      Goblin 3       Goblin   T10/10
    round 1, turn 1/2
    > Goblin 1       Goblin   T10/10
      Goblin 3       Goblin   T10/10 |}]
;;

let%expect_test "removing the last combatant empties the encounter and resets the round" =
  let e = create three_goblins in
  [%expect
    {|
    round 1, turn 1/3
    > Goblin 1       Goblin   T10/10
      Goblin 2       Goblin   T10/10
      Goblin 3       Goblin   T10/10
    ~ Rebuilt the auto-naming counter from Goblin 3. |}];
  let e, (_ : [ `Wrapped | `Same_round ]) = Encounter.next_turn e in
  let e = List.fold [ "c1"; "c2" ] ~init:e ~f:(fun e id -> Encounter.remove e (cid id)) in
  print_encounter e;
  printf "  round %d\n" (Round.to_int (Encounter.round e));
  let e = Encounter.remove e (cid "c3") in
  print_encounter e;
  printf "  round %d\n" (Round.to_int (Encounter.round e));
  [%expect
    {|
    round 1, turn 1/1
    > Goblin 3       Goblin   T10/10
    round 1
    (no combatants)
    round 1 |}]
;;

let%expect_test "the round advances on the wrap, not on the step" =
  let e = create three_goblins in
  [%expect
    {|
    round 1, turn 1/3
    > Goblin 1       Goblin   T10/10
      Goblin 2       Goblin   T10/10
      Goblin 3       Goblin   T10/10
    ~ Rebuilt the auto-naming counter from Goblin 3. |}];
  let (_ : Encounter.t) =
    List.fold (List.range 0 7) ~init:e ~f:(fun e _ ->
      let e, wrapped = Encounter.next_turn e in
      printf
        "  turn %d/%d, round %d %s\n"
        (Option.value_exn (Encounter.turn_index e) + 1)
        (Encounter.length e)
        (Round.to_int (Encounter.round e))
        (match wrapped with
         | `Wrapped -> "(new round)"
         | `Same_round -> "");
      e)
  in
  [%expect
    {|
    turn 2/3, round 1
    turn 3/3, round 1
    turn 1/3, round 2 (new round)
    turn 2/3, round 2
    turn 3/3, round 2
    turn 1/3, round 3 (new round)
    turn 2/3, round 3 |}]
;;

(* The asymmetry is deliberate and is the reason [Round.prev] saturates: there is
   no round zero to step back into. *)
let%expect_test "stepping back walks the round back, and stops at round one" =
  let e = create three_goblins in
  [%expect
    {|
    round 1, turn 1/3
    > Goblin 1       Goblin   T10/10
      Goblin 2       Goblin   T10/10
      Goblin 3       Goblin   T10/10
    ~ Rebuilt the auto-naming counter from Goblin 3. |}];
  let e, (_ : [ `Wrapped | `Same_round ]) = Encounter.next_turn e in
  let (_ : Encounter.t) =
    List.fold (List.range 0 4) ~init:e ~f:(fun e _ ->
      let e, (_ : [ `Wrapped | `Same_round ]) = Encounter.prev_turn e in
      printf
        "  turn %d/%d, round %d\n"
        (Option.value_exn (Encounter.turn_index e) + 1)
        (Encounter.length e)
        (Round.to_int (Encounter.round e));
      e)
  in
  [%expect
    {|
    turn 1/3, round 1
    turn 3/3, round 1
    turn 2/3, round 1
    turn 1/3, round 1 |}]
;;

let%expect_test "sorting is by descending initiative and hands the turn to the fastest" =
  let e = create three_goblins in
  [%expect
    {|
    round 1, turn 1/3
    > Goblin 1       Goblin   T10/10
      Goblin 2       Goblin   T10/10
      Goblin 3       Goblin   T10/10
    ~ Rebuilt the auto-naming counter from Goblin 3. |}];
  let e = Encounter.sort_by_initiative e in
  Encounter.invariant e;
  print_encounter e;
  [%expect
    {|
    round 1, turn 1/3
    > Goblin 2       Goblin   T10/10
      Goblin 3       Goblin   T10/10
      Goblin 1       Goblin   T10/10 |}]
;;

let%expect_test "the tally is what the end-of-round summary reports" =
  let e = create three_goblins in
  [%expect
    {|
    round 1, turn 1/3
    > Goblin 1       Goblin   T10/10
      Goblin 2       Goblin   T10/10
      Goblin 3       Goblin   T10/10
    ~ Rebuilt the auto-naming counter from Goblin 3. |}];
  let e =
    Encounter.update e (cid "c2") ~f:(fun c -> { c with toughness = tough ~current:0 10 })
  in
  let `Standing standing, `Down down = Encounter.tally e in
  print_s [%message "" (standing : int) (down : int)];
  [%expect
    {|
    ((standing 2)
     (down     1)) |}]
;;
