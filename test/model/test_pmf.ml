(** Damage distributions, convolved exactly.

    The 2d6 row is a closed-form anchor: those eleven numbers are 1/36 through
    6/36 and back, and nothing about the implementation gets to have an opinion
    about them. *)

open! Core
open! Symbaroum

let show t =
  List.iter (Pmf.to_alist t) ~f:(fun (value, p) -> printf "  %2d  %.6f\n" value p);
  printf "  total %.15f, mean %.4f\n" (Pmf.total t) (Pmf.mean t)
;;

let dice s = Option.value_exn (Dice.parse s)

let%expect_test "2d6, exactly" =
  show (Pmf.of_dice (dice "2d6"));
  [%expect
    {|
     2  0.027778
     3  0.055556
     4  0.083333
     5  0.111111
     6  0.138889
     7  0.166667
     8  0.138889
     9  0.111111
    10  0.083333
    11  0.055556
    12  0.027778
    total 1.000000000000000, mean 7.0000 |}]
;;

let%expect_test "a fixed value is a point mass" =
  show (Pmf.of_reduction (Fixed 3));
  show (Pmf.of_reduction Unarmored);
  [%expect
    {|
     3  1.000000
    total 1.000000000000000, mean 3.0000
     0  1.000000
    total 1.000000000000000, mean 0.0000 |}]
;;

(* The rule the type exists for: armour cannot heal you. Every outcome at or
   below zero lands on zero rather than being dropped, so the result still sums
   to one -- a blow that fails to get through is a blow that happened and did
   nothing. *)
let%expect_test "damage minus armour, floored at zero" =
  show (Pmf.sub_clamped (Pmf.of_dice (dice "1d6")) (Pmf.of_reduction (Fixed 3)));
  [%expect
    {|
     0  0.500000
     1  0.166667
     2  0.166667
     3  0.166667
    total 1.000000000000000, mean 1.0000 |}]
;;

let%expect_test "a die against a die" =
  show
    (Pmf.sub_clamped (Pmf.of_dice (dice "1d8")) (Pmf.of_reduction (Rolled (dice "1d4"))));
  [%expect
    {|
     0  0.312500
     1  0.125000
     2  0.125000
     3  0.125000
     4  0.125000
     5  0.093750
     6  0.062500
     7  0.031250
    total 1.000000000000000, mean 2.3125 |}]
;;

let%expect_test "armour that always wins leaves all the mass on zero" =
  show (Pmf.sub_clamped (Pmf.of_dice (dice "1d4")) (Pmf.of_reduction (Fixed 20)));
  [%expect
    {|
     0  1.000000
    total 1.000000000000000, mean 0.0000 |}]
;;

let%test_unit "every distribution sums to one" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = Dice.t * Armor.Reduction.t [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (dice, reduction) ->
      let weapon = Pmf.of_dice dice in
      let armor = Pmf.of_reduction reduction in
      let net = Pmf.sub_clamped weapon armor in
      List.iter [ weapon; armor; net ] ~f:(fun t ->
        [%test_pred: float] (fun total -> Float.(abs (total - 1.) < 1e-12)) (Pmf.total t)))
;;

let%test_unit "armour weakly reduces the mean, and never below zero" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = Dice.t * Armor.Reduction.t [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (dice, reduction) ->
      let weapon = Pmf.of_dice dice in
      let net = Pmf.sub_clamped weapon (Pmf.of_reduction reduction) in
      [%test_pred: float * float]
        (fun (net, weapon) -> Float.(net <= weapon +. 1e-12 && net >= 0.))
        (Pmf.mean net, Pmf.mean weapon))
;;

(* The sampler and the summer have to agree, or {!Symbaroum.Combat_sim} is not an
   oracle for {!Symbaroum.Attrition_dp}, it is a second opinion. *)
let%test_unit "sampling reproduces the distribution it was drawn from" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = Dice.t [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun dice ->
      let t = Pmf.of_dice dice in
      let random = Splittable_random.State.of_int 7 in
      let samples = 20_000 in
      let counts = Array.create ~len:(Pmf.length t) 0 in
      for _ = 1 to samples do
        let value = Pmf.sample t random in
        counts.(value) <- counts.(value) + 1
      done;
      Array.iteri counts ~f:(fun value count ->
        let observed = Float.of_int count /. Float.of_int samples in
        let expected = Pmf.prob t value in
        (* Four standard errors of a binomial, plus slack for the tiny cells. *)
        let tolerance =
          (4. *. Float.sqrt (expected *. (1. -. expected) /. Float.of_int samples))
          +. 0.002
        in
        [%test_pred: float * float * int]
          (fun (observed, expected, _) -> Float.(abs (observed - expected) <= tolerance))
          (observed, expected, value)))
;;
