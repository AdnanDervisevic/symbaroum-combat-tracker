open! Core
open! Symbaroum

(* The [defense] field has two spellings, and which one applies depends on whose
   sheet the number came off. A monster table prints the modifier an attacker
   applies; a player character's sheet prints the roll-under target itself. Both
   describe the same quantity -- a creature whose Quick is the target -- and
   differ only by [10 - x], which is why [Defense.t] stores one of them and names
   both constructors. Where each reading is applied is in [Migrate]; the ledger
   row is [test_v1_defense_reads_by_side]. *)
let%expect_test "the two preset spellings of Defence reconcile to one value" =
  let show label result =
    print_s [%message "" ~_:(label : string) ~_:(result : Defense.t Or_error.t)]
  in
  (* Spring Elf: qui 13, defense -3. *)
  show "Spring Elf, read as a modifier" (Defense.of_modifier (-3));
  [%expect {| ("Spring Elf, read as a modifier" (Ok 13)) |}];
  show "Spring Elf, read as a target" (Defense.of_target 13);
  [%expect {| ("Spring Elf, read as a target" (Ok 13)) |}];
  (* Servant Daemon: qui 15, defense 15. *)
  show "Servant Daemon, read as a target" (Defense.of_target 15);
  [%expect {| ("Servant Daemon, read as a target" (Ok 15)) |}];
  show "Servant Daemon, read as a modifier" (Defense.of_modifier 15);
  [%expect
    {|
    ("Servant Daemon, read as a modifier"
     (Error
      ("value out of range" (module_ Symbaroum.Defense) (value -5) (min_value 1)
       (max_value 20)))) |}]
;;

let%expect_test "target and modifier are two views of one number" =
  List.iter [ 3; 10; 13; 15; 20 ] ~f:(fun target ->
    let defense = Defense.of_int_exn target in
    print_s
      [%message
        ""
          ~target:(Defense.to_int defense : int)
          ~modifier:(Defense.to_modifier defense : int)]);
  [%expect
    {|
    ((target 3) (modifier 7))
    ((target 10) (modifier 0))
    ((target 13) (modifier -3))
    ((target 15) (modifier -5))
    ((target 20) (modifier -10)) |}]
;;

let%test_unit "of_modifier inverts to_modifier" =
  Base_quickcheck.Test.run_exn
    (module Defense)
    ~f:(fun defense ->
      [%test_result: Defense.t Or_error.t]
        (Defense.of_modifier (Defense.to_modifier defense))
        ~expect:(Ok defense))
;;
