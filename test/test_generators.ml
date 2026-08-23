(** Generators for the property tests.

    Two rules shape everything here.

    {b Generate through the smart constructors.} A generated value is a legal
    value by construction, so a counterexample is always a real one rather than a
    state the app could never reach. Most of the work is already done, because
    the scalars derive their own generators from bounded types.

    {b Generate scripts, not states.} The interesting property is not "is this
    {!Symbaroum.World.t} consistent" but "does it stay consistent after any
    sequence of things a user can do". So the generator produces an
    {!Symbaroum.Action.t} list and the properties fold it over
    {!Test_helpers.fixture_world}. That also sidesteps the question of how to
    generate a [private] type without a public constructor.

    The ids come from small fixed pools. Freely generated ids would produce a
    script that is almost entirely [Rejected] -- which exercises the rejection
    path thoroughly and everything else not at all. *)

open! Core
open! Symbaroum
open Base_quickcheck
open Test_helpers

let combatant_ids =
  List.init 6 ~f:(fun i -> Ids.Combatant_id.of_string [%string "cmb_%{i#Int}"])
;;

let character_ids = fixture_ids

let snapshot_ids =
  List.init 2 ~f:(fun i -> Ids.Snapshot_id.of_string [%string "snp_%{i#Int}"])
;;

let bestiary_ids =
  List.init 2 ~f:(fun i -> Ids.Bestiary_id.of_string [%string "bst_%{i#Int}"])
;;

let monster_types = List.map [ "Goblin"; "Robber"; "Troll" ] ~f:Monster_type.of_string

(** The number of NPCs added at once is kept small and its ids are drawn from the
    same pool, so batches collide with each other and with the player characters
    -- which is where the duplicate-id and name-collision properties earn their
    keep. *)
let npc_batch =
  let open Generator.Let_syntax in
  let%bind monster_type = Generator.of_list monster_types in
  let%bind length = Generator.of_list [ 1; 2; 3 ] in
  let%bind ids = Generator.list_with_length (Generator.of_list combatant_ids) ~length in
  let%map bestiary_id = Generator.of_list bestiary_ids in
  let draft =
    { Npc_draft.default with
      monster_type = Some monster_type
    ; count = Npc_count.of_int_exn (List.length ids)
    }
  in
  Action.Add_npcs { draft; ids; bestiary_id; at = Time_ns.of_int_ns_since_epoch 0 }
;;

let action =
  let open Generator.Let_syntax in
  let combatant_id = Generator.of_list combatant_ids in
  let character_id = Generator.of_list character_ids in
  let snapshot_id = Generator.of_list snapshot_ids in
  Generator.union
    [ npc_batch
    ; (let%map characters =
         Generator.list_non_empty
           (let%map id = character_id in
            id, Ids.Combatant_id.of_string ("cmb_" ^ Ids.Character_id.to_string id))
       in
       Action.Add_player_characters { characters })
    ; (let%map id = character_id in
       Action.Delete_character { id })
    ; (let%bind id = character_id in
       let%map patch = Character_patch.quickcheck_generator in
       Action.Update_character { id; patch })
    ; (let%bind id = combatant_id in
       let%map patch = Member_patch.quickcheck_generator in
       Action.Update_member { id; patch })
    ; (let%bind id = combatant_id in
       let%bind amount = Adjust_amount.quickcheck_generator in
       let%map mode = Generator.of_list [ `Hurt; `Heal ] in
       Action.Adjust { id; amount; mode })
    ; (let%map id = combatant_id in
       Action.Remove_member { id })
    ; (let%bind id = combatant_id in
       let%map direction = Generator.of_list [ `Up; `Down ] in
       Action.Move_member { id; direction })
    ; Generator.return Action.Sort_by_initiative
    ; Generator.return Action.Next_turn
    ; Generator.return Action.Prev_turn
    ; Generator.return Action.Sync_members_from_roster
    ; (let%map snapshot_id = snapshot_id in
       Action.Clear_encounter { snapshot_id; at = Time_ns.of_int_ns_since_epoch 0 })
    ; (let%map id = snapshot_id in
       Action.Restore_encounter { id })
    ]
;;

(* [Next_turn] and [Prev_turn] are weighted up because a fight is mostly turns,
   and because the round arithmetic is what several properties are about. *)
let weighted_action =
  Generator.weighted_union
    [ 3.0, Generator.return Action.Next_turn
    ; 1.0, Generator.return Action.Prev_turn
    ; 6.0, action
    ]
;;

module Script = struct
  type t = Action.t list [@@deriving sexp_of]

  let quickcheck_generator : t Generator.t = Generator.list weighted_action
  let quickcheck_shrinker : t Shrinker.t = Shrinker.list Shrinker.atomic

  (* Nothing ever observes a script -- one never appears as the argument of a
     generated function -- but [@@deriving quickcheck] on a tuple containing one
     asks for all three of the trio, so here is the third. *)
  let quickcheck_observer : t Observer.t = Observer.opaque

  (** Every world a script passes through, so a property can be stated about the
      whole run rather than only its result. *)
  let trace t =
    List.folding_map t ~init:fixture_world ~f:(fun world action ->
      let next, events = World.apply world action in
      next, (action, next, events))
  ;;

  let run t = fst (World.apply_all fixture_world t)
end
