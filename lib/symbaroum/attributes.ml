open! Core

(* The key-total invariant -- [Map.keys t = Attribute.all] -- is maintained by
   construction: [empty] starts total and [set] only replaces existing keys.
   The type is abstract rather than [private] precisely so that [Map.remove]
   cannot be reached from outside and break it. *)
type t = Attribute_value.t option Attribute.Map.t [@@deriving compare, equal, sexp_of]

let empty =
  Attribute.Map.of_key_set (Attribute.Set.of_list Attribute.all) ~f:(fun _ -> None)
;;

let find t attribute = Map.find_exn t attribute
let set t attribute value = Map.set t ~key:attribute ~data:value
let to_alist t = Map.to_alist t

let to_known_alist t =
  List.filter_map (to_alist t) ~f:(fun (k, v) -> Option.map v ~f:(fun v -> k, v))
;;

let to_map t = t
let count_known t = List.length (to_known_alist t)
let is_empty t = count_known t = 0

let of_alist alist =
  match Attribute.Map.of_alist alist with
  | `Duplicate_key key ->
    Or_error.error_s
      [%message "Attributes.of_alist: duplicate attribute" (key : Attribute.t)]
  | `Ok given -> Ok (Map.fold given ~init:empty ~f:(fun ~key ~data t -> set t key data))
;;

let quickcheck_generator =
  let open Base_quickcheck.Generator.Let_syntax in
  let%map values =
    Base_quickcheck.Generator.list_with_length
      ~length:(List.length Attribute.all)
      (Base_quickcheck.Generator.option [%quickcheck.generator: Attribute_value.t])
  in
  List.fold2_exn Attribute.all values ~init:empty ~f:(fun t key data -> set t key data)
;;

let quickcheck_observer =
  Base_quickcheck.Observer.unmap
    [%quickcheck.observer: Attribute_value.t option list]
    ~f:(fun t -> List.map (to_alist t) ~f:snd)
;;

let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
