open! Core
open! Symbaroum

let%expect_test "an identity cannot be blank" =
  let show s =
    print_s
      [%message
        ""
          ~_:(s : string)
          ~_:
            (Or_error.try_with (fun () -> Ids.Character_id.of_string s)
             : Ids.Character_id.t Or_error.t)]
  in
  show "pc_default_cassimei";
  [%expect {| (pc_default_cassimei (Ok pc_default_cassimei)) |}];
  show "";
  [%expect
    {|
    (""
     (Error
      (Invalid_argument
       "'' is not a valid Symbaroum.Ids.Character_id because it is empty"))) |}];
  show "  padded  ";
  [%expect
    {|
    ("  padded  "
     (Error
      (Invalid_argument
       "'  padded  ' is not a valid Symbaroum.Ids.Character_id because it has whitespace on the edge"))) |}]
;;

(* CharacterCard.tsx:112 asks whether the id starts with "pc_default_" to decide
   whether a character is built in. The id has no opinion about that here; the
   character record carries an is_builtin field instead (Phase 3). This test
   exists to record that the smuggled property is gone, and that a user is free
   to name a character anything at all without changing how it behaves. *)
let%expect_test "an identity carries no data" =
  let looks_builtin = Ids.Character_id.of_string "pc_default_impostor" in
  print_s [%sexp (looks_builtin : Ids.Character_id.t)];
  [%expect {| pc_default_impostor |}]
;;

let%expect_test "a numbered NPC name is built from its monster type" =
  let goblin = Monster_type.of_string "Goblin" in
  List.iter [ 1; 3; 12 ] ~f:(fun n ->
    print_s [%sexp (Name.numbered ~base:goblin n : Name.t)]);
  [%expect
    {|
    "Goblin 1"
    "Goblin 3"
    "Goblin 12" |}]
;;
