open! Core
open Expect_test_helpers_core

(* The four shipped player characters, with the defence reading applied. The
   point of printing [defense] both ways is that the React file stores the
   modifier and the UI shows it, while every rules question wants the target. *)

let%expect_test "the shipped roster" =
  List.iter Symbaroum.Default_roster.all ~f:(fun (c : Symbaroum.Character.t) ->
    printf
      "%-10s %-8s T%d/%d  defense %2d (modifier) -> %2d (target)  armor %-12s %s\n"
      (Symbaroum.Name.to_string c.name)
      c.role
      c.toughness.current
      c.toughness.max
      (Symbaroum.Character.defense_modifier c)
      (Symbaroum.Defense.to_int c.defense)
      c.armor.text
      (if c.is_builtin then "builtin" else "user"));
  [%expect
    {|
    Cassimei   Bard     T10/10  defense  8 (modifier) ->  2 (target)  armor Light (d4)   builtin
    Thalia     Wizard   T10/10  defense  3 (modifier) ->  7 (target)  armor Light (d4)   builtin
    Vigoi      Warrior  T10/10  defense  0 (modifier) -> 10 (target)  armor Medium (d8)  builtin
    Ymma       Goblin   T10/10  defense  0 (modifier) -> 10 (target)  armor Light (d4)   builtin |}]
;;

let%expect_test "a new character is average, not the React default" =
  (* [buildNewCharacter] in combatLogic.ts sets [defense: 10], which under the
     modifier reading is a target of 0 -- a roll-under target nobody can fail.
     The port's default is a modifier of 0, an exactly average target of 10. *)
  let c =
    Symbaroum.Character.create_new ~id:(Symbaroum.Ids.Character_id.of_string "pc_1")
  in
  print_s
    [%message
      ""
        ~defense_modifier:(Symbaroum.Character.defense_modifier c : int)
        ~defense_target:(Symbaroum.Defense.to_int c.defense : int)
        ~react_default_would_be:
          (Symbaroum.Defense.of_modifier 10 : Symbaroum.Defense.t Or_error.t)];
  [%expect
    {|
    ((defense_modifier 0)
     (defense_target   10)
     (react_default_would_be (
       Error (
         "value out of range"
         (module_   Symbaroum.Defense)
         (value     0)
         (min_value 1)
         (max_value 20))))) |}]
;;
