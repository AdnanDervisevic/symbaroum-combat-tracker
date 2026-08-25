open! Core
open! Symbaroum

(* Every armour spelling that occurs in the shipped data, plus one that does not
   parse. Nothing in the React app reads any of them. *)
let%expect_test "armour parses the shipped spellings and keeps the rest verbatim" =
  List.iter
    [ ""; "0"; "2"; "4"; "10"; "1D4"; "1D8"; "Light (d4)"; "Medium (d8)"; "chitin"; "-1" ]
    ~f:(fun text ->
      let armor = Armor.parse text in
      print_s
        [%message
          ""
            ~_:(text : string)
            ~reduction:(armor.reduction : Armor.Reduction.t option)
            ~mean:(Option.map armor.reduction ~f:Armor.Reduction.mean : float option)]);
  [%expect
    {|
    ("" (reduction (Unarmored)) (mean (0)))
    (0 (reduction (Unarmored)) (mean (0)))
    (2 (reduction ((Fixed 2))) (mean (2)))
    (4 (reduction ((Fixed 4))) (mean (4)))
    (10 (reduction ((Fixed 10))) (mean (10)))
    (1D4 (reduction ((Rolled ((count 1) (sides 4) (modifier 0))))) (mean (2.5)))
    (1D8 (reduction ((Rolled ((count 1) (sides 8) (modifier 0))))) (mean (4.5)))
    ("Light (d4)" (reduction ((Rolled ((count 1) (sides 4) (modifier 0)))))
     (mean (2.5)))
    ("Medium (d8)" (reduction ((Rolled ((count 1) (sides 8) (modifier 0)))))
     (mean (4.5)))
    (chitin (reduction ()) (mean ()))
    (-1 (reduction ()) (mean ())) |}]
;;

(* The free text survives the parse, which is what lets the codec claim an exact
   round-trip rather than an "up to normalization" one -- and what keeps the UI
   showing "Light (d4)" rather than "1d4". *)
let%expect_test "the text the user typed is preserved, parsed or not" =
  List.iter [ "Light (d4)"; "chitin"; "  4  " ] ~f:(fun text ->
    let armor = Armor.parse text in
    print_s
      [%message
        ""
          ~typed:(text : string)
          ~kept:(armor.text : string)
          ~unparsed:(Armor.is_unparsed armor : bool)]);
  [%expect
    {|
    ((typed "Light (d4)") (kept "Light (d4)") (unparsed false))
    ((typed chitin) (kept chitin) (unparsed true))
    ((typed "  4  ") (kept 4) (unparsed false)) |}]
;;

let%test_unit "parse is total" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = string [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun text ->
      let armor = Armor.parse text in
      [%test_result: string] armor.text ~expect:(String.strip text))
;;
