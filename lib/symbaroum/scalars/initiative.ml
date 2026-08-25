open! Core

include Bounded_int.Make (struct
    let module_name = "Symbaroum.Initiative"
    let min_value = 0
    let max_value = 99
  end)

let zero = of_int_exn 0
