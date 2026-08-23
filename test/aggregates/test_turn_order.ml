(** The nonempty zipper.

    Most of what this type buys cannot be tested directly, because it is the
    {i absence} of a state: there is no test for "the turn index is never out of
    range" when there is no turn index to range-check. What is left worth
    checking is the part a zipper can still get wrong -- that the cursor follows
    the combatant it is on rather than the slot it sits in -- and the wrap flags,
    which are what {!Symbaroum.Encounter} reads to decide the round. *)

open! Core
open! Symbaroum
open Expect_test_helpers_core

let of_list_exn xs = Option.value_exn (Turn_order.of_list xs)

let show (t : int Turn_order.t) =
  printf
    "%s [%d] %s   (index %d of %d)\n"
    (String.concat ~sep:" " (List.rev_map t.before ~f:Int.to_string))
    t.current
    (String.concat ~sep:" " (List.map t.after ~f:Int.to_string))
    (Turn_order.index t)
    (Turn_order.length t)
;;

let%expect_test "the empty list has no zipper, which is the whole point" =
  print_s [%sexp (Turn_order.of_list ([] : int list) : int Turn_order.t option)];
  [%expect {| () |}];
  print_s
    [%sexp
      (Turn_order.of_list_with_focus ([] : int list) ~focus:5
       : (int Turn_order.t * Normalization.t list) option)];
  [%expect {| () |}]
;;

(* This is the repair that [handleImport] and [restoreEncounter] skip entirely.
   It happens here, once, and says so. *)
let%expect_test "an out-of-range focus is clamped, and the clamp is reported" =
  List.iter [ -3; 0; 2; 9 ] ~f:(fun focus ->
    let t, normalizations =
      Option.value_exn (Turn_order.of_list_with_focus [ 10; 20; 30 ] ~focus)
    in
    printf "focus %d -> index %d  " focus (Turn_order.index t);
    print_s [%sexp (normalizations : Normalization.t list)]);
  [%expect
    {|
    focus -3 -> index 0  ((
      Turn_index_clamped
      (given -3)
      (used  0)))
    focus 0 -> index 0  ()
    focus 2 -> index 2  ()
    focus 9 -> index 2  ((
      Turn_index_clamped
      (given 9)
      (used  2))) |}]
;;

let%expect_test "next and prev wrap, and say when they did" =
  let t = of_list_exn [ 1; 2; 3 ] in
  let t =
    List.fold (List.range 0 4) ~init:t ~f:(fun t _ ->
      let t, wrapped = Turn_order.next t in
      printf
        "next -> %d (%s)\n"
        (Turn_order.current t)
        (Sexp.to_string [%sexp (wrapped : [ `Wrapped | `Same_round ])]);
      t)
  in
  let (_ : int Turn_order.t) =
    List.fold (List.range 0 2) ~init:t ~f:(fun t _ ->
      let t, wrapped = Turn_order.prev t in
      printf
        "prev -> %d (%s)\n"
        (Turn_order.current t)
        (Sexp.to_string [%sexp (wrapped : [ `Wrapped | `Same_round ])]);
      t)
  in
  [%expect
    {|
    next -> 2 (Same_round)
    next -> 3 (Same_round)
    next -> 1 (Wrapped)
    next -> 2 (Same_round)
    prev -> 1 (Same_round)
    prev -> 3 (Wrapped) |}]
;;

(* The React behaviour, minus the case where it left the index dangling: whoever
   moves into the vacated slot takes the turn. *)
let%expect_test "removing the current element hands the turn to the next one" =
  let t = of_list_exn [ 1; 2; 3; 4 ] in
  let t, (_ : [ `Wrapped | `Same_round ]) = Turn_order.next t in
  show t;
  show (Option.value_exn (Turn_order.remove t ~f:(fun x -> x = 2)));
  [%expect
    {|
    1 [2] 3 4   (index 1 of 4)
    1 [3] 4   (index 1 of 3) |}];
  (* ... and at the end of the order there is no next, so it is the new last. *)
  let t = Turn_order.focus (of_list_exn [ 1; 2; 3; 4 ]) ~f:(fun x -> x = 4) in
  show (Option.value_exn (Turn_order.remove t ~f:(fun x -> x = 4)));
  [%expect {| 1 2 [3]    (index 2 of 3) |}];
  (* Removing someone earlier in the order shifts the cursor with them. *)
  let t = Turn_order.focus (of_list_exn [ 1; 2; 3; 4 ]) ~f:(fun x -> x = 4) in
  show (Option.value_exn (Turn_order.remove t ~f:(fun x -> x = 1)));
  [%expect {| 2 3 [4]    (index 2 of 3) |}]
;;

let%expect_test "removing the only element leaves no zipper at all" =
  print_s
    [%sexp
      (Turn_order.remove (Turn_order.singleton 1) ~f:(fun _ -> true)
       : int Turn_order.t option)];
  [%expect {| () |}]
