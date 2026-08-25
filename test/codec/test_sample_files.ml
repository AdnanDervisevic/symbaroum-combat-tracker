(** The whole pipeline against a whole file on disk.

    [doc/samples/v1-export.json] is what the deployed React app writes: its four
    shipped characters verbatim from
    {{:src/data/defaultCharacters.ts} [defaultCharacters.ts]}, a fight in
    progress, and a bestiary entry. It is hand-built rather than exported from
    the live site -- see the open question in [PORT_TODO.md] -- but every field
    spelling in it is taken from {{:src/types.ts} [types.ts]}, and it exercises
    every interesting part of the migration at once:

    - a defence modifier of [8] becoming a roll-under target of [2], and the two
      [0]s becoming [10];
    - a wounded player character recovering its maximum toughness from its roster
      entry, and a wounded NPC recovering its from the bestiary;
    - a name counter rebuilt to [Robber 3], so the next robber added is Robber 4
      rather than a second Robber 3 -- which is the React naming bug, fixed at
      the import boundary rather than only at the adding one;
    - [attributes: null] on every character, which is one of the three spellings
      of absence that collapse into one value here. *)

open! Core
open! Symbaroum
open Test_helpers

let sample = In_channel.read_all "../doc/samples/v1-export.json"

let%expect_test "a version 1 export reads, and says what it changed" =
  match Codec.decode_string sample with
  | Error errors ->
    List.iter errors ~f:(fun e -> printf "! %s\n" (Json_decoder.Error.to_string_hum e))
  | Ok { world; normalizations } ->
    World.invariant world;
    print_encounter world.encounter;
    List.iter (Roster.to_list world.roster) ~f:(fun (c : Character.t) ->
      printf
        "  %-10s rolls under %2d, so attackers get %+d\n"
        (Name.to_string c.name)
        (Defense.to_int c.defense)
        (Defense.to_modifier c.defense));
    List.iter normalizations ~f:(fun n ->
      printf "  ~ %s\n" (Normalization.to_string_hum n));
    [%expect
      {|
      round 3, turn 3/4
        Vigoi          PC       T6/10
        Ymma           PC       T10/10
      > Robber 1       Robber   T4/11 [prone]
        Robber 3       Robber   T11/11
      Cassimei   rolls under  8, so attackers get +2
      Thalia     rolls under  3, so attackers get +7
      Vigoi      rolls under  1, so attackers get +9
      Ymma       rolls under  1, so attackers get +9
      ~ characters[2].defense (as a roll-under target) 0 is out of range; clamped to 1.
      ~ characters[3].defense (as a roll-under target) 0 is out of range; clamped to 1.
      ~ encounter.members[0].defense (as a roll-under target) 0 is out of range; clamped to 1.
      ~ encounter.members[1].defense (as a roll-under target) 0 is out of range; clamped to 1.
      ~ Rebuilt the auto-naming counter from Robber 3. |}]
;;

(* The counter is the point of the previous test's last line, so it gets its own
   assertion: adding a robber after the import must not produce a second Robber
   3. *)
let%expect_test "the next NPC added after an import continues the numbering" =
  let { Codec.world; normalizations = _ } =
    Or_error.ok_exn
      (Result.map_error (Codec.decode_string sample) ~f:(fun errors ->
         Error.create_s [%sexp (errors : Json_decoder.Error.t list)]))
  in
  let draft =
    { Npc_draft.default with
      monster_type = Some (mt "Robber")
    ; count = Npc_count.of_int_exn 1
    }
  in
  let world, (_ : Event.t list) =
    World.apply
      world
      (Add_npcs { draft; ids = [ cid "cmb_new" ]; bestiary_id = bid "bst_robber"; at })
  in
  print_s
    [%sexp
      (List.map (Encounter.members world.encounter) ~f:(fun c -> Name.to_string c.name)
       : string list)];
  [%expect {| (Vigoi Ymma "Robber 1" "Robber 3" "Robber 4") |}]
;;

(* Reading a v1 file and writing it back gives a v2 file, and reading {i that}
   changes nothing further. Whatever the migration did, it did once. *)
let%expect_test "converting to version 2 is a fixed point" =
  match Codec.decode_string sample with
  | Error _ -> print_endline "the sample did not read"
  | Ok { world; normalizations = _ } ->
    (match Codec.decode_string (Codec.encode_string world) with
     | Error errors ->
       List.iter errors ~f:(fun e -> printf "! %s\n" (Json_decoder.Error.to_string_hum e))
     | Ok { world = again; normalizations } ->
       printf "identical: %b\n" (World.equal again world);
       printf "further corrections: %d\n" (List.length normalizations));
    [%expect
      {|
      identical: true
      further corrections: 0 |}]
;;
