open! Core
open! Symbaroum

(* [painThreshold: number | null] carries a three-way distinction in a two-way
   type. The difference between "never prones" and "every hit prones" is real,
   and today it survives only as the reader's memory that [0 >= 0]. *)
let%expect_test "the three cases are three constructors" =
  List.iter [ None; Some 0; Some 5; Some (-2) ] ~f:(fun raw ->
    print_s
      [%message
        ""
          ~stored:(raw : int option)
          ~parsed:(Pain_threshold.of_int_option raw : Pain_threshold.t)]);
  [%expect
    {|
    ((stored ()) (parsed No_threshold))
    ((stored (0)) (parsed Every_hit))
    ((stored (5)) (parsed (At_least 5)))
    ((stored (-2)) (parsed Every_hit)) |}]
;;

let%expect_test "and they round-trip back to the wire spelling" =
  List.iter
    [ Pain_threshold.no_threshold; Pain_threshold.every_hit; Pain_threshold.at_least 5 ]
    ~f:(fun t ->
      print_s
        [%message
          "" ~_:(t : Pain_threshold.t) ~wire:(Pain_threshold.to_int_option t : int option)]);
  [%expect
    {|
    (No_threshold (wire ()))
    (Every_hit (wire (0)))
    ((At_least 5) (wire (5))) |}]
;;

(* Bug ledger: test_pain_threshold_uses_damage_dealt.
   [applyAdjustment] (App.tsx:411) compares the raw number typed into the box
   against the threshold. It never subtracts armour. A 9 typed against a
   combatant in 4 points of armour lands for 5, which is under a threshold of 8 --
   but the React app prones anyway, because it is looking at the 9. *)
let%expect_test "test_pain_threshold_uses_damage_dealt" =
  let threshold = Pain_threshold.at_least 8 in
  let armor = Armor.parse "4" in
  let toughness = Toughness.create_exn ~current:10 ~max:10 in
  let typed = 9 in
  let absorbed = Int.of_float (Armor.Reduction.mean (Option.value_exn armor.reduction)) in
  let through_armor = Int.max 0 (typed - absorbed) in
  let after, _dealt = Toughness.damage toughness through_armor in
  print_s
    [%message
      ""
        ~typed_into_the_box:(typed : int)
        ~absorbed_by_armor:(absorbed : int)
        ~(through_armor : int)
        ~toughness_after:(after : Toughness.t)
        ~react_prones_on_the_typed_number:
          (Pain_threshold.is_exceeded threshold ~damage:typed : bool)
        ~ocaml_prones_on_what_got_through:
          (Pain_threshold.is_exceeded threshold ~damage:through_armor : bool)];
  [%expect
    {|
    ((typed_into_the_box 9) (absorbed_by_armor 4) (through_armor 5)
     (toughness_after ((current 5) (max 10)))
     (react_prones_on_the_typed_number true)
     (ocaml_prones_on_what_got_through false)) |}]
;;

(* The other quantity in play is the damage actually absorbed by the target,
   which is smaller again when the blow is lethal. The threshold deliberately
   does not use it: the two differ only when the combatant is reduced to zero,
   and a combatant at zero is down, not prone. Recording the case here so the
   choice is visible rather than accidental. *)
let%expect_test "the overkill case, and why the threshold ignores it" =
  let threshold = Pain_threshold.at_least 5 in
  let toughness = Toughness.create_exn ~current:3 ~max:10 in
  let through_armor = 9 in
  let after, dealt = Toughness.damage toughness through_armor in
  print_s
    [%message
      ""
        (through_armor : int)
        ~actually_absorbed:(dealt : int)
        ~toughness_after:(after : Toughness.t)
        ~is_down:(Toughness.is_down after : bool)
        ~prones:(Pain_threshold.is_exceeded threshold ~damage:through_armor : bool)];
  [%expect
    {|
    ((through_armor 9) (actually_absorbed 3)
     (toughness_after ((current 0) (max 10))) (is_down true) (prones true)) |}]
;;

let%expect_test "no_threshold never prones, every_hit prones on any real damage" =
  let show t =
    List.map [ 0; 1; 7 ] ~f:(fun damage -> damage, Pain_threshold.is_exceeded t ~damage)
  in
  print_s
    [%message "no_threshold" ~_:(show Pain_threshold.no_threshold : (int * bool) list)];
  [%expect {| (no_threshold ((0 false) (1 false) (7 false))) |}];
  print_s [%message "every_hit" ~_:(show Pain_threshold.every_hit : (int * bool) list)];
  [%expect {| (every_hit ((0 false) (1 true) (7 true))) |}];
  print_s
    [%message "at_least 5" ~_:(show (Pain_threshold.at_least 5) : (int * bool) list)];
  [%expect {| ("at_least 5" ((0 false) (1 false) (7 true))) |}]
;;
