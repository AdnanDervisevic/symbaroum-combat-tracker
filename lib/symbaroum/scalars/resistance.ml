open! Core

module T = struct
  type t =
    | Weak
    | Ordinary
    | Challenging
    | Strong
    | Mighty
    | Legendary
  [@@deriving compare, enumerate, hash, sexp, quickcheck]

  let to_string = function
    | Weak -> "Weak"
    | Ordinary -> "Ordinary"
    | Challenging -> "Challenging"
    | Strong -> "Strong"
    | Mighty -> "Mighty"
    | Legendary -> "Legendary"
  ;;

  let of_string s =
    match List.find all ~f:(fun t -> String.Caseless.equal (to_string t) s) with
    | Some t -> t
    | None -> raise_s [%message "Resistance.of_string: unknown band" (s : string)]
  ;;

  let module_name = "Symbaroum.Resistance"
end

include T
include Identifiable.Make_plain (T)
