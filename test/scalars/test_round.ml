open! Core
open! Symbaroum

let%expect_test "rounds start at one, and zero cannot be built" =
  print_s [%sexp (Round.first : Round.t)];
  [%expect {| 1 |}];
  print_s [%sexp (Round.of_int 0 : Round.t Or_error.t)];
  [%expect {| (Error ("Round.of_int: rounds start at 1" (round 0))) |}];
  print_s [%sexp (Round.of_int_clamped 0 : Round.t)];
  [%expect {| 1 |}]
;;

(* The asymmetry is deliberate and is the interesting half of the invariant:
   stepping back from round 1 is a no-op, so one direction composes to the
   identity and the other does not. Asserting the exception is what stops it
   becoming folklore. *)
let%expect_test "prev floors at one, so succ and prev do not commute there" =
  print_s
    [%message "" ~prev_of_succ_of_first:(Round.prev (Round.succ Round.first) : Round.t)];
  [%expect {| (prev_of_succ_of_first 1) |}];
  print_s
    [%message "" ~succ_of_prev_of_first:(Round.succ (Round.prev Round.first) : Round.t)];
  [%expect {| (succ_of_prev_of_first 2) |}]
;;

let%test_unit "prev undoes succ everywhere" =
  Base_quickcheck.Test.run_exn
    (module Round)
    ~f:(fun round ->
      [%test_result: Round.t] (Round.prev (Round.succ round)) ~expect:round)
;;

let%test_unit "succ undoes prev except at the floor" =
  Base_quickcheck.Test.run_exn
    (module Round)
    ~f:(fun round ->
      let round_tripped = Round.succ (Round.prev round) in
      if Round.equal round Round.first
      then [%test_result: Round.t] round_tripped ~expect:(Round.succ Round.first)
      else [%test_result: Round.t] round_tripped ~expect:round)
;;
