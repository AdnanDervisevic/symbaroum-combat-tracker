open! Core

type t =
  | No_toughness
  | Defense_derived_from_quick of int option
  | Armor_unparsed of string
  | Damage_die_estimated of Resistance.t
  | No_attack_profile
[@@deriving compare, equal, sexp_of]

let to_string_hum = function
  | No_toughness -> "No toughness recorded, so this creature cannot be modelled."
  | Defense_derived_from_quick None -> "No defence recorded; derived from Quick."
  | Defense_derived_from_quick (Some stored) ->
    [%string
      "Recorded defence %{stored#Int} is not a legal modifier; derived from Quick \
       instead."]
  | Armor_unparsed text -> [%string "Armour %{text} could not be read; treated as none."]
  | Damage_die_estimated resistance ->
    [%string
      "No weapon recorded; damage estimated from the %{resistance#Resistance} band."]
  | No_attack_profile ->
    "No weapon recorded for this combatant; an average attack was assumed."
;;

let quickcheck_generator =
  Base_quickcheck.Generator.union
    [ Base_quickcheck.Generator.return No_toughness
    ; Base_quickcheck.Generator.map [%quickcheck.generator: int option] ~f:(fun stored ->
        Defense_derived_from_quick stored)
    ; Base_quickcheck.Generator.map [%quickcheck.generator: string] ~f:(fun text ->
        Armor_unparsed text)
    ; Base_quickcheck.Generator.map [%quickcheck.generator: Resistance.t] ~f:(fun r ->
        Damage_die_estimated r)
    ; Base_quickcheck.Generator.return No_attack_profile
    ]
;;

let quickcheck_observer = Base_quickcheck.Observer.opaque
let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
