(** What holds after {i any} sequence of actions.

    These are the properties the expect tests cannot state. An expect test says
    "this script produced this output"; a property says "no script produces a
    turn index that is out of range", and the generator goes looking for one.

    See {!Test_generators} for why the scripts are generated rather than the
    states. *)

open! Core
open! Symbaroum
open Test_helpers
open Test_generators

let run f = Base_quickcheck.Test.run_exn (module Script) ~f

(* The strongest one, and the reason {!Symbaroum.World.invariant} exists at all:
   it is checked after every step, not only at the end, so a script that passes
   through an inconsistent world and repairs itself later still fails. *)
let%test_unit "the world invariant holds after every action" =
  run (fun script ->
    List.iter (Script.trace script) ~f:(fun (_, world, _) -> World.invariant world))
;;

let%test_unit "there is a current combatant exactly when the fight is not empty" =
  run (fun script ->
    List.iter (Script.trace script) ~f:(fun (_, world, _) ->
      let encounter = world.encounter in
      [%test_result: bool]
        ~message:"is_empty disagrees with current"
        (Option.is_none (Encounter.current encounter))
        ~expect:(Encounter.is_empty encounter);
      match Encounter.turn_index encounter with
      | None -> ()
      | Some index ->
        [%test_pred: int * int]
          (fun (i, n) -> 0 <= i && i < n)
          (index, Encounter.length encounter)))
;;

let%test_unit "no combatant id appears twice" =
  run (fun script ->
    List.iter (Script.trace script) ~f:(fun (_, world, _) ->
      let ids =
        List.map (Encounter.members world.encounter) ~f:(fun (c : Combatant.t) -> c.id)
      in
      [%test_result: bool]
        ~message:"a combatant id is in the fight twice"
        (List.contains_dup ids ~compare:Ids.Combatant_id.compare)
        ~expect:false))
;;

(* The React app numbers the next goblin by counting the goblins currently in the
   encounter, so removing one makes the next name a duplicate. The counter lives
   in the encounter here, and this says the fix holds for every script, not only
   for the one in the bug ledger. *)
let%test_unit "auto-generated names are pairwise distinct" =
  run (fun script ->
    List.iter (Script.trace script) ~f:(fun (_, world, _) ->
      let names =
        List.map (Encounter.members world.encounter) ~f:(fun (c : Combatant.t) ->
          Name.to_string c.name)
      in
      [%test_result: bool]
        ~message:"two combatants have the same name"
        (List.contains_dup names ~compare:String.compare)
        ~expect:false))
;;

let%test_unit "toughness stays between zero and its maximum" =
  run (fun script ->
    List.iter (Script.trace script) ~f:(fun (_, world, _) ->
      List.iter (Encounter.members world.encounter) ~f:(fun (c : Combatant.t) ->
        [%test_pred: Toughness.t]
          (fun t -> t.current >= 0 && t.current <= t.max)
          c.toughness)))
;;

(* [Next_turn] is the only thing that advances the round, and it advances it by
   exactly one, on the wrap. Stated over the trace rather than as a single step
   because the interesting failure is a round that jumps when something else
   happens -- which is precisely the [sortByInitiative] bug. *)
