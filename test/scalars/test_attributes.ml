open! Core
open! Symbaroum

(* The React app spells "this creature has no attributes" three ways -- absent,
   [null], and [{}] -- and each of the eight fields three more. Here there is one
   spelling, and it is a value rather than an absence. *)
let%expect_test "an empty attribute block is key-total" =
  print_s [%sexp (Attributes.empty : Attributes.t)];
  [%expect
    {|
    ((Accurate ()) (Cunning ()) (Discreet ()) (Persuasive ()) (Quick ())
     (Resolute ()) (Strong ()) (Vigilant ())) |}];
  print_s [%sexp (Attributes.is_empty Attributes.empty : bool)];
  [%expect {| true |}]
;;

let%expect_test "of_alist fills in the attributes it was not given" =
  let attributes =
    Attributes.of_alist
      [ Attribute.Quick, Some (Attribute_value.of_int_exn 13)
      ; Attribute.Accurate, Some (Attribute_value.of_int_exn 10)
      ]
    |> ok_exn
  in
  print_s
    [%sexp
      (Attributes.to_known_alist attributes : (Attribute.t * Attribute_value.t) list)];
  [%expect {| ((Accurate 10) (Quick 13)) |}];
  print_s [%sexp (Attributes.count_known attributes : int)];
  [%expect {| 2 |}];
  print_s [%sexp (List.length (Attributes.to_alist attributes) : int)];
  [%expect {| 8 |}]
;;

let%expect_test "of_alist rejects a duplicate key" =
  let result =
    Attributes.of_alist
      [ Attribute.Quick, Some (Attribute_value.of_int_exn 13)
      ; Attribute.Quick, Some (Attribute_value.of_int_exn 15)
      ]
  in
  print_s [%sexp (result : Attributes.t Or_error.t)];
  [%expect {| (Error ("Attributes.of_alist: duplicate attribute" (key Quick))) |}]
;;

(* [areAttributesEqual] in combatLogic.ts exists because [{}], [null] and
   [{acc: null}] all mean the same thing and none of them compares equal. With a
   key-total map the derived compare is already the right answer, so that
   function -- and [normalizeAttributes] and [cloneAttributes] with it -- has
   nothing left to do. *)
let%expect_test "equality is structural, so areAttributesEqual is not needed" =
  let quick_13 =
    Attributes.set Attributes.empty Attribute.Quick (Some (Attribute_value.of_int_exn 13))
  in
  let same =
    Attributes.of_alist [ Attribute.Quick, Some (Attribute_value.of_int_exn 13) ]
    |> ok_exn
  in
  print_s [%sexp (Attributes.equal quick_13 same : bool)];
  [%expect {| true |}];
  let cleared = Attributes.set quick_13 Attribute.Quick None in
  print_s [%sexp (Attributes.equal cleared Attributes.empty : bool)];
  [%expect {| true |}]
;;

let%expect_test "every attribute round-trips through its wire key" =
  List.iter Attribute.all ~f:(fun attribute ->
    let key = Attribute.to_key attribute in
    let back = Attribute.of_key key in
    print_s
      [%message
        ""
          ~_:(key : string)
          ~label:(Attribute.to_label attribute : string)
          (back : Attribute.t option)]);
  [%expect
    {|
    (acc (label ACC) (back (Accurate)))
    (cun (label CUN) (back (Cunning)))
    (dis (label DIS) (back (Discreet)))
    (per (label PER) (back (Persuasive)))
    (qui (label QUI) (back (Quick)))
    (res (label RES) (back (Resolute)))
    (str (label STR) (back (Strong)))
    (vig (label VIG) (back (Vigilant))) |}]
;;

let%expect_test "an attribute score is bounded, and its modifier is 10 - raw" =
  let show n =
    print_s [%sexp (Attribute_value.of_int n : Attribute_value.t Or_error.t)]
  in
  show 0;
  [%expect
    {|
    (Error
     ("value out of range" (module_ Symbaroum.Attribute_value) (value 0)
      (min_value 1) (max_value 20))) |}];
  show 1;
  [%expect {| (Ok 1) |}];
  show 21;
  [%expect
    {|
    (Error
     ("value out of range" (module_ Symbaroum.Attribute_value) (value 21)
      (min_value 1) (max_value 20))) |}];
  List.iter [ 5; 10; 13; 15 ] ~f:(fun n ->
    let v = Attribute_value.of_int_exn n in
    print_s
      [%message
        ""
          ~raw:(Attribute_value.to_int v : int)
          ~modifier:(Attribute_value.modifier v : int)]);
  [%expect
    {|
    ((raw 5) (modifier 5))
    ((raw 10) (modifier 0))
    ((raw 13) (modifier -3))
    ((raw 15) (modifier -5)) |}]
;;

let%test_unit "modifier is always 10 - raw" =
  Base_quickcheck.Test.run_exn
    (module Attribute_value)
    ~f:(fun v ->
      [%test_result: int]
        (Attribute_value.modifier v)
        ~expect:(10 - Attribute_value.to_int v))
;;

let%test_unit "a generated attribute block is always key-total" =
  Base_quickcheck.Test.run_exn
    (module Attributes)
    ~f:(fun t ->
      [%test_result: int]
        (List.length (Attributes.to_alist t))
        ~expect:(List.length Attribute.all))
;;
