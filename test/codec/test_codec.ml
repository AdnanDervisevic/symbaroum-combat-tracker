(** The pipeline end to end: what a file looks like, what round-trips, what is
    repaired, and what is refused. *)

open! Core
open! Symbaroum
open Expect_test_helpers_core
open Test_helpers

let show_normalizations normalizations =
  match (normalizations : Normalization.t list) with
  | [] -> print_endline "  (no corrections)"
  | normalizations ->
    List.iter normalizations ~f:(fun n ->
      printf "  ~ %s\n" (Normalization.to_string_hum n))
;;

let decode text =
  match Codec.decode_string text with
  | Ok { world; normalizations } ->
    World.invariant world;
    show_normalizations normalizations;
    Some world
  | Error errors ->
    List.iter errors ~f:(fun e -> printf "  ! %s\n" (Json_decoder.Error.to_string_hum e));
    None
;;

(** Encodes, decodes, and reports whether the world came back unchanged and
    unrepaired -- which is the strong form of the round-trip property. *)
let round_trip world =
  match Codec.decode_string (Codec.encode_string world) with
  | Error errors ->
    List.iter errors ~f:(fun e -> printf "  ! %s\n" (Json_decoder.Error.to_string_hum e))
  | Ok { world = decoded; normalizations } ->
    printf "  identical: %b\n" (World.equal decoded world);
    show_normalizations normalizations
;;

(* A whole fight, so the round trip covers every store: a roster, NPCs with
   preset attack profiles, a bestiary entry and an archived encounter. *)
