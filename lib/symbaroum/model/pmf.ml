open! Core

type t = float array [@@deriving compare, equal, sexp_of]

let dirac n =
  let n = Int.max 0 n in
  let t = Array.create ~len:(n + 1) 0. in
  t.(n) <- 1.;
  t
;;

let of_dice dice =
  let outcomes = Dice.distribution dice in
  let largest =
    List.fold outcomes ~init:0 ~f:(fun acc (value, _) -> Int.max acc (Int.max 0 value))
  in
  let t = Array.create ~len:(largest + 1) 0. in
  List.iter outcomes ~f:(fun (value, p) ->
    let value = Int.max 0 value in
    t.(value) <- t.(value) +. p);
  t
;;

let of_reduction : Armor.Reduction.t -> t = function
  | Unarmored -> dirac 0
  | Fixed n -> dirac n
  | Rolled dice -> of_dice dice
;;

let length = Array.length
let prob t value = if value >= 0 && value < Array.length t then t.(value) else 0.
let total t = Array.fold t ~init:0. ~f:( +. )

let mean t =
  Array.foldi t ~init:0. ~f:(fun value acc p -> acc +. (Float.of_int value *. p))
;;

let to_alist t =
  Array.to_list
    (Array.filter_mapi t ~f:(fun value p -> Option.some_if Float.(p > 0.) (value, p)))
;;

let sub_clamped damage armor =
  (* The largest possible result is the largest damage with no armour at all. *)
  let result = Array.create ~len:(Array.length damage) 0. in
  Array.iteri damage ~f:(fun d p_d ->
    if Float.(p_d > 0.)
    then
      Array.iteri armor ~f:(fun a p_a ->
        if Float.(p_a > 0.)
        then (
          let net = Int.max 0 (d - a) in
          result.(net) <- result.(net) +. (p_d *. p_a))));
  result
;;

let probability t ~f =
  Array.foldi t ~init:0. ~f:(fun value acc p -> if f value then acc +. p else acc)
;;

let sample t random =
  let target = Splittable_random.float random ~lo:0. ~hi:1. in
  let rec go value seen =
    if value >= Array.length t - 1
    then Array.length t - 1
    else (
      let seen = seen +. t.(value) in
      if Float.(target < seen) then value else go (value + 1) seen)
  in
  go 0 0.
;;
