open! Core

module Entry = struct
  type t =
    { id : Ids.Bestiary_id.t
    ; monster_type : Monster_type.t
    ; initiative : Initiative.t
    ; toughness : Toughness.t
    ; defense : Defense.t
    ; armor : Armor.t
    ; pain_threshold : Pain_threshold.t
    ; attributes : Attributes.t
    ; attack : Attack_profile.t option
    ; note : string
    ; updated_at : Time_ns.Alternate_sexp.t
    }
  [@@deriving compare, equal, fields ~getters, sexp_of]
end

type t =
  { by_type : Entry.t Monster_type.Map.t
  ; order : Monster_type.t list
  }
[@@deriving compare, equal, sexp_of]

let empty = { by_type = Monster_type.Map.empty; order = [] }

let upsert t (entry : Entry.t) =
  let existing = Map.find t.by_type entry.monster_type in
  let entry =
    match existing with
    | None -> entry
    | Some existing -> { entry with id = existing.id }
  in
  { by_type = Map.set t.by_type ~key:entry.monster_type ~data:entry
  ; order =
      (if Option.is_some existing then t.order else t.order @ [ entry.monster_type ])
  }
;;

let of_list entries = List.fold entries ~init:empty ~f:upsert
let to_list t = List.map t.order ~f:(fun key -> Map.find_exn t.by_type key)
let find t monster_type = Map.find t.by_type monster_type
let find_by_id t id = List.find (to_list t) ~f:(fun e -> Ids.Bestiary_id.equal e.id id)
let length t = Map.length t.by_type

let remove t id =
  match find_by_id t id with
  | None -> t
  | Some entry ->
    { by_type = Map.remove t.by_type entry.monster_type
    ; order =
        List.filter t.order ~f:(fun key ->
          not (Monster_type.equal key entry.monster_type))
    }
;;
