open! Core

type t =
  | Empty of { name_counter : Name_counter.t }
  | Active of
      { members : Combatant.t Ids.Combatant_id.Map.t
      ; order : Ids.Combatant_id.t Turn_order.t
      ; round : Round.t
      ; name_counter : Name_counter.t
      }
[@@deriving compare, equal, sexp_of]

let empty = Empty { name_counter = Name_counter.empty }

let invariant t =
  Invariant.invariant [%here] t [%sexp_of: t] (fun () ->
    match t with
    | Empty _ -> ()
    | Active { members; order; round = _; name_counter = _ } ->
      let ordered = Turn_order.to_list order in
      [%test_result: int]
        ~message:"order and members disagree on how many combatants there are"
        (List.length ordered)
        ~expect:(Map.length members);
      [%test_result: bool]
        ~message:"an id appears twice in the turn order"
        (List.contains_dup ordered ~compare:Ids.Combatant_id.compare)
        ~expect:false;
      List.iter ordered ~f:(fun id ->
        [%test_result: bool]
          ~message:"the turn order names a combatant that is not a member"
          (Map.mem members id)
          ~expect:true))
;;

let name_counter = function
  | Empty { name_counter } -> name_counter
  | Active { name_counter; _ } -> name_counter
;;

let set_name_counter t name_counter =
  match t with
  | Empty _ -> Empty { name_counter }
  | Active a -> Active { a with name_counter }
;;

let members = function
  | Empty _ -> []
  | Active { members; order; _ } ->
    List.map (Turn_order.to_list order) ~f:(fun id -> Map.find_exn members id)
;;

let find t id =
  match t with
  | Empty _ -> None
  | Active { members; _ } -> Map.find members id
;;

let mem t id = Option.is_some (find t id)

let length = function
  | Empty _ -> 0
  | Active { members; _ } -> Map.length members
;;

let is_empty = function
  | Empty _ -> true
  | Active _ -> false
;;

let round = function
  | Empty _ -> Round.first
  | Active { round; _ } -> round
;;

let current_id = function
  | Empty _ -> None
  | Active { order; _ } -> Some (Turn_order.current order)
;;

let current t =
  match t with
  | Empty _ -> None
  | Active { members; order; _ } -> Map.find members (Turn_order.current order)
;;

let turn_index = function
  | Empty _ -> None
  | Active { order; _ } -> Some (Turn_order.index order)
;;

(* Rebuild [Active] from an ordered list. [Empty] is the only representation of
   "no combatants", so this is also where an emptied fight loses its round -- and
   it is the only place that can happen. *)
let of_ordered ~ordered ~round ~name_counter =
  match Turn_order.of_list (List.map ordered ~f:(fun (c : Combatant.t) -> c.id)) with
  | None -> Empty { name_counter }
  | Some order ->
    Active
      { members =
          Ids.Combatant_id.Map.of_alist_exn
            (List.map ordered ~f:(fun (c : Combatant.t) -> c.id, c))
      ; order
      ; round
      ; name_counter
      }
;;

(* A combatant whose id is taken keeps its place in the fight and gets a derived
   id, rather than being dropped. Deterministic, so the repair is reproducible
   and the codec round-trip stays stable. *)
let dedupe members =
  let rec fresh taken id n =
    let candidate =
      Ids.Combatant_id.of_string [%string "%{id#Ids.Combatant_id}-%{n#Int}"]
    in
    if Set.mem taken candidate then fresh taken id (n + 1) else candidate
  in
  let members, _, normalizations =
    List.fold
      members
      ~init:([], Ids.Combatant_id.Set.empty, [])
      ~f:(fun (acc, taken, normalizations) (member : Combatant.t) ->
        if not (Set.mem taken member.id)
        then member :: acc, Set.add taken member.id, normalizations
        else (
          let id = fresh taken member.id 2 in
          ( { member with id } :: acc
          , Set.add taken id
          , Normalization.Duplicate_combatant_id
              { id = Ids.Combatant_id.to_string member.id
              ; replaced_with = Ids.Combatant_id.to_string id
              }
            :: normalizations )))
  in
  List.rev members, List.rev normalizations
;;

