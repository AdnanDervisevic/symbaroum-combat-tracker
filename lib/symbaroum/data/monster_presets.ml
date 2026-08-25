open! Core

let all =
  List.map Monster_presets_data.raw ~f:(fun raw ->
    Or_error.tag_s
      (Monster_preset.of_raw raw)
      ~tag:[%message "while normalizing a shipped preset" ~name:(raw.name : string)]
    |> Or_error.ok_exn)
;;

let by_name = Monster_type.Map.of_alist_exn (List.map all ~f:(fun p -> p.name, p))
let find name = Map.find by_name name

let by_category =
  List.map all ~f:(fun p -> p.category, p)
  |> Monster_preset.Category.Map.of_alist_multi
  |> Map.map ~f:List.rev
  |> Map.to_alist
;;
