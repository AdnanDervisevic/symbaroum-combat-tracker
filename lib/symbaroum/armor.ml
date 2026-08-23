open! Core

module Reduction = struct
  type t =
    | Unarmored
    | Fixed of int
    | Rolled of Dice.t
  [@@deriving compare, equal, sexp_of]

  let min_value = function
    | Unarmored -> 0
    | Fixed n -> n
    | Rolled dice -> Dice.min_roll dice
  ;;

  let max_value = function
    | Unarmored -> 0
    | Fixed n -> n
    | Rolled dice -> Dice.max_roll dice
  ;;

  let mean = function
    | Unarmored -> 0.
    | Fixed n -> Float.of_int n
    | Rolled dice -> Dice.mean dice
  ;;

  let quickcheck_generator =
    Base_quickcheck.Generator.union
      [ Base_quickcheck.Generator.return Unarmored
      ; Base_quickcheck.Generator.map
          (Base_quickcheck.Generator.int_inclusive 1 10)
          ~f:(fun n -> Fixed n)
      ; Base_quickcheck.Generator.map [%quickcheck.generator: Dice.t] ~f:(fun d ->
          Rolled d)
      ]
  ;;

  let quickcheck_observer = Base_quickcheck.Observer.opaque
  let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
end

type t =
  { text : string
  ; reduction : Reduction.t option
  }
[@@deriving compare, equal, sexp_of]

let max_fixed = 99

(* Tried in order: nothing at all, a plain integer, a dice expression, a dice
   expression inside parentheses (which is how player-character armour is
   written: "Light (d4)"). Anything else is kept verbatim and marked unparsed. *)
let parse text =
  let text = String.strip text in
  let parenthesized () =
    let%bind.Option _, after = String.lsplit2 text ~on:'(' in
    let%bind.Option inside, _ = String.rsplit2 after ~on:')' in
    Dice.parse inside
  in
  let reduction =
    if String.is_empty text
    then Some Reduction.Unarmored
    else (
      match Int.of_string_opt text with
      | Some 0 -> Some Reduction.Unarmored
      | Some n when n > 0 && n <= max_fixed -> Some (Reduction.Fixed n)
      | Some _ -> None
      | None ->
        (match Dice.parse text with
         | Some dice -> Some (Reduction.Rolled dice)
         | None -> Option.map (parenthesized ()) ~f:(fun dice -> Reduction.Rolled dice)))
  in
  { text; reduction }
;;

let unarmored = parse ""
let none = unarmored
let is_unparsed t = Option.is_none t.reduction

let quickcheck_generator =
  Base_quickcheck.Generator.map
    (Base_quickcheck.Generator.of_list
       [ ""; "0"; "2"; "4"; "10"; "1D4"; "1D8"; "Light (d4)"; "Medium (d8)"; "scales" ])
    ~f:parse
;;

let quickcheck_observer =
  Base_quickcheck.Observer.unmap Base_quickcheck.Observer.string ~f:(fun t -> t.text)
;;

let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