let a_used_world =
  lazy
    (let party =
       List.map [ "pc_default_cassimei"; "pc_default_vigoi" ] ~f:(fun id ->
         let id = chid id in
         id, cid ("cmb_" ^ Ids.Character_id.to_string id))
     in
     let draft =
       { (Npc_draft.of_preset (preset "Robber")) with count = Npc_count.of_int_exn 2 }
     in
     fst
       (World.apply_all
          World.initial
          [ Add_player_characters { characters = party }
            (* Cleared first, so the archive holds a fight and the live encounter
               is a different one. *)
          ; Clear_encounter { snapshot_id = sid "snap_1"; at }
          ; Add_player_characters { characters = party }
          ; Add_npcs
              { draft
              ; ids = [ cid "cmb_r1"; cid "cmb_r2" ]
              ; bestiary_id = bid "bst_robber"
              ; at
              }
          ; Sort_by_initiative
          ; Next_turn
          ; Adjust { id = cid "cmb_r1"; amount = amount 7; mode = `Hurt }
          ]))
;;

let%expect_test "an empty world, so the format is readable at a glance" =
  print_endline (Codec.encode_string World.empty);
  [%expect
    {|
    {
      "version": 2,
      "characters": [],
      "encounter": {
        "members": [],
        "turn_index": 0,
        "round": 1,
        "name_counter": []
      },
      "bestiary": [],
      "archive": []
    } |}]
;;

let%expect_test "the shipped world round-trips exactly, with nothing repaired" =
  round_trip World.initial;
  [%expect
    {|
    identical: true
    (no corrections) |}]
;;

let%expect_test "and so does one that has been played" =
  round_trip (force a_used_world);
  [%expect
    {|
    identical: true
    (no corrections) |}]
;;

(* One combatant, printed whole, because this is the record with every
   interesting field on it: a fused allegiance, a current-and-max toughness, a
   defence stored as a target, and an attack profile that remembers it is an
   estimate. *)
let%expect_test "one combatant, in full" =
  let world = force a_used_world in
  let json = Codec.to_json world in
  let member =
    let open Yojson.Safe.Util in
    json
    |> member "encounter"
    |> member "members"
    |> to_list
    |> List.find_exn ~f:(fun m -> not (Yojson.Safe.equal (member "attack" m) `Null))
  in
  print_endline (Yojson.Safe.pretty_to_string member);
  [%expect
    {|
    {
      "id": "cmb_r1",
      "allegiance": { "npc": "Robber" },
      "name": "Robber 1",
      "initiative": 10,
      "toughness": { "current": 4, "max": 11 },
      "defense": 6,
      "armor": "3",
      "pain_threshold": 6,
      "prone": true,
      "flanked": false,
      "attributes": {
        "acc": 10,
        "cun": 5,
        "dis": 13,
        "per": 9,
        "qui": 10,
        "res": 7,
        "str": 11,
        "vig": 15
      },
      "attack": {
        "accurate": 10,
        "damage": { "count": 1, "sides": 6, "modifier": 0 },
        "estimated_from": "Weak"
      },
      "note": ""
    } |}]
;;

let%expect_test "what the reader refuses" =
  let refuse text =
    printf "%s\n" (String.prefix text 60);
    (match Codec.decode_string text with
     | Ok _ -> print_endline "  (accepted)"
     | Error errors ->
       List.iter errors ~f:(fun e ->
         printf "  ! %s\n" (Json_decoder.Error.to_string_hum e)));
    print_endline ""
  in
  refuse "this is not a save file";
  refuse "{";
  refuse {|{"characters": [], "encounter": {"members": []}}|};
  (* [validateImportData] checks that [version] is a number and never compares it
     to anything, so this file is accepted and blind-cast in the React app. *)
  refuse {|{"version": 7, "characters": [], "encounter": {"members": []}}|};
  refuse {|{"version": 1, "characters": {}, "encounter": {"members": []}}|};
  refuse {|{"version": 1, "characters": [], "encounter": {"members": {}}}|};
  [%expect
    {|
    this is not a save file
      ! $: this is not JSON: Line 1, bytes 0-23:
    Invalid token 'this is not a save file'

    {
      ! $: this is not JSON: Line 1, bytes 0-1:
    Unexpected end of input

    {"characters": [], "encounter": {"members": []}}
      ! $.version: the field is missing

    {"version": 7, "characters": [], "encounter": {"members": []
      ! $.version: this file says version 7; this app reads versions 1 and 2

    {"version": 1, "characters": {}, "encounter": {"members": []
      ! $.characters: expected an array, found an object

    {"version": 1, "characters": [], "encounter": {"members": {}
      ! $.encounter.members: expected an array, found an object |}]
;;

(* The demonstration of the applicative: one file, four unrelated problems, four
   messages with paths. The React import says "Invalid file format". *)
let%expect_test "four problems in one file, all four reported" =
  let (_ : World.t option) =
    decode
      {|{ "version": 1
        , "characters":
            [ {"id": "a", "name": "Ymma", "toughness": "lots"}
            , {"id": "b"}
            ]
        , "encounter": {"members": [{"id": "c"}], "turnIndex": "first"}
        }|}
  in
  [%expect
    {|
    ! $.characters[0].toughness: expected a whole number, found a string
    ! $.characters[1].name: the field is missing
    ! $.encounter.members[0].name: the field is missing
    ! $.encounter.turnIndex: expected a whole number, found a string |}]
;;

let%expect_test "a v1 export from the deployed app" =
  let world =
    decode
      {|{ "version": 1
        , "characters":
            [ { "id": "pc_default_ymma", "name": "Ymma", "role": "Goblin"
              , "initiative": 11, "toughness": 10, "defense": 0
              , "armor": "Light (d4)", "painThreshold": 5
              , "attributes": {"acc": 10, "qui": 10, "str": 10, "res": 10}
              , "note": "" }
            , { "id": "pc_custom_1", "name": "Brakk", "role": "Fighter"
              , "initiative": 9, "toughness": 12, "defense": 3
              , "armor": "chitin", "painThreshold": null
              , "attributes": null, "note": "a friend" }
            ]
        , "encounter":
            { "members":
                [ { "id": "cmb_1", "source": "pc", "refId": "pc_default_ymma"
                  , "name": "Ymma", "initiative": 11, "toughness": 4
                  , "defense": 0, "armor": "Light (d4)", "painThreshold": 5
                  , "prone": true, "flanked": false }
                , { "id": "cmb_2", "source": "npc", "monsterType": "Goblin"
                  , "name": "Goblin 3", "initiative": 8, "toughness": 6
                  , "defense": 2, "armor": "2", "painThreshold": 3
                  , "prone": false, "flanked": false }
                ]
            , "turnIndex": 1, "round": 3 }
        , "bestiary":
            [ { "id": "bst_1", "monsterType": "Goblin", "initiative": 8
              , "toughness": 11, "defense": 2, "armor": "2"
              , "painThreshold": 3, "note": "", "updatedAt": 1700000000000 } ]
        }|}
  in
  Option.iter world ~f:(fun world ->
    print_encounter world.encounter;
    List.iter (Roster.to_list world.roster) ~f:(fun (c : Character.t) ->
      printf
        "  %-10s defense target %-3d armor %-12s builtin %b\n"
        (Name.to_string c.name)
        (Defense.to_int c.defense)
        c.armor.text
        c.is_builtin));
  [%expect
    {|
    ~ Rebuilt the auto-naming counter from Goblin 3.
    round 3, turn 2/2
      Ymma           PC       T4/10 [prone]
    > Goblin 3       Goblin   T6/11
    Ymma       defense target 10  armor Light (d4)   builtin true
    Brakk      defense target 7   armor chitin       builtin false |}]
;;

(* v1's single [toughness] is a maximum on a roster entry and whatever is left on
   a combatant. Ymma above is at 4, and her roster entry says 10, so she comes
   back at 4 of 10 rather than 4 of 4. The goblin is at 6 and the bestiary says
   11. Neither number is in the file as a pair; both are recovered. *)
let%expect_test "a wounded combatant recovers its maximum from the roster or the bestiary"
  =
  let world =
    decode
      {|{ "version": 1
        , "characters":
            [ { "id": "pc_1", "name": "Ymma", "toughness": 10, "defense": 0
              , "armor": "", "painThreshold": null, "note": "" } ]
        , "encounter":
            { "members":
                [ { "id": "c1", "source": "pc", "refId": "pc_1", "name": "Ymma"
                  , "toughness": 4, "defense": 0, "armor": ""
                  , "painThreshold": null, "prone": false, "flanked": false }
                , { "id": "c2", "source": "npc", "monsterType": "Goblin"
                  , "name": "Goblin 1", "toughness": 6, "defense": 2
                  , "armor": "", "painThreshold": null, "prone": false
                  , "flanked": false }
                , { "id": "c3", "source": "npc", "monsterType": "Wight"
                  , "name": "Wight 1", "toughness": 5, "defense": 2
                  , "armor": "", "painThreshold": null, "prone": false
                  , "flanked": false }
                ]
            , "turnIndex": 0, "round": 1 }
        , "bestiary":
            [ { "id": "b1", "monsterType": "Goblin", "toughness": 11
              , "defense": 2, "armor": "", "painThreshold": null, "note": ""
              , "updatedAt": 0 } ]
        }|}
  in
  Option.iter world ~f:(fun world -> print_encounter world.encounter);
  [%expect
    {|
    ~ Rebuilt the auto-naming counter from Goblin 1, Wight 1.
    round 1, turn 1/3
    > Ymma           PC       T4/10
      Goblin 1       Goblin   T6/11
      Wight 1        Wight    T5/5 |}]
;;

(* The state the React type permits and four separate paths produce. Nothing on
   the import side has ever repaired it. *)
let%expect_test "an out-of-range turn index and a round of zero are repaired and reported"
  =
  let (_ : World.t option) =
    decode
      {|{ "version": 1, "characters": []
        , "encounter":
            { "members":
                [ {"id": "c1", "source": "npc", "name": "Goblin 1", "toughness": 10, "defense": 0, "armor": "", "painThreshold": null, "prone": false, "flanked": false} ]
            , "turnIndex": 5, "round": 0 }
        }|}
  in
  [%expect
    {|
    ~ Rebuilt the auto-naming counter from NPC 1.
    ~ There is no turn 6; moved to turn 1.
    ~ Round 0 is not a round; set to 1. |}]
;;

let%expect_test "a combatant pointing at a character that is gone becomes an NPC" =
  let world =
    decode
      {|{ "version": 1, "characters": []
        , "encounter":
            { "members":
                [ {"id": "c1", "source": "pc", "refId": "pc_deleted", "name": "Ghost", "toughness": 10, "defense": 0, "armor": "", "painThreshold": null, "prone": false, "flanked": false} ]
            , "turnIndex": 0, "round": 1 }
        }|}
  in
  Option.iter world ~f:(fun world -> print_encounter world.encounter);
  [%expect
    {|
    ~ Ghost points at character pc_deleted, which is gone; demoted to an NPC.
    ~ Rebuilt the auto-naming counter from NPC 1.
    round 1, turn 1/1
    > Ghost          NPC      T10/10 |}]
;;

let%expect_test "a repaired file is a fixed point: reading it back changes nothing" =
  let text =
    {|{ "version": 1, "characters": []
      , "encounter":
          { "members":
              [ {"id": "c1", "source": "npc", "monsterType": "Goblin", "name": "Goblin 7", "toughness": 400, "defense": 99, "armor": "chitin", "painThreshold": null, "prone": false, "flanked": false} ]
          , "turnIndex": 9, "round": 0 }
      }|}
  in
  printf "first read:\n";
  let world = Option.value_exn (decode text) in
  printf "written back and read again:\n";
  let (_ : World.t option) = decode (Codec.encode_string world) in
  [%expect
    {|
    first read:
      ~ encounter.members[0].defense (as a roll-under target) -89 is out of range; clamped to 1.
      ~ Rebuilt the auto-naming counter from Goblin 7.
      ~ There is no turn 10; moved to turn 1.
      ~ Round 0 is not a round; set to 1.
    written back and read again:
      (no corrections) |}]
;;

let%expect_test "the five localStorage keys the deployed app writes" =
  let stored =
    String.Map.of_alist_exn
      [ ( "sct.v1.characters"
        , {|[{"id": "pc_1", "name": "Ymma", "toughness": 10, "defense": 0, "armor": "", "painThreshold": null, "note": ""}]|}
        )
      ; ( "sct.v1.encounter"
        , {|{"members": [{"id": "c1", "source": "pc", "refId": "pc_1", "name": "Ymma", "toughness": 7, "defense": 0, "armor": "", "painThreshold": null, "prone": false, "flanked": false}], "turnIndex": 0, "round": 2}|}
        )
      ; "sct.v1.bestiary", {|[ this is not json |}
      ]
  in
  let { Codec.world; normalizations }, errors =
    Codec.of_local_storage_v1 ~find:(Map.find stored)
  in
  World.invariant world;
  print_encounter world.encounter;
  show_normalizations normalizations;
  (* The unreadable key costs the bestiary and nothing else. Refusing to start
     because one of five keys is corrupt would be the worse trade. *)
  List.iter errors ~f:(fun e -> printf "  ! %s\n" (Json_decoder.Error.to_string_hum e));
  printf "  bestiary entries: %d\n" (Bestiary.length world.bestiary);
  [%expect
    {|
      round 2, turn 1/1
      > Ymma           PC       T7/10
      (no corrections)
      ! sct.v1.bestiary: this is not JSON: Line 1, bytes 2-19:
    Invalid token 'this is not json '
      bestiary entries: 0 |}]
;;

(* {1 Properties} *)

let%test_unit "any world survives the round trip unchanged and unrepaired" =
  Base_quickcheck.Test.run_exn
    (module Test_generators.Script)
    ~f:(fun script ->
      let world = Test_generators.Script.run script in
      match Codec.decode_string (Codec.encode_string world) with
      | Error errors ->
        raise_s
          [%message
            "a world this app wrote did not read back"
              (errors : Json_decoder.Error.t list)]
      | Ok { world = decoded; normalizations } ->
        [%test_result: Normalization.t list]
          ~message:"reading back a file this app wrote needed repairs"
          normalizations
          ~expect:[];
        [%test_result: World.t] decoded ~expect:world)
;;

(* Arbitrary JSON, including near-misses drawn from the real key names, so the
   generator spends its time on shapes that get past the first field.
   [validateImportData] fails this catastrophically: it blind-casts anything that
   has a numeric [version], an array of objects with [id] and [name], and an
   [encounter.members] array. *)
module Arbitrary_json = struct
  type t = Yojson.Safe.t

  let sexp_of_t json = Sexp.Atom (Yojson.Safe.to_string json)

  let quickcheck_generator =
    let open Base_quickcheck.Generator.Let_syntax in
    let key =
      Base_quickcheck.Generator.of_list
        [ "version"
        ; "characters"
        ; "encounter"
        ; "members"
        ; "turnIndex"
        ; "round"
        ; "bestiary"
        ; "id"
        ; "name"
        ; "toughness"
        ; "source"
        ; "wat"
        ]
    in
    Base_quickcheck.Generator.recursive_union
      [ Base_quickcheck.Generator.return `Null
      ; (let%map b = Base_quickcheck.Generator.bool in
         `Bool b)
      ; (let%map i = Base_quickcheck.Generator.int in
         `Int i)
      ; (let%map f = Base_quickcheck.Generator.float in
         `Float f)
      ; (let%map s = Base_quickcheck.Generator.string in
         `String s)
      ]
      ~f:(fun self ->
        [ (let%map items = Base_quickcheck.Generator.list self in
           `List items)
        ; (let%map fields =
             Base_quickcheck.Generator.list (Base_quickcheck.Generator.both key self)
           in
           `Assoc fields)
        ])
  ;;

  let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
end

let%test_unit "the decoder is total: arbitrary JSON gives Ok or Error, never an exception"
  =
  Base_quickcheck.Test.run_exn
    (module Arbitrary_json)
    ~f:(fun json ->
      match Codec.decode_json json with
      | Error _ -> ()
      | Ok { world; normalizations = _ } ->
        (* And whatever it does accept is a legal world. *)
        World.invariant world)
;;
