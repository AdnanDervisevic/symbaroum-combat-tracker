open! Core
open! Symbaroum

let%expect_test "toughness is current and maximum, not one number doing both" =
  let t = Toughness.full 10 |> ok_exn in
  print_s [%sexp (t : Toughness.t)];
  [%expect {| ((current 10) (max 10)) |}];
  let wounded, taken = Toughness.damage t 4 in
  print_s [%message "" ~after_a_4_point_hit:(wounded : Toughness.t) (taken : int)];
  [%expect {| ((after_a_4_point_hit ((current 6) (max 10))) (taken 4)) |}]
;;

(* The overkill case is why [damage] reports what it actually took: a 9-point
   swing against 3 remaining toughness deals 3, and every downstream rule -- the
   pain threshold above all -- has to reason about 3, not 9. *)
let%expect_test "damage floors at zero and reports what it really dealt" =
  let t = Toughness.create_exn ~current:3 ~max:10 in
  let after, taken = Toughness.damage t 9 in
  print_s
    [%message
      "" (after : Toughness.t) (taken : int) ~is_down:(Toughness.is_down after : bool)];
  [%expect {| ((after ((current 0) (max 10))) (taken 3) (is_down true)) |}]
;;

let%expect_test "healing caps at the maximum" =
  let t = Toughness.create_exn ~current:8 ~max:10 in
  let after, restored = Toughness.heal t 5 in
  print_s [%message "" (after : Toughness.t) (restored : int)];
  [%expect {| ((after ((current 10) (max 10))) (restored 2)) |}]
;;

let%expect_test "an out-of-range pair cannot be built" =
  print_s [%sexp (Toughness.create ~current:12 ~max:10 : Toughness.t Or_error.t)];
  [%expect
    {| (Error ("Toughness.create: current outside 0 .. max" (current 12) (max 10))) |}];
  print_s [%sexp (Toughness.create ~current:(-4) ~max:10 : Toughness.t Or_error.t)];
  [%expect
    {| (Error ("Toughness.create: current outside 0 .. max" (current -4) (max 10))) |}];
  (* What the import path does instead: repair, and report the repair. *)
  print_s [%sexp (Toughness.create_clamped ~current:(-4) ~max:10 : Toughness.t)];
  [%expect {| ((current 0) (max 10)) |}]
;;

let%test_unit "0 <= current <= max survives any sequence of adjustments" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = Toughness.t * int list [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (start, deltas) ->
      let final =
        List.fold deltas ~init:start ~f:(fun t delta ->
          if delta < 0
          then fst (Toughness.damage t (-delta))
          else fst (Toughness.heal t delta))
      in
      [%test_pred: Toughness.t] (fun t -> t.current >= 0 && t.current <= t.max) final;
      [%test_result: int] final.max ~expect:start.max)
;;
