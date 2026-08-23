open! Core

type t =
  | No_threshold
  | Every_hit
  | At_least of int
[@@deriving compare, equal, hash, sexp_of]

let no_threshold = No_threshold
let every_hit = Every_hit
let at_least n = if n <= 0 then Every_hit else At_least n

let of_int_option = function
  | None -> No_threshold
  | Some n -> at_least n
;;

let to_int_option = function
  | No_threshold -> None
  | Every_hit -> Some 0
  | At_least n -> Some n
;;

(* [damage] is post-armour, pre-clamp; see the interface. *)
let is_exceeded t ~damage =
  match t with
  | No_threshold -> false
  | Every_hit -> damage > 0
  | At_least n -> damage >= n
;;

let quickcheck_generator =
  Base_quickcheck.Generator.union
    [ Base_quickcheck.Generator.return No_threshold
    ; Base_quickcheck.Generator.return Every_hit
    ; Base_quickcheck.Generator.map
        (Base_quickcheck.Generator.int_inclusive 1 12)
        ~f:at_least
    ]
;;

let quickcheck_observer =
  Base_quickcheck.Observer.unmap [%quickcheck.observer: int option] ~f:to_int_option
;;

let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
