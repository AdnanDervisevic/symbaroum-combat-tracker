(** Past, present and future.

    The two React bugs this type is shaped around have their own rows in
    [test_bug_ledger.ml] -- the unbounded [redo] and the reference-identity
    deduplication. What is here is the rest of the contract: what a push does to
    the future, what coalescing does and does not collapse, and what survives
    being written to disk. *)

open! Core
open! Symbaroum
open Expect_test_helpers_core

let equal = Int.equal

let show t =
  printf
    "present %d   past %d   future %d   (undo %b, redo %b)\n"
    (Undo_history.present t)
    (Undo_history.depth t)
    (Undo_history.future_depth t)
    (Undo_history.can_undo t)
    (Undo_history.can_redo t)
;;

let push ?key t n = Undo_history.push t n ~equal ~key

let%expect_test "a fresh history has nowhere to go" =
  show (Undo_history.create 0);
  printf "default capacity %d\n" Undo_history.default_capacity;
  [%expect
    {|
    present 0   past 0   future 0   (undo false, redo false)
    default capacity 50 |}]
;;

let%expect_test "push, undo, redo" =
  let t = push (push (push (Undo_history.create 0) 1) 2) 3 in
  show t;
  let t = Option.value_exn (Undo_history.undo t) in
  show t;
  let t = Option.value_exn (Undo_history.undo t) in
  show t;
  let t = Option.value_exn (Undo_history.redo t) in
  show t;
  [%expect
    {|
    present 3   past 3   future 0   (undo true, redo false)
    present 2   past 2   future 1   (undo true, redo true)
    present 1   past 1   future 2   (undo true, redo true)
    present 2   past 2   future 1   (undo true, redo true) |}]
;;

(* The React hook means to do this and cannot, because its comparison is
   [newPresent === prev.present] against a freshly built object literal. A
   structural [equal] makes "nothing changed" cost nothing -- not an entry, and
   not the redo stack, which is the part that would be rude. *)
let%expect_test "pushing the value already present does nothing at all" =
  let t = push (push (Undo_history.create 0) 1) 2 in
  let t = Option.value_exn (Undo_history.undo t) in
  show t;
  show (push t 1);
  [%expect
    {|
    present 1   past 1   future 1   (undo true, redo true)
    present 1   past 1   future 1   (undo true, redo true) |}]
;;

let%expect_test "a push after an undo abandons the future" =
  let t = push (push (Undo_history.create 0) 1) 2 in
  let t = Option.value_exn (Undo_history.undo t) in
  show t;
  show (push t 99);
  [%expect
    {|
    present 1   past 1   future 1   (undo true, redo true)
    present 99   past 2   future 0   (undo true, redo false) |}]
;;

(* Coalescing is keyed by field, not merely by "the last thing was also an
   edit": a run of keystrokes in a note is one entry, and moving to a different
   field starts the next one. *)
let%expect_test "same key coalesces, a different key does not" =
  let t = Undo_history.create 0 in
  let t = push t 1 ~key:"note" in
  let t = push t 2 ~key:"note" in
  let t = push t 3 ~key:"note" in
  show t;
  let t = push t 4 ~key:"initiative" in
  show t;
  let t = push t 5 in
  show t;
  (* One undo per key, so the whole run of note edits comes back together. *)
  let t = Option.value_exn (Undo_history.undo t) in
  show t;
  let t = Option.value_exn (Undo_history.undo t) in
  show t;
  [%expect
    {|
    present 3   past 1   future 0   (undo true, redo false)
    present 4   past 2   future 0   (undo true, redo false)
    present 5   past 3   future 0   (undo true, redo false)
    present 4   past 2   future 1   (undo true, redo true)
    present 3   past 1   future 2   (undo true, redo true) |}]
;;

let%expect_test "the oldest entry falls off the end" =
  let t =
    List.fold (List.range 1 8) ~init:(Undo_history.create ~capacity:3 0) ~f:(fun t n ->
      push t n)
  in
  show t;
  let rec drain t acc =
    match Undo_history.undo t with
    | None -> List.rev (Undo_history.present t :: acc)
    | Some t' -> drain t' (Undo_history.present t :: acc)
  in
  print_s [%sexp (drain t [] : int list)];
  [%expect
    {|
    present 7   past 3   future 0   (undo true, redo false)
    (7 6 5 4) |}]
;;

(* The future is deliberately dropped on the way to disk. A redo stack that
   survives a reload is a promise the app cannot keep: the state it would redo
   into was never saved. *)
