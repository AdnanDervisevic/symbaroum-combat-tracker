open! Core

include Bounded_int.Make (struct
    let module_name = "Symbaroum.Defense"
    let min_value = 1
    let max_value = 20
  end)

let of_target = of_int
let to_modifier t = 10 - to_int t
let of_modifier m = of_int (10 - m)
let of_quick quick = of_int_exn (Attribute_value.to_int quick)