let create ~members ~turn_index ~round ~name_counter =
  let members, duplicate_repairs = dedupe members in
  let name_counter, counter_repairs =
    match name_counter with
    | Some counter -> counter, []
    | None ->
      Name_counter.rebuild_from
        (List.filter_map members ~f:(fun (member : Combatant.t) ->
           Option.map (Combatant.Allegiance.naming_key member.allegiance) ~f:(fun key ->
             key, member.name)))
  in
  match members with
  | [] ->
    (* Nothing to be whose turn it is, so the index and the round are both
       meaningless. Say so rather than storing them. *)
    let repairs =
      (if turn_index = 0
       then []
       else [ Normalization.Turn_index_clamped { given = turn_index; used = 0 } ])
      @
      if round = Round.to_int Round.first
      then []
      else
        [ Normalization.Round_clamped { given = round; used = Round.to_int Round.first } ]
    in
    Empty { name_counter }, duplicate_repairs @ counter_repairs @ repairs
  | _ :: _ ->
    let order, index_repairs =
      Option.value_exn
        (Turn_order.of_list_with_focus
           (List.map members ~f:(fun (c : Combatant.t) -> c.id))
           ~focus:turn_index)
    in
    let clamped_round = Round.of_int_clamped round in
    let round_repairs =
      if Round.to_int clamped_round = round
      then []
      else
        [ Normalization.Round_clamped { given = round; used = Round.to_int clamped_round }
        ]
    in
    ( Active
        { members =
            Ids.Combatant_id.Map.of_alist_exn
              (List.map members ~f:(fun (c : Combatant.t) -> c.id, c))
        ; order
        ; round = clamped_round
        ; name_counter
        }
    , duplicate_repairs @ counter_repairs @ index_repairs @ round_repairs )
;;

let add t ~name_counter additions =
  let existing = members t in
  (* Against a set that grows as the batch is walked, not a fixed one: an id
     repeated {i within} [additions] is already taken by the time the second copy
     is reached. Filtering against the existing members alone was enough to make
     [Empty] raise out of [Map.of_alist_exn] and -- worse, because it was
     silent -- to leave [Active] holding an id in the order that the member map
     did not have. A property test found it; see
     [test/aggregates/test_encounter.ml]. *)
  let additions =
    List.folding_map
      additions
      ~init:
        (Ids.Combatant_id.Set.of_list
           (List.map existing ~f:(fun (c : Combatant.t) -> c.id)))
      ~f:(fun taken (c : Combatant.t) ->
        if Set.mem taken c.id then taken, None else Set.add taken c.id, Some c)
    |> List.filter_opt
  in
  match t with
  | Empty _ -> of_ordered ~ordered:(existing @ additions) ~round:Round.first ~name_counter
  | Active a ->
    let members =
      List.fold additions ~init:a.members ~f:(fun acc (c : Combatant.t) ->
        Map.set acc ~key:c.id ~data:c)
    in
    let order =
      List.fold additions ~init:a.order ~f:(fun acc (c : Combatant.t) ->
        Turn_order.add_last acc c.id)
    in
    Active { a with members; order; name_counter }
;;

let remove t id =
  match t with
  | Empty _ -> t
  | Active a ->
    if not (Map.mem a.members id)
    then t
    else (
      match Turn_order.remove a.order ~f:(Ids.Combatant_id.equal id) with
      | None -> Empty { name_counter = a.name_counter }
      | Some order -> Active { a with members = Map.remove a.members id; order })
;;

let remove_if t ~f =
  List.fold (members t) ~init:t ~f:(fun acc (c : Combatant.t) ->
    if f c then remove acc c.id else acc)
;;

let update t id ~f =
  match t with
  | Empty _ -> t
  | Active a ->
    (match Map.find a.members id with
     | None -> t
     | Some member ->
       Active { a with members = Map.set a.members ~key:id ~data:(f member) })
;;

let map_members t ~f =
  match t with
  | Empty _ -> t
  | Active a -> Active { a with members = Map.map a.members ~f }
;;

let move t id direction =
  match t with
  | Empty _ -> t
  | Active a ->
    Active
      { a with order = Turn_order.move a.order ~f:(Ids.Combatant_id.equal id) direction }
;;

let sort_by_initiative t =
  match t with
  | Empty _ -> t
  | Active a ->
    let initiative id =
      Initiative.to_int (Map.find_exn a.members id).Combatant.initiative
    in
    (* Descending, and stable, so equal initiatives keep the order the GM chose.
       Note what is not being written here: a new round. *)
    Active
      { a with
        order =
          Turn_order.sort_by a.order ~compare:(fun x y ->
            Int.descending (initiative x) (initiative y))
      }
;;

let next_turn t =
  match t with
  | Empty _ -> t, `Same_round
  | Active a ->
    let order, wrapped = Turn_order.next a.order in
    let round =
      match wrapped with
      | `Wrapped -> Round.succ a.round
      | `Same_round -> a.round
    in
    Active { a with order; round }, wrapped
;;

let prev_turn t =
  match t with
  | Empty _ -> t, `Same_round
  | Active a ->
    let order, wrapped = Turn_order.prev a.order in
    let round =
      match wrapped with
      | `Wrapped -> Round.prev a.round
      | `Same_round -> a.round
    in
    Active { a with order; round }, wrapped
;;

let tally t =
  let down = List.count (members t) ~f:Combatant.is_down in
  `Standing (length t - down), `Down down
;;
