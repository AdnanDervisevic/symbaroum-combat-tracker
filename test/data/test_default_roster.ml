(** The shipped roster is content, not behaviour.

    The GM edits it -- fills in a sheet that was blank, renames somebody, writes
    down the defence they actually rolled under last session. So this file checks
    only what has to hold whatever the numbers say, and nothing else in the suite
    reads it: the behaviour tests run against [Test_helpers.fixture_roster]
    instead. Pinning these values anywhere else would mean asserting that nobody
    has played the game lately. *)

open! Core
open! Symbaroum

let%expect_test "the shipped roster is well-formed, whatever the numbers say" =
  let all = Default_roster.all in
  let ids = List.map all ~f:Character.id in
  let unique compare xs = not (List.contains_dup xs ~compare) in
  printf "characters:     %d\n" (List.length all);
  printf "ids unique:     %b\n" (unique Ids.Character_id.compare ids);
  printf "names unique:   %b\n" (unique Name.compare (List.map all ~f:Character.name));
  printf "all builtin:    %b\n" (List.for_all all ~f:Character.is_builtin);
  (* Load-bearing rather than cosmetic: [Migrate] recovers [is_builtin] from this
     prefix, because v1 never stored the flag. Renaming an id silently demotes
     that character on every import of an old save. *)
  printf
    "ids prefixed:   %b\n"
    (List.for_all ids ~f:(fun id ->
       String.is_prefix (Ids.Character_id.to_string id) ~prefix:"pc_default_"));
  printf
    "at full health: %b\n"
    (List.for_all all ~f:(fun (c : Character.t) -> c.toughness.current = c.toughness.max));
  printf "reaches Roster: %b\n" (Roster.length Roster.default = List.length all);
  [%expect
    {|
    characters:     4
    ids unique:     true
    names unique:   true
    all builtin:    true
    ids prefixed:   true
    at full health: true
    reaches Roster: true |}]
;;

(* [defense] on a player character is the target they roll under -- the number on
   the sheet -- and [Defense.t] holds exactly that. A monster table prints the
   modifier instead; that reading lives in [Monster_preset] and in [Migrate], and
   is checked in [test/scalars/test_defense.ml]. The only thing worth asserting
   here is that the roster went through the sheet reading, which it did if every
   character survived construction at all: [Defense.of_target] rejects the [0]
   that an unfilled sheet stores. *)
let%expect_test "a blank sheet is not a defence" =
  print_s [%sexp (Defense.of_target 0 : Defense.t Or_error.t)];
  [%expect
    {|
    (Error
     ("value out of range" (module_ Symbaroum.Defense) (value 0) (min_value 1)
      (max_value 20)))
    |}]
;;
