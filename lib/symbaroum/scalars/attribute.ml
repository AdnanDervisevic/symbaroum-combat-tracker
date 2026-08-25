open! Core

module T = struct
  type t =
    | Accurate
    | Cunning
    | Discreet
    | Persuasive
    | Quick
    | Resolute
    | Strong
    | Vigilant
  [@@deriving compare, enumerate, hash, sexp, quickcheck]

  let to_key = function
    | Accurate -> "acc"
    | Cunning -> "cun"
    | Discreet -> "dis"
    | Persuasive -> "per"
    | Quick -> "qui"
    | Resolute -> "res"
    | Strong -> "str"
    | Vigilant -> "vig"
  ;;

  let of_key key = List.find all ~f:(fun t -> String.equal (to_key t) key)
  let to_string = to_key

  let of_string key =
    match of_key key with
    | Some t -> t
    | None ->
      raise_s [%message "Attribute.of_string: unknown attribute key" (key : string)]
  ;;

  let module_name = "Symbaroum.Attribute"
end

include T
include Identifiable.Make_plain (T)

let to_label t = String.uppercase (to_key t)
