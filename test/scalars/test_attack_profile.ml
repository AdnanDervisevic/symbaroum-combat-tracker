open! Core
open! Symbaroum

(* The plan for this port assumed four resistance bands. Counting the shipped
   data finds six: Mighty (4 presets) and Legendary (3) exist as well. Since the
   band is the {i only} thing standing in for weapon data, a missing band would
   have quietly given the seven nastiest creatures in the file a mild weapon. *)
let%expect_test "every resistance band has a damage prior" =
  List.iter Resistance.all ~f:(fun resistance ->
    let dice = Attack_profile.damage_prior resistance in
    print_s
      [%message
        ""
          ~_:(resistance : Resistance.t)
          ~damage:(Dice.to_string dice : string)
          ~mean:(Dice.mean dice : float)]);
  [%expect
    {|
    (Weak (damage 1d6) (mean 3.5))
    (Ordinary (damage 1d8) (mean 4.5))
    (Challenging (damage 1d10) (mean 5.5))
    (Strong (damage 1d12) (mean 6.5))
    (Mighty (damage 1d12+1) (mean 7.5))
    (Legendary (damage 1d12+2) (mean 8.5)) |}]
;;

(* An estimate that cannot be told apart from data is worse than no estimate.
   The provenance is in the value, so the analysis has to decide what to say
   about it and the UI has to decide whether to offer a correction. *)
let%expect_test "an estimated profile says so" =
  let estimated =
    Attack_profile.estimate
      ~accurate:(Attribute_value.of_int_exn 10)
      ~resistance:Resistance.Challenging
  in
  print_s [%sexp (estimated : Attack_profile.t)];
  [%expect
    {|
    ((accurate 10) (damage ((count 1) (sides 10) (modifier 0)))
     (source (Estimated_from_resistance Challenging))) |}];
  print_s [%sexp (Attack_profile.Source.is_estimated estimated.source : bool)];
  [%expect {| true |}];
  let measured =
    Attack_profile.create
      ~accurate:(Attribute_value.of_int_exn 13)
      ~damage:(Dice.create_exn ~count:1 ~sides:8 ~modifier:2)
      ~source:From_data
  in
  print_s [%sexp (measured : Attack_profile.t)];
  [%expect
    {|
    ((accurate 13) (damage ((count 1) (sides 8) (modifier 2)))
     (source From_data)) |}];
  print_s [%sexp (Attack_profile.Source.is_estimated measured.source : bool)];
  [%expect {| false |}]
;;

let%expect_test "resistance round-trips through its wire spelling" =
  List.iter Resistance.all ~f:(fun r ->
    let s = Resistance.to_string r in
    print_s [%message "" ~_:(s : string) ~back:(Resistance.of_string s : Resistance.t)]);
  [%expect
    {|
    (Weak (back Weak))
    (Ordinary (back Ordinary))
    (Challenging (back Challenging))
    (Strong (back Strong))
    (Mighty (back Mighty))
    (Legendary (back Legendary)) |}]
;;
