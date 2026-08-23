open! Core

type t =
  { current : int
  ; max : int
  }
[@@deriving compare, equal, hash, sexp_of]

let min_max = 1
let max_max = 999

let create ~current ~max =
  if max < min_max || max > max_max
  then
    Or_error.error_s
      [%message
        "Toughness.create: maximum out of range"
          (max : int)
          (min_max : int)
          (max_max : int)]
  else if current < 0 || current > max
  then
    Or_error.error_s
      [%message "Toughness.create: current outside 0 .. max" (current : int) (max : int)]
  else Ok { current; max }
;;

let create_exn ~current ~max = Or_error.ok_exn (create ~current ~max)

let create_clamped ~current ~max =
  let max = Int.clamp_exn max ~min:min_max ~max:max_max in
  { current = Int.clamp_exn current ~min:0 ~max; max }
;;

let full max = create ~current:max ~max
let is_down t = t.current = 0

let damage t n =
  let taken = Int.clamp_exn n ~min:0 ~max:t.current in
  { t with current = t.current - taken }, taken
;;

let heal t n =
  let restored = Int.clamp_exn n ~min:0 ~max:(t.max - t.current) in
  { t with current = t.current + restored }, restored
;;

let with_max t max = create ~current:(Int.min t.current max) ~max

let quickcheck_generator =
  let open Base_quickcheck.Generator.Let_syntax in
  let%bind max = Base_quickcheck.Generator.int_inclusive min_max 30 in
  let%map current = Base_quickcheck.Generator.int_inclusive 0 max in
  create_exn ~current ~max
;;

let quickcheck_observer =
  Base_quickcheck.Observer.unmap
    [%quickcheck.observer: int * int]
    ~f:(fun { current; max } -> current, max)
;;

let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
