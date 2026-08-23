open! Core

include Bounded_int.Make (struct
    let module_name = "Symbaroum.Npc_count"
    let min_value = 1
    let max_value = 20
  end)
