open! Core

include Bounded_int.Make (struct
    let module_name = "Symbaroum.Adjust_amount"
    let min_value = 1
    let max_value = 999
  end)
