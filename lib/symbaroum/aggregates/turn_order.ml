open! Core

type 'a t =
  { before : 'a list
  ; current : 'a
  ; after : 'a list
  }
[@@deriving compare, equal, sexp_of]

let singleton current = { before = []; current; after = [] }
let to_list t = List.rev_append t.before (t.current :: t.after)
let current t = t.current
let length t = List.length t.before + 1 + List.length t.after
let index t = List.length t.before

let map t ~f =
  { before = List.map t.before ~f; current = f t.current; after = List.map t.after ~f }
;;

let exists t ~f = List.exists (to_list t) ~f

(* Everything below is easier to say as "a list plus an index" than as three
   fields, so it is said that way once, here, and converted back. *)
let of_list_index items index =
  match List.split_n items index with
  | _, [] -> None
  | before, current :: after -> Some { before = List.rev before; current; after }
;;

let of_list items = of_list_index items 0

let of_list_with_focus items ~focus =
  if List.is_empty items
  then None
  else (
    let used = Int.clamp_exn focus ~min:0 ~max:(List.length items - 1) in
    let normalizations =
      if used = focus
      then []
      else [ Normalization.Turn_index_clamped { given = focus; used } ]
    in
    Option.map (of_list_index items used) ~f:(fun t -> t, normalizations))
;;

let next t =
  match t.after with
  | x :: rest ->
    { before = t.current :: t.before; current = x; after = rest }, `Same_round
  | [] ->
    (match List.rev (t.current :: t.before) with
     | [] -> assert false
     | current :: after -> { before = []; current; after }, `Wrapped)
;;

let prev t =
  match t.before with
  | x :: rest -> { before = rest; current = x; after = t.current :: t.after }, `Same_round
  | [] ->
    (match List.rev (t.current :: t.after) with
     | [] -> assert false
     | current :: before -> { before; current; after = [] }, `Wrapped)
;;

let focus t ~f =
  let items = to_list t in
  match List.findi items ~f:(fun _ x -> f x) with
  | None -> t
  | Some (i, _) -> Option.value_exn (of_list_index items i)
;;

let remove t ~f =
  let items = to_list t in
  match List.findi items ~f:(fun _ x -> f x) with
  | None -> Some t
  | Some (removed, _) ->
    let items = List.filteri items ~f:(fun i _ -> i <> removed) in
    if List.is_empty items
    then None
    else (
      let index = index t in
      (* Removing something before the cursor shifts it; removing the cursor
         itself leaves the index pointing at whoever moved into the slot, which
         is the next combatant -- or the new last, if there was no next. *)
      let index = if removed < index then index - 1 else index in
      of_list_index items (Int.min index (List.length items - 1)))
;;

let move t ~f direction =
  let items = to_list t in
  match List.findi items ~f:(fun _ x -> f x) with
  | None -> t
  | Some (from, item) ->
    let target =
      match direction with
      | `Up -> from - 1
      | `Down -> from + 1
    in
    if target < 0 || target >= List.length items
    then t
    else (
      let without = List.filteri items ~f:(fun i _ -> i <> from) in
      let before, after = List.split_n without target in
      let items = before @ (item :: after) in
      (* Follow the element under the cursor, not its index. Working it out
         arithmetically rather than by searching for the element keeps this
         correct when two entries compare equal. *)
      let cursor = index t in
      let cursor =
        if cursor = from
        then target
        else (
          let removed = if cursor > from then cursor - 1 else cursor in
          if removed >= target then removed + 1 else removed)
      in
      Option.value_exn (of_list_index items cursor))
;;

let add_last t item = { t with after = t.after @ [ item ] }

let sort_by t ~compare =
  (* [List.stable_sort], and the cursor to the front, exactly as
     [sortByInitiative] does. What it cannot do -- because the round is not in
     this type -- is reset the round. *)
  Option.value_exn (of_list (List.stable_sort (to_list t) ~compare))
;;
