(** The rules, which are a reconstruction.

    Printed as a table on purpose. If the formula is wrong against the core book,
    this is the diff a reader compares -- and {!Symbaroum.Hit_chance} is the one
    file that has to change. *)

open! Core
open! Symbaroum

let target ?(prone = false) ?(flanked = false) ~accurate ~defense () =
  Hit_chance.target
    ~attacker_accurate:(Attribute_value.of_int_exn accurate)
    ~defender_defense:(Or_error.ok_exn (Defense.of_target defense))
    ~defender_prone:prone
    ~defender_flanked:flanked
;;

let%expect_test "the roll-under target, across the range that matters" =
  printf "            defence:";
  List.iter [ 2; 5; 10; 13; 15; 18 ] ~f:(fun d -> printf " %4d" d);
  printf "\n";
  List.iter [ 5; 8; 10; 13; 15 ] ~f:(fun accurate ->
    printf "  accurate %2d:       " accurate;
    List.iter [ 2; 5; 10; 13; 15; 18 ] ~f:(fun defense ->
      printf " %4d" (target ~accurate ~defense ()));
    printf "\n");
  [%expect
    {|
              defence:    2    5   10   13   15   18
    accurate  5:          13   10    5    2    1    1
    accurate  8:          16   13    8    5    3    1
    accurate 10:          18   15   10    7    5    2
    accurate 13:          19   18   13   10    8    5
    accurate 15:          19   19   15   12   10    7 |}]
;;

(* A natural 1 always hits and a natural 20 always misses, so no matchup is ever
   certain in either direction. That is the clamp, and it is why the closed-form
   anchor in [test_attrition_dp.ml] is 0.952381 rather than 1. *)
let%expect_test "no fight is ever a foregone conclusion" =
  printf
    "  best case  %d (p = %.2f)\n"
    (target ~accurate:20 ~defense:1 ())
    (Hit_chance.of_matchup
       ~attacker_accurate:(Attribute_value.of_int_exn 20)
       ~defender_defense:(Or_error.ok_exn (Defense.of_target 1))
       ~defender_prone:true
       ~defender_flanked:true);
  printf
    "  worst case %d (p = %.2f)\n"
    (target ~accurate:1 ~defense:20 ())
    (Hit_chance.of_matchup
       ~attacker_accurate:(Attribute_value.of_int_exn 1)
       ~defender_defense:(Or_error.ok_exn (Defense.of_target 20))
       ~defender_prone:false
       ~defender_flanked:false);
  printf "  clamped into [%d, %d]\n" Hit_chance.min_target Hit_chance.max_target;
  [%expect
    {|
    best case  19 (p = 0.95)
    worst case 1 (p = 0.05)
    clamped into [1, 19] |}]
;;

(* Both of these are guesses. They are named constants so that changing them is
   a one-line diff, and [doc/model.md] says plainly that they are unverified. *)
let%expect_test "the two situational modifiers, and their size" =
  printf "  prone bonus   %+d\n" Hit_chance.prone_bonus;
  printf "  flanked bonus %+d\n" Hit_chance.flanked_bonus;
  let plain = target ~accurate:10 ~defense:10 () in
  printf "  against defence 10 with accurate 10:\n";
  printf "    upright, unflanked  %d\n" plain;
  printf "    prone               %d\n" (target ~accurate:10 ~defense:10 ~prone:true ());
  printf "    flanked             %d\n" (target ~accurate:10 ~defense:10 ~flanked:true ());
  printf
    "    both                %d\n"
    (target ~accurate:10 ~defense:10 ~prone:true ~flanked:true ());
  [%expect
    {|
    prone bonus   +2
    flanked bonus +2
    against defence 10 with accurate 10:
      upright, unflanked  10
      prone               12
      flanked             12
      both                14 |}]
;;

let%test_unit "a probability is always a probability" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = Attribute_value.t * Defense.t * bool * bool
      [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (accurate, defense, prone, flanked) ->
      let p =
        Hit_chance.of_matchup
          ~attacker_accurate:accurate
          ~defender_defense:defense
          ~defender_prone:prone
          ~defender_flanked:flanked
      in
      [%test_pred: float] (fun p -> Float.(p >= 0.05 && p <= 0.95)) p)
;;

let%test_unit "being on the ground never helps you" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = Attribute_value.t * Defense.t [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (accurate, defense) ->
      let p prone =
        Hit_chance.of_matchup
          ~attacker_accurate:accurate
          ~defender_defense:defense
          ~defender_prone:prone
          ~defender_flanked:false
      in
      [%test_pred: float * float]
        (fun (upright, prone) -> Float.(prone >= upright))
        (p false, p true))
;;
