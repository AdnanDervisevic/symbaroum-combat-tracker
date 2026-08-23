open! Core

module type S = sig
  type t = private int [@@deriving compare, equal, hash, sexp_of, quickcheck]

  val min_value : int
  val max_value : int
  val of_int : int -> t Or_error.t
  val of_int_exn : int -> t
  val of_int_clamped : int -> t
  val to_int : t -> int
end

module type Arg = sig
  val module_name : string
  val min_value : int
  val max_value : int
end

module Make (Arg : Arg) = struct
  type t = int [@@deriving compare, equal, hash, sexp_of]

  let min_value = Arg.min_value
  let max_value = Arg.max_value
  let to_int t = t

  let of_int n =
    if n >= min_value && n <= max_value
    then Ok n
    else
      Or_error.error_s
        [%message
          "value out of range"
            ~module_:(Arg.module_name : string)
            ~value:(n : int)
            (min_value : int)
            (max_value : int)]
  ;;

  let of_int_exn n = Or_error.ok_exn (of_int n)
  let of_int_clamped n = Int.clamp_exn n ~min:min_value ~max:max_value

  (* Routed through the smart constructor, so no generator can produce a value
     that the constructor would have rejected. Every generator in this library
     is built this way. *)
  let quickcheck_generator =
    Base_quickcheck.Generator.map
      (Base_quickcheck.Generator.int_inclusive min_value max_value)
      ~f:of_int_exn
  ;;

  let quickcheck_observer =
    Base_quickcheck.Observer.unmap Base_quickcheck.Observer.int ~f:to_int
  ;;

  let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
end