;;

(* Written with duplicate values on purpose. [move] tracks the cursor
   arithmetically rather than by searching for the element it was on, because
   [phys_equal] on an unboxed [int] -- or on two combatants that happen to
   compare equal -- would put the cursor on the wrong one. *)
let%expect_test "move follows the element under the cursor, not the index" =
  let t, (_ : Normalization.t list) =
    Option.value_exn (Turn_order.of_list_with_focus [ 1; 2; 1; 3 ] ~focus:2)
  in
  show t;
  show (Turn_order.move t ~f:(fun x -> x = 3) `Up);
  show (Turn_order.move t ~f:(fun x -> x = 2) `Down);
  [%expect
    {|
    1 2 [1] 3   (index 2 of 4)
    1 2 3 [1]    (index 3 of 4)
    1 [1] 2 3   (index 1 of 4) |}]
;;

let%expect_test "move is a no-op at the ends" =
  let t = of_list_exn [ 1; 2; 3 ] in
  show (Turn_order.move t ~f:(fun x -> x = 1) `Up);
  show (Turn_order.move t ~f:(fun x -> x = 3) `Down);
  show (Turn_order.move t ~f:(fun x -> x = 99) `Up);
  [%expect
    {|
    [1] 2 3   (index 0 of 3)
    [1] 2 3   (index 0 of 3)
    [1] 2 3   (index 0 of 3) |}]
;;

let%expect_test "sorting is stable and puts the cursor back on the first entry" =
  let t = Turn_order.focus (of_list_exn [ 3; 1; 2; 1 ]) ~f:(fun x -> x = 2) in
  show t;
  show (Turn_order.sort_by t ~compare:(fun a b -> Int.descending a b));
  [%expect
    {|
    3 1 [2] 1   (index 2 of 4)
     [3] 2 1 1   (index 0 of 4) |}]
;;

let%expect_test "add_last appends without disturbing the turn" =
  let t = of_list_exn [ 1; 2 ] in
  let t, (_ : [ `Wrapped | `Same_round ]) = Turn_order.next t in
  show (Turn_order.add_last t 3);
  [%expect {| 1 [2] 3   (index 1 of 3) |}]
;;

(* The properties. A zipper is generated as a nonempty list plus a focus, which
   is the only way in, so every generated value is legal by construction. *)
module Zipper = struct
  type t = int * int list * int [@@deriving quickcheck, sexp_of]

  let build (head, tail, focus) =
    fst (Option.value_exn (Turn_order.of_list_with_focus (head :: tail) ~focus))
  ;;
end

let%test_unit "the cursor is always a real position" =
  Base_quickcheck.Test.run_exn
    (module Zipper)
    ~f:(fun args ->
      let t = Zipper.build args in
      let index = Turn_order.index t in
      [%test_pred: int * int] (fun (i, n) -> 0 <= i && i < n) (index, Turn_order.length t);
      [%test_result: int]
        (List.nth_exn (Turn_order.to_list t) index)
        ~expect:(Turn_order.current t))
;;

let%test_unit "prev undoes next, everywhere -- the zipper has no floor" =
  Base_quickcheck.Test.run_exn
    (module Zipper)
    ~f:(fun args ->
      let t = Zipper.build args in
      let stepped, (_ : [ `Wrapped | `Same_round ]) = Turn_order.next t in
      let back, (_ : [ `Wrapped | `Same_round ]) = Turn_order.prev stepped in
      [%test_result: int Turn_order.t] back ~expect:t)
;;

let%test_unit "next wraps exactly when it returns to the first combatant" =
  Base_quickcheck.Test.run_exn
    (module Zipper)
    ~f:(fun args ->
      let t = Zipper.build args in
      let stepped, wrapped = Turn_order.next t in
      let expect = if Turn_order.index stepped = 0 then `Wrapped else `Same_round in
      [%test_result: [ `Wrapped | `Same_round ]] wrapped ~expect)
;;

let%test_unit "move permutes and preserves whose turn it is" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = Zipper.t * int * bool [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (args, target, up) ->
      let t = Zipper.build args in
      let moved =
        Turn_order.move t ~f:(fun x -> x = target) (if up then `Up else `Down)
      in
      [%test_result: int] (Turn_order.current moved) ~expect:(Turn_order.current t);
      [%test_result: int list]
        (List.sort (Turn_order.to_list moved) ~compare:Int.compare)
        ~expect:(List.sort (Turn_order.to_list t) ~compare:Int.compare))
;;

let%test_unit "removing an element that is not the current one keeps the turn" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = Zipper.t * int [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (args, target) ->
      let t = Zipper.build args in
      if Turn_order.current t <> target
      then (
        match Turn_order.remove t ~f:(fun x -> x = target) with
        | None -> assert false (* the current element is still there *)
        | Some removed ->
          [%test_result: int] (Turn_order.current removed) ~expect:(Turn_order.current t)))
;;
