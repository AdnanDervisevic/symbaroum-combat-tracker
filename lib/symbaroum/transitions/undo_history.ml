open! Core

(* [past] is newest-at-the-back, so a push is [enqueue_back] and an undo is
   [dequeue_back]; dropping the oldest is [dequeue_front]. All three are O(1)
   amortised on [Fdeque], which is what a list cannot give at both ends. *)
type 'a t =
  { past : 'a Fdeque.t
  ; present : 'a
  ; future : 'a Fdeque.t
  ; capacity : int
  ; last_key : string option
  }
[@@deriving compare, equal, sexp_of]

let default_capacity = 50

let create ?(capacity = default_capacity) present =
  { past = Fdeque.empty
  ; present
  ; future = Fdeque.empty
  ; capacity = Int.max 1 capacity
  ; last_key = None
  }
;;

let present t = t.present
let capacity t = t.capacity
let depth t = Fdeque.length t.past
let future_depth t = Fdeque.length t.future
let can_undo t = not (Fdeque.is_empty t.past)
let can_redo t = not (Fdeque.is_empty t.future)

(* The one place the bound is applied, so [redo] cannot skip it the way the
   React hook does. *)
let trim t =
  let rec go past =
    if Fdeque.length past > t.capacity then go (Fdeque.drop_front_exn past) else past
  in
  { t with past = go t.past }
;;

let push t next ~equal ~key =
  if equal next t.present
  then t
  else (
    let coalesces =
      match key, t.last_key with
      | Some key, Some last -> String.equal key last
      | _, _ -> false
    in
    if coalesces
    then { t with present = next; future = Fdeque.empty }
    else
      trim
        { t with
          past = Fdeque.enqueue_back t.past t.present
        ; present = next
        ; future = Fdeque.empty
        ; last_key = key
        })
;;

let undo t =
  let%map.Option previous, past = Fdeque.dequeue_back t.past in
  { t with
    past
  ; present = previous
  ; future = Fdeque.enqueue_front t.future t.present
  ; last_key = None
  }
;;

let redo t =
  if not (can_redo t)
  then None
  else (
    let next, future = Fdeque.dequeue_front_exn t.future in
    Some
      (trim
         { t with
           past = Fdeque.enqueue_back t.past t.present
         ; present = next
         ; future
         ; last_key = None
         }))
;;

let to_persistable t ~keep_past =
  let past = Fdeque.to_list t.past in
  ( t.present
  , List.rev (List.drop past (Int.max 0 (List.length past - Int.max 0 keep_past))) )
;;

let of_persisted ?capacity present ~past =
  let t = create ?capacity present in
  trim { t with past = Fdeque.of_list (List.rev past) }
;;

let map t ~f =
  { past = Fdeque.map t.past ~f
  ; present = f t.present
  ; future = Fdeque.map t.future ~f
  ; capacity = t.capacity
  ; last_key = t.last_key
  }
;;
