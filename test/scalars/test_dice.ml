open! Core
open! Symbaroum

let%expect_test "the spellings that actually occur in the data all parse" =
  List.iter
    [ "1D4"; "1D8"; "d8"; "2d6+1"; "2d6 - 1"; "3D6"; ""; "0"; "Light (d4)"; "scales" ]
    ~f:(fun s ->
      print_s [%message "" ~_:(s : string) ~parsed:(Dice.parse s : Dice.t option)]);
  [%expect
    {|
    (1D4 (parsed (((count 1) (sides 4) (modifier 0)))))
    (1D8 (parsed (((count 1) (sides 8) (modifier 0)))))
    (d8 (parsed (((count 1) (sides 8) (modifier 0)))))
    (2d6+1 (parsed (((count 2) (sides 6) (modifier 1)))))
    ("2d6 - 1" (parsed (((count 2) (sides 6) (modifier -1)))))
    (3D6 (parsed (((count 3) (sides 6) (modifier 0)))))
    ("" (parsed ()))
    (0 (parsed ()))
    ("Light (d4)" (parsed ()))
    (scales (parsed ())) |}]
;;

let%expect_test "to_string round-trips through parse" =
  List.iter
    [ Dice.d 4
    ; Dice.d 8
    ; Dice.create_exn ~count:2 ~sides:6 ~modifier:1
    ; Dice.create_exn ~count:2 ~sides:6 ~modifier:(-1)
    ]
    ~f:(fun dice ->
      let text = Dice.to_string dice in
      let back = Dice.parse text in
      print_s
        [%message
          ""
            ~_:(text : string)
            ~round_trips:([%equal: Dice.t option] back (Some dice) : bool)]);
  [%expect
    {|
    (1d4 (round_trips true))
    (1d8 (round_trips true))
    (2d6+1 (round_trips true))
    (2d6-1 (round_trips true)) |}]
;;

(* A closed-form anchor: 2d6 has eleven outcomes with probabilities
   1/36 .. 6/36 .. 1/36. If the convolution is wrong, this is where it shows. *)
let%expect_test "2d6 has the exact eleven-outcome distribution" =
  let distribution = Dice.distribution (Dice.create_exn ~count:2 ~sides:6 ~modifier:0) in
  List.iter distribution ~f:(fun (value, p) ->
    let thirty_sixths = Float.round_nearest (p *. 36.) in
    print_s [%message "" ~total:(value : int) ~probability:(thirty_sixths : float)]);
  [%expect
    {|
    ((total 2) (probability 1))
    ((total 3) (probability 2))
    ((total 4) (probability 3))
    ((total 5) (probability 4))
    ((total 6) (probability 5))
    ((total 7) (probability 6))
    ((total 8) (probability 5))
    ((total 9) (probability 4))
    ((total 10) (probability 3))
    ((total 11) (probability 2))
    ((total 12) (probability 1)) |}];
  print_s [%message "" ~sums_to:(List.sum (module Float) distribution ~f:snd : float)];
  [%expect {| (sums_to 1.0000000000000002) |}]
;;

let%expect_test "bounds and mean" =
  List.iter
    [ Dice.d 4; Dice.d 8; Dice.create_exn ~count:2 ~sides:6 ~modifier:1 ]
    ~f:(fun dice ->
      print_s
        [%message
          ""
            ~_:(Dice.to_string dice : string)
            ~min:(Dice.min_roll dice : int)
            ~max:(Dice.max_roll dice : int)
            ~mean:(Dice.mean dice : float)]);
  [%expect
    {|
    (1d4 (min 1) (max 4) (mean 2.5))
    (1d8 (min 1) (max 8) (mean 4.5))
    (2d6+1 (min 3) (max 13) (mean 8)) |}]
;;

let%test_unit "a distribution sums to one and spans exactly min .. max" =
  Base_quickcheck.Test.run_exn
    (module Dice)
    ~f:(fun dice ->
      let distribution = Dice.distribution dice in
      let total = List.sum (module Float) distribution ~f:snd in
      [%test_pred: float] (fun total -> Float.( < ) (Float.abs (total -. 1.)) 1e-12) total;
      [%test_result: int] (fst (List.hd_exn distribution)) ~expect:(Dice.min_roll dice);
      [%test_result: int] (fst (List.last_exn distribution)) ~expect:(Dice.max_roll dice))
;;

let%test_unit "a roll always lands inside the bounds" =
  let random = Splittable_random.State.of_int 1234 in
  Base_quickcheck.Test.run_exn
    (module Dice)
    ~f:(fun dice ->
      let roll = Dice.roll dice random in
      [%test_pred: int] (fun r -> r >= Dice.min_roll dice && r <= Dice.max_roll dice) roll)
;;
