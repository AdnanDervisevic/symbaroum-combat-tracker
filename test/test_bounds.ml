open! Core
open! Symbaroum

(* NPC_COUNT_MIN and NPC_COUNT_MAX exist in npcConstants.ts and are enforced by
   the min and max attributes of one number input. That is a hint to the browser,
   not a check: the handler reads the count out of component state and never
   revalidates it. *)
let%expect_test "an NPC batch size is bounded by the type, not by the input" =
  List.iter [ 0; 1; 20; 21; 1000 ] ~f:(fun n ->
    print_s [%message "" ~_:(n : int) ~_:(Npc_count.of_int n : Npc_count.t Or_error.t)]);
  [%expect
    {|
    (0
     (Error
      ("value out of range" (module_ Symbaroum.Npc_count) (value 0) (min_value 1)
       (max_value 20))))
    (1 (Ok 1))
    (20 (Ok 20))
    (21
     (Error
      ("value out of range" (module_ Symbaroum.Npc_count) (value 21)
       (min_value 1) (max_value 20))))
    (1000
     (Error
      ("value out of range" (module_ Symbaroum.Npc_count) (value 1000)
       (min_value 1) (max_value 20)))) |}]
;;

(* applyAdjustment clamps to 0 .. 999 and then returns early on zero, so it goes
   to the trouble of representing an adjustment that does nothing. *)
let%expect_test "an adjustment has a magnitude of at least one" =
  List.iter [ 0; 1; 999; 1000 ] ~f:(fun n ->
    print_s
      [%message "" ~_:(n : int) ~_:(Adjust_amount.of_int n : Adjust_amount.t Or_error.t)]);
  [%expect
    {|
    (0
     (Error
      ("value out of range" (module_ Symbaroum.Adjust_amount) (value 0)
       (min_value 1) (max_value 999))))
    (1 (Ok 1))
    (999 (Ok 999))
    (1000
     (Error
      ("value out of range" (module_ Symbaroum.Adjust_amount) (value 1000)
       (min_value 1) (max_value 999)))) |}]
;;

let%expect_test "clamping is available, but it is a separate decision" =
  List.iter [ -5; 0; 4; 5000 ] ~f:(fun n ->
    print_s
      [%message
        ""
          ~_:(n : int)
          ~npc_count:(Npc_count.to_int (Npc_count.of_int_clamped n) : int)
          ~adjust_amount:(Adjust_amount.to_int (Adjust_amount.of_int_clamped n) : int)]);
  [%expect
    {|
    (-5 (npc_count 1) (adjust_amount 1))
    (0 (npc_count 1) (adjust_amount 1))
    (4 (npc_count 4) (adjust_amount 4))
    (5000 (npc_count 20) (adjust_amount 999)) |}]
;;
