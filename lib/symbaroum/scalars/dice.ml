open! Core

type t =
  { count : int
  ; sides : int
  ; modifier : int
  }
[@@deriving compare, equal, hash, sexp_of, fields ~getters]

let min_count = 1
let max_count = 20
let min_sides = 2
let max_sides = 100
let max_abs_modifier = 100

let create ~count ~sides ~modifier =
  let check name value ~min ~max =
    if value >= min && value <= max
    then Ok ()
    else
      Or_error.error_s
        [%message
          "Dice.create: out of range"
            ~field:(name : string)
            (value : int)
            (min : int)
            (max : int)]
  in
  let%map.Or_error () = check "count" count ~min:min_count ~max:max_count
  and () = check "sides" sides ~min:min_sides ~max:max_sides
  and () = check "modifier" modifier ~min:(-max_abs_modifier) ~max:max_abs_modifier in
  { count; sides; modifier }
;;

let create_exn ~count ~sides ~modifier = Or_error.ok_exn (create ~count ~sides ~modifier)
let d sides = create_exn ~count:1 ~sides ~modifier:0

let parse s =
  let s = String.filter (String.lowercase s) ~f:(fun c -> not (Char.is_whitespace c)) in
  match String.lsplit2 s ~on:'d' with
  | None -> None
  | Some (before, after) ->
    let count = if String.is_empty before then Some 1 else Int.of_string_opt before in
    let sides, modifier =
      match String.lsplit2 after ~on:'+' with
      | Some (sides, modifier) -> Int.of_string_opt sides, Int.of_string_opt modifier
      | None ->
        (match String.lsplit2 after ~on:'-' with
         | Some (sides, modifier) ->
           Int.of_string_opt sides, Option.map (Int.of_string_opt modifier) ~f:Int.neg
         | None -> Int.of_string_opt after, Some 0)
    in
    let%bind.Option count = count in
    let%bind.Option sides = sides in
    let%bind.Option modifier = modifier in
    create ~count ~sides ~modifier |> Or_error.ok
;;

let to_string { count; sides; modifier } =
  let base = [%string "%{count#Int}d%{sides#Int}"] in
  if modifier = 0
  then base
  else if modifier > 0
  then [%string "%{base}+%{modifier#Int}"]
  else [%string "%{base}-%{(-modifier)#Int}"]
;;

let min_roll { count; sides = _; modifier } = count + modifier
let max_roll { count; sides; modifier } = (count * sides) + modifier

let mean { count; sides; modifier } =
  (Float.of_int count *. (Float.of_int sides +. 1.) /. 2.) +. Float.of_int modifier
;;

(* Convolution: fold one die at a time over the running distribution. The
   support is tiny (at most [count * sides] values), so the quadratic cost is
   irrelevant and the result is exact. *)
let distribution { count; sides; modifier } =
  let single = Array.create ~len:sides (1. /. Float.of_int sides) in
  let combined =
    Fn.apply_n_times
      ~n:(count - 1)
      (fun acc ->
         let result = Array.create ~len:(Array.length acc + sides - 1) 0. in
         Array.iteri acc ~f:(fun i p ->
           Array.iteri single ~f:(fun j q -> result.(i + j) <- result.(i + j) +. (p *. q)));
         result)
      single
  in
  Array.to_list combined |> List.mapi ~f:(fun i p -> i + count + modifier, p)
;;

let roll { count; sides; modifier } random =
  let rec go n acc =
    if n = 0 then acc else go (n - 1) (acc + Splittable_random.int random ~lo:1 ~hi:sides)
  in
  go count modifier
;;

(* Only shapes that appear in, or could plausibly be typed into, the app. *)
let quickcheck_generator =
  let open Base_quickcheck.Generator.Let_syntax in
  let%bind count = Base_quickcheck.Generator.int_inclusive 1 3 in
  let%bind sides = Base_quickcheck.Generator.of_list [ 4; 6; 8; 10; 12; 20 ] in
  let%map modifier = Base_quickcheck.Generator.int_inclusive (-3) 3 in
  create_exn ~count ~sides ~modifier
;;

let quickcheck_observer =
  Base_quickcheck.Observer.unmap
    [%quickcheck.observer: int * int * int]
    ~f:(fun { count; sides; modifier } -> count, sides, modifier)
;;

let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
