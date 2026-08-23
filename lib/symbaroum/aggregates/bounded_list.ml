open! Core

type 'a t =
  { capacity : int
  ; items : 'a list
  }
[@@deriving compare, equal, sexp_of]

let create ~capacity = { capacity = Int.max 1 capacity; items = [] }
let truncate t = { t with items = List.take t.items t.capacity }
let of_list ~capacity items = truncate { capacity = Int.max 1 capacity; items }
let add t item = truncate { t with items = item :: t.items }
let to_list t = t.items
let length t = List.length t.items
let is_empty t = List.is_empty t.items
let filter t ~f = { t with items = List.filter t.items ~f }
let find t ~f = List.find t.items ~f
let map t ~f = { capacity = t.capacity; items = List.map t.items ~f }