let%expect_test "persistence keeps the present and a truncated past, and no future" =
  let t =
    List.fold (List.range 1 8) ~init:(Undo_history.create 0) ~f:(fun t n -> push t n)
  in
  let t = Option.value_exn (Undo_history.undo t) in
  let present, past = Undo_history.to_persistable t ~keep_past:3 in
  print_s [%message "" (present : int) (past : int list)];
  show (Undo_history.of_persisted present ~past);
  [%expect
    {|
    ((present 6) (past (5 4 3)))
    present 6   past 3   future 0   (undo true, redo false) |}]
;;

let%expect_test "map rewrites every entry, which is what a migration needs" =
  let t = push (push (Undo_history.create 0) 1) 2 in
  let t = Undo_history.map t ~f:(fun n -> n * 10) in
  let present, past = Undo_history.to_persistable t ~keep_past:10 in
  print_s [%message "" (present : int) (past : int list)];
  [%expect {| ((present 20) (past (10 0))) |}]
;;

(* The properties. A step is generated rather than a value, so the sequences
   quickcheck explores are the interleavings that actually break things. *)
module Step = struct
  (* Three keys rather than an arbitrary string, so that generated runs actually
     coalesce. With free strings the same key twice in a row essentially never
     happens, and the coalescing path would go untested while looking tested. *)
  module Key = struct
    type t =
      | Unkeyed
      | Note
      | Initiative
    [@@deriving quickcheck, sexp_of]

    let to_key = function
      | Unkeyed -> None
      | Note -> Some "note"
      | Initiative -> Some "initiative"
    ;;
  end

  type t =
    | Push of int * Key.t
    | Undo
    | Redo
  [@@deriving quickcheck, sexp_of]
end

module Script = struct
  type t = Step.t list [@@deriving quickcheck, sexp_of]

  let run ?capacity t =
    List.fold t ~init:(Undo_history.create ?capacity 0) ~f:(fun history step ->
      match (step : Step.t) with
      | Push (n, key) -> Undo_history.push history n ~equal ~key:(Step.Key.to_key key)
      | Undo -> Option.value (Undo_history.undo history) ~default:history
      | Redo -> Option.value (Undo_history.redo history) ~default:history)
  ;;
end

let%test_unit "the past never outgrows the capacity, whatever the sequence" =
  Base_quickcheck.Test.run_exn
    (module Script)
    ~f:(fun script ->
      let history = Script.run script ~capacity:5 in
      [%test_pred: int] (fun depth -> depth <= 5) (Undo_history.depth history))
;;

let%test_unit "redo undoes undo" =
  Base_quickcheck.Test.run_exn
    (module Script)
    ~f:(fun script ->
      let history = Script.run script in
      match Undo_history.undo history with
      | None -> ()
      | Some undone ->
        let redone = Option.value_exn (Undo_history.redo undone) in
        [%test_result: int]
          (Undo_history.present redone)
          ~expect:(Undo_history.present history);
        [%test_result: int]
          (Undo_history.depth redone)
          ~expect:(Undo_history.depth history))
;;

(* Stated as its own property because it is the one an interface can get subtly
   wrong: [can_undo] must agree with [undo], or the UI greys out a button that
   would have worked. *)
let%test_unit "can_undo and can_redo agree with undo and redo" =
  Base_quickcheck.Test.run_exn
    (module Script)
    ~f:(fun script ->
      let history = Script.run script ~capacity:4 in
      [%test_result: bool]
        (Undo_history.can_undo history)
        ~expect:(Option.is_some (Undo_history.undo history));
      [%test_result: bool]
        (Undo_history.can_redo history)
        ~expect:(Option.is_some (Undo_history.redo history)))
;;

let%test_unit "an uncoalesced push is undone exactly by one undo" =
  Base_quickcheck.Test.run_exn
    (module struct
      type t = Script.t * int [@@deriving quickcheck, sexp_of]
    end)
    ~f:(fun (script, n) ->
      let history = Script.run script in
      let pushed = Undo_history.push history n ~equal ~key:None in
      if not (equal n (Undo_history.present history))
      then (
        let undone = Option.value_exn (Undo_history.undo pushed) in
        [%test_result: int]
          (Undo_history.present undone)
          ~expect:(Undo_history.present history))
      else
        (* Pushing the present is a no-op, so there is nothing to undo back to. *)
        [%test_result: int]
          (Undo_history.depth pushed)
          ~expect:(Undo_history.depth history))
;;
