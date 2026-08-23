open! Core

type t =
  { by_id : Character.t Ids.Character_id.Map.t
  ; order : Ids.Character_id.t list
  }
[@@deriving compare, equal, sexp_of]

let empty = { by_id = Ids.Character_id.Map.empty; order = [] }

let of_list characters =
  List.fold
    characters
    ~init:(empty, [])
    ~f:(fun (t, normalizations) (character : Character.t) ->
      match Map.add t.by_id ~key:character.id ~data:character with
      | `Ok by_id -> { by_id; order = t.order @ [ character.id ] }, normalizations
      | `Duplicate ->
        ( t
        , normalizations
          @ [ Normalization.Duplicate_character_id
                { id = Ids.Character_id.to_string character.id }
            ] ))
;;

let default = fst (of_list Default_roster.all)
let to_list t = List.map t.order ~f:(fun id -> Map.find_exn t.by_id id)
let find t id = Map.find t.by_id id
let mem t id = Map.mem t.by_id id
let length t = Map.length t.by_id

let add t (character : Character.t) =
  let by_id = Map.set t.by_id ~key:character.id ~data:character in
  let order =
    if Map.mem t.by_id character.id then t.order else t.order @ [ character.id ]
  in
  { by_id; order }
;;

let remove t id =
  { by_id = Map.remove t.by_id id
  ; order = List.filter t.order ~f:(fun other -> not (Ids.Character_id.equal id other))
  }
;;

let update t id ~f =
  match Map.find t.by_id id with
  | None -> t
  | Some character -> { t with by_id = Map.set t.by_id ~key:id ~data:(f character) }
;;
