open! Core

type t = int [@@deriving compare, equal, hash, sexp_of]

let first = 1
let to_int t = t

let of_int n =
  if n >= first
  then Ok n
  else Or_error.error_s [%message "Round.of_int: rounds start at 1" ~round:(n : int)]
;;

let of_int_exn n = Or_error.ok_exn (of_int n)
let of_int_clamped n = Int.max first n
let succ t = t + 1
let prev t = Int.max first (t - 1)

let quickcheck_generator =
  Base_quickcheck.Generator.map
    (Base_quickcheck.Generator.int_inclusive first 40)
    ~f:of_int_exn
;;

let quickcheck_observer =
  Base_quickcheck.Observer.unmap Base_quickcheck.Observer.int ~f:to_int
;;

let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
