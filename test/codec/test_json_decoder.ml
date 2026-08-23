(** The decoder, on its own, before any domain type is involved.

    The one behaviour worth reading closely is the first test: two bad fields
    produce two errors. That is what the applicative buys and what a monadic
    decoder cannot do, and it is the difference between "Loaded" / "Invalid file
    format" and an import dialog that tells a GM what to fix. *)

open! Core
open! Symbaroum
open Expect_test_helpers_core
module D = Json_decoder

let show decoder text =
  match D.run_string decoder text with
  | Ok value -> print_s [%message "ok" ~_:(value : Sexp.t)]
  | Error errors ->
    List.iter errors ~f:(fun error -> print_endline (D.Error.to_string_hum error))
;;

let point =
  let open D.Let_syntax in
  let%map x = D.field "x" D.int
  and y = D.field "y" D.int
  and label = D.field_or "label" D.string ~default:"-" in
  [%message "" (x : int) (y : int) (label : string)]
;;

(* Both halves of every [apply] run whatever the other one does, so the errors
   concatenate. A [bind] would have nothing to feed the continuation after the
   first failure and would have to stop there. *)
let%expect_test "every bad field is reported, not just the first" =
  show point {|{"x": "one", "y": null, "label": 7}|};
  [%expect
    {|
    $.x: expected a whole number, found a string
    $.y: expected a whole number, found null
    $.label: expected a string, found a number |}]
;;

let%expect_test "a good value passes through" =
  show point {|{"x": 1, "y": 2}|};
  [%expect
    {|
    (ok (
      (x     1)
      (y     2)
      (label -))) |}]
;;

let%expect_test "the path says where the problem is" =
  let decoder =
    D.map
      (D.field "encounter" (D.field "members" (D.list point)))
      ~f:(fun points -> Sexp.List points)
  in
  show decoder {|{"encounter": {"members": [{"x": 1, "y": 2}, {"x": 3}]}}|};
  [%expect {| $.encounter.members[1].y: the field is missing |}]
;;

(* JavaScript has one number type and [JSON.stringify] writes 10 for 10.0, so an
   integral float on the wire is an artefact of the format. A fraction is not. *)
let%expect_test "a whole number may arrive as a float" =
  let x = D.map (D.field "x" D.int) ~f:[%sexp_of: int] in
  show x {|{"x": 10.0}|};
  show x {|{"x": 10.5}|};
  [%expect
    {|
    (ok 10)
    $.x: expected a whole number, found 10.5 |}]
;;

(* Missing and null are two spellings of the same absence in the data the React
   app writes: [refId] is null when it was cleared and absent when it was never
   set, and nothing on either side has ever told them apart. *)
let%expect_test "missing and null are the same absence" =
  let decoder =
    D.map (D.field_opt "note" D.string) ~f:(fun note ->
      [%message "" (note : string option)])
  in
  show decoder {|{}|};
  show decoder {|{"note": null}|};
  show decoder {|{"note": "a wounded champion"}|};
  [%expect
    {|
    (ok (note ()))
    (ok (note ()))
    (ok (note ("a wounded champion"))) |}]
;;

let%expect_test "one_of says what it wanted, not what each alternative wanted" =
  let decoder =
    D.one_of
      "a number or null"
      [ D.map D.null ~f:(fun () -> [%message "absent"])
      ; D.map D.int ~f:(fun i -> [%message "" ~_:(i : int)])
      ]
  in
  show (D.field "pain" decoder) {|{"pain": null}|};
  show (D.field "pain" decoder) {|{"pain": 6}|};
  show (D.field "pain" decoder) {|{"pain": "sometimes"}|};
  [%expect
    {|
    (ok absent)
    (ok 6)
    $.pain: expected a number or null, found a string |}]
;;

(* The only way to build a [private] type: a decoded value handed to the smart
   constructor that may refuse it. *)
let%expect_test "validate is where smart constructors run" =
  let decoder =
    D.validate_or_error (D.field "round" D.int) ~f:(fun n ->
      Or_error.map (Round.of_int n) ~f:(fun r -> [%sexp (r : Round.t)]))
  in
  show decoder {|{"round": 3}|};
  show decoder {|{"round": 0}|};
  [%expect
    {|
    (ok 3)
    $: ("Round.of_int: rounds start at 1" (round 0)) |}]
;;

let%expect_test "text that is not JSON is an error at the root, not an exception" =
  show point "not json at all";
  show point "";
  [%expect
    {|
    $: this is not JSON: Line 1, bytes 0-15:
    Invalid token 'not json at all'
    $: this is not JSON: Blank input data |}]
;;

let%expect_test "the wrong shape entirely" =
  show point {|[1, 2, 3]|};
  show (D.map (D.list point) ~f:(fun points -> Sexp.List points)) {|{"x": 1}|};
  [%expect
    {|
    $: expected an object with a x field, found an array
    $: expected an object with a y field, found an array
    $: expected an object with an optional label field, found an array
    $: expected an array, found an object |}]
;;