let%test_unit "only stepping the turn moves the round, and never by more than one" =
  run (fun script ->
    let (_ : Round.t) =
      List.fold
        (Script.trace script)
        ~init:(Encounter.round fixture_world.encounter)
        ~f:(fun before (action, world, _) ->
          let after = Encounter.round world.encounter in
          let before = Round.to_int before
          and after' = Round.to_int after in
          (match (action : Action.t) with
           | Next_turn ->
             [%test_pred: int * int] (fun (b, a) -> a = b || a = b + 1) (before, after')
           | Prev_turn ->
             [%test_pred: int * int] (fun (b, a) -> a = b || a = b - 1) (before, after')
           | Remove_member _
           | Delete_character _
           | Clear_encounter _
           | Restore_encounter _ ->
             (* Emptying a fight resets the round, and restoring one brings its
                round back. Both are jumps, and both are the point. *)
             ()
           | _ -> [%test_result: int] after' ~expect:before);
          after)
    in
    ())
;;

let%test_unit "the round is never less than one" =
  run (fun script ->
    List.iter (Script.trace script) ~f:(fun (_, world, _) ->
      [%test_pred: int] (fun r -> r >= 1) (Round.to_int (Encounter.round world.encounter))))
;;

(* The asymmetry {!Symbaroum.Round.prev} documents, asserted rather than left as
   folklore: stepping back always undoes stepping forward, {i except} at the very
   start of the fight, where there is no round zero to return to. *)
let%test_unit "prev_turn undoes next_turn, except at the floor" =
  run (fun script ->
    let world = Script.run script in
    if not (Encounter.is_empty world.encounter)
    then (
      let at_the_floor =
        Round.to_int (Encounter.round world.encounter) = 1
        && Option.value_exn (Encounter.turn_index world.encounter) = 0
      in
      let there, (_ : Event.t list) = World.apply world Next_turn in
      let back, (_ : Event.t list) = World.apply there Prev_turn in
      if at_the_floor
      then
        [%test_result: bool]
          ~message:"the floor did not bite where it was supposed to"
          (World.equal back world)
          ~expect:true
      else [%test_result: Encounter.t] back.encounter ~expect:world.encounter))
;;

(* Reordering is reordering: it may not change who is in the fight, and it may
   not change whose turn it is. The React version tracks the cursor by index and
   gets the second half wrong when the moved combatant crosses it. *)
let%test_unit "moving a combatant changes neither the cast nor the turn" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = Script.t * int * bool [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (script, which, up) ->
      let world = Script.run script in
      match Encounter.members world.encounter with
      | [] -> ()
      | members ->
        let (target : Combatant.t) =
          List.nth_exn members (Int.abs which % List.length members)
        in
        let moved, (_ : Event.t list) =
          World.apply
            world
            (Move_member { id = target.id; direction = (if up then `Up else `Down) })
        in
        World.invariant moved;
        [%test_result: Ids.Combatant_id.t option]
          ~message:"moving a combatant handed the turn to somebody else"
          (Encounter.current_id moved.encounter)
          ~expect:(Encounter.current_id world.encounter);
        [%test_result: Ids.Combatant_id.t list]
          ~message:"moving a combatant changed who is in the fight"
          (List.sort
             (List.map (Encounter.members moved.encounter) ~f:Combatant.id)
             ~compare:Ids.Combatant_id.compare)
          ~expect:
            (List.sort
               (List.map members ~f:Combatant.id)
               ~compare:Ids.Combatant_id.compare))
;;

let%test_unit "sorting keeps the cast, the round, and descending initiative" =
  run (fun script ->
    let world = Script.run script in
    let sorted, (_ : Event.t list) = World.apply world Sort_by_initiative in
    World.invariant sorted;
    [%test_result: Round.t]
      ~message:"sorting moved the round"
      (Encounter.round sorted.encounter)
      ~expect:(Encounter.round world.encounter);
    [%test_result: Ids.Combatant_id.t list]
      (List.sort
         (List.map (Encounter.members sorted.encounter) ~f:Combatant.id)
         ~compare:Ids.Combatant_id.compare)
      ~expect:
        (List.sort
           (List.map (Encounter.members world.encounter) ~f:Combatant.id)
           ~compare:Ids.Combatant_id.compare);
    [%test_pred: int list]
      (fun order -> List.is_sorted order ~compare:Int.descending)
      (List.map (Encounter.members sorted.encounter) ~f:(fun (c : Combatant.t) ->
         Initiative.to_int c.initiative)))
;;

(* [Rejected] is the only event the reducer emits for an action it did not
   perform, so it is also the check that "did nothing" and "said nothing" cannot
   drift apart. *)
let%test_unit "a rejected action leaves the world exactly as it was" =
  run (fun script ->
    let (_ : World.t) =
      List.fold script ~init:fixture_world ~f:(fun world action ->
        let next, events = World.apply world action in
        let rejected =
          List.exists events ~f:(function
            | Event.Rejected _ -> true
            | _ -> false)
        in
        if rejected
        then
          [%test_result: bool]
            ~message:"a rejected action changed the world anyway"
            (World.equal next world)
            ~expect:true;
        next)
    in
    ())
;;
