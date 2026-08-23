open! Core

include Bounded_int.Make (struct
    let module_name = "Symbaroum.Attribute_value"
    let min_value = 1
    let max_value = 20
  end)

let modifier t = 10 - to_int t
