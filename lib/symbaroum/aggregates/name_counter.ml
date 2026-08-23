open! Core

type t = int Monster_type.Map.t [@@deriving compare, equal, sexp_of]

let empty = Monster_type.Map.empty
let anonymous = Monster_type.of_string "NPC"
let peek t monster_type = Option.value (Map.find t monster_type) ~default:0

let reserve t monster_type n =
  Map.update t monster_type ~f:(fun cur -> Int.max (Option.value cur ~default:0) n)
;;

let next t monster_type =
  let n = peek t monster_type + 1 in
  reserve t monster_type n, n
;;

let next_n t monster_type count =
  let start = peek t monster_type in
  let numbers = List.init (Int.max 0 count) ~f:(fun i -> start + i + 1) in
  ( (match List.last numbers with
     | None -> t
     | Some last -> reserve t monster_type last)
  , numbers )
;;

let to_alist t = Map.to_alist t

(* ["Goblin 7"] under monster type ["Goblin"] is a 7. Anything else -- a
   hand-typed name, or a name belonging to a different type -- is not a number
   and contributes only to the count. *)
let suffix ~monster_type name =
  let prefix = Monster_type.to_string monster_type ^ " " in
  let%bind.Option rest = String.chop_prefix (Name.to_string name) ~prefix in
  Int.of_string_opt (String.strip rest)
;;

let rebuild_from named =
  let counts =
    List.fold named ~init:Monster_type.Map.empty ~f:(fun acc (monster_type, _) ->
      Map.update acc monster_type ~f:(fun n -> Option.value n ~default:0 + 1))
  in
  let t =
    List.fold named ~init:counts ~f:(fun acc (monster_type, name) ->
      match suffix ~monster_type name with
      | None -> acc
      | Some n -> reserve acc monster_type n)
  in
  let normalizations =
    if Map.is_empty t
    then []
    else
      [ Normalization.Name_counter_rebuilt
          { highest =
              List.map (Map.to_alist t) ~f:(fun (monster_type, n) ->
                Monster_type.to_string monster_type, n)
          }
      ]
  in
  t, normalizations
;;
