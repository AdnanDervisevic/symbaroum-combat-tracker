open! Core

module Entry = struct
  type t =
    { id : Ids.Snapshot_id.t
    ; at : Time_ns.Alternate_sexp.t
    ; label : string
    ; encounter : Encounter.t
    }
  [@@deriving compare, equal, fields ~getters, sexp_of]

  let label_for encounter =
    let members = Encounter.members encounter in
    let pcs =
      List.count members ~f:(fun (c : Combatant.t) ->
        Combatant.Allegiance.is_player c.allegiance)
    in
    let npcs = List.length members - pcs in
    let plural n = if n = 1 then "" else "s" in
    let round = Round.to_int (Encounter.round encounter) in
    [%string
      "Round %{round#Int} - %{pcs#Int} PC%{plural pcs}, %{npcs#Int} NPC%{plural npcs}"]
  ;;
end

type t = Entry.t Bounded_list.t [@@deriving compare, equal, sexp_of]

let capacity = 10
let empty = Bounded_list.create ~capacity
let of_list entries = Bounded_list.of_list ~capacity entries
let to_list = Bounded_list.to_list
let add = Bounded_list.add

let find t id =
  Bounded_list.find t ~f:(fun (e : Entry.t) -> Ids.Snapshot_id.equal e.id id)
;;

let remove t id =
  Bounded_list.filter t ~f:(fun (e : Entry.t) -> not (Ids.Snapshot_id.equal e.id id))
;;

let length = Bounded_list.length
