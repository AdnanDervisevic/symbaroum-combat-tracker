open! Core

module Source = struct
  type t =
    | From_data
    | Estimated_from_resistance of Resistance.t
  [@@deriving compare, equal, sexp_of]

  let is_estimated = function
    | From_data -> false
    | Estimated_from_resistance _ -> true
  ;;

  let quickcheck_generator =
    Base_quickcheck.Generator.union
      [ Base_quickcheck.Generator.return From_data
      ; Base_quickcheck.Generator.map [%quickcheck.generator: Resistance.t] ~f:(fun r ->
          Estimated_from_resistance r)
      ]
  ;;

  let quickcheck_observer = Base_quickcheck.Observer.opaque
  let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
end

type t =
  { accurate : Attribute_value.t
  ; damage : Dice.t
  ; source : Source.t
  }
[@@deriving compare, equal, sexp_of]

let create ~accurate ~damage ~source = { accurate; damage; source }

let damage_prior : Resistance.t -> Dice.t = function
  | Weak -> Dice.d 6
  | Ordinary -> Dice.d 8
  | Challenging -> Dice.d 10
  | Strong -> Dice.d 12
  | Mighty -> Dice.create_exn ~count:1 ~sides:12 ~modifier:1
  | Legendary -> Dice.create_exn ~count:1 ~sides:12 ~modifier:2
;;

let estimate ~accurate ~resistance =
  create
    ~accurate
    ~damage:(damage_prior resistance)
    ~source:(Estimated_from_resistance resistance)
;;

let quickcheck_generator =
  let open Base_quickcheck.Generator.Let_syntax in
  let%bind accurate = [%quickcheck.generator: Attribute_value.t] in
  let%bind damage = [%quickcheck.generator: Dice.t] in
  let%map source = [%quickcheck.generator: Source.t] in
  create ~accurate ~damage ~source
;;

let quickcheck_observer = Base_quickcheck.Observer.opaque
let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
