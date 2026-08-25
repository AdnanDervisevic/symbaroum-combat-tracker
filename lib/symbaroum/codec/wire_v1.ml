open! Core
module D = Json_decoder

let version = 1

module Attributes = struct
  type t =
    { acc : int option
    ; cun : int option
    ; dis : int option
    ; per : int option
    ; qui : int option
    ; res : int option
    ; str : int option
    ; vig : int option
    }
  [@@deriving compare, equal, sexp_of]

  let empty =
    { acc = None
    ; cun = None
    ; dis = None
    ; per = None
    ; qui = None
    ; res = None
    ; str = None
    ; vig = None
    }
  ;;

  let decoder =
    let open D.Let_syntax in
    let score key = D.field_opt key D.int in
    let%map acc = score "acc"
    and cun = score "cun"
    and dis = score "dis"
    and per = score "per"
    and qui = score "qui"
    and res = score "res"
    and str = score "str"
    and vig = score "vig" in
    { acc; cun; dis; per; qui; res; str; vig }
  ;;
end

module Character = struct
  type t =
    { id : string
    ; name : string
    ; role : string
    ; initiative : int
    ; toughness : int
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; attributes : Attributes.t option
    ; note : string
    }
  [@@deriving compare, equal, sexp_of]

  let decoder =
    let open D.Let_syntax in
    let%map id = D.field "id" D.string
    and name = D.field "name" D.string
    and role = D.field_or "role" D.string ~default:""
    and initiative = D.field_or "initiative" D.int ~default:0
    and toughness = D.field_or "toughness" D.int ~default:10
    and defense = D.field_or "defense" D.int ~default:0
    and armor = D.field_or "armor" D.string ~default:""
    and pain_threshold = D.field_opt "painThreshold" D.int
    and attributes = D.field_opt "attributes" Attributes.decoder
    and note = D.field_or "note" D.string ~default:"" in
    { id
    ; name
    ; role
    ; initiative
    ; toughness
    ; defense
    ; armor
    ; pain_threshold
    ; attributes
    ; note
    }
  ;;
end

module Combatant = struct
  type t =
    { id : string
    ; source : string
    ; ref_id : string option
    ; monster_type : string option
    ; name : string
    ; initiative : int
    ; toughness : int
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; prone : bool
    ; flanked : bool
    ; attributes : Attributes.t option
    ; note : string
    }
  [@@deriving compare, equal, sexp_of]

  let decoder =
    let open D.Let_syntax in
    let%map id = D.field "id" D.string
    and source = D.field_or "source" D.string ~default:"npc"
    and ref_id = D.field_opt "refId" D.string
    and monster_type = D.field_opt "monsterType" D.string
    and name = D.field "name" D.string
    and initiative = D.field_or "initiative" D.int ~default:0
    and toughness = D.field_or "toughness" D.int ~default:10
    and defense = D.field_or "defense" D.int ~default:0
    and armor = D.field_or "armor" D.string ~default:""
    and pain_threshold = D.field_opt "painThreshold" D.int
    and prone = D.field_or "prone" D.bool ~default:false
    and flanked = D.field_or "flanked" D.bool ~default:false
    and attributes = D.field_opt "attributes" Attributes.decoder
    and note = D.field_or "note" D.string ~default:"" in
    { id
    ; source
    ; ref_id
    ; monster_type
    ; name
    ; initiative
    ; toughness
    ; defense
    ; armor
    ; pain_threshold
    ; prone
    ; flanked
    ; attributes
    ; note
    }
  ;;
end

module Encounter = struct
  type t =
    { members : Combatant.t list
    ; turn_index : int
    ; round : int
    }
  [@@deriving compare, equal, sexp_of]

  let decoder =
    let open D.Let_syntax in
    let%map members = D.field "members" (D.list Combatant.decoder)
    and turn_index = D.field_or "turnIndex" D.int ~default:0
    and round = D.field_or "round" D.int ~default:1 in
    { members; turn_index; round }
  ;;
end

module Bestiary_entry = struct
  type t =
    { id : string
    ; monster_type : string
    ; initiative : int
    ; toughness : int
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; note : string
    ; updated_at_ms : float
    }
  [@@deriving compare, equal, sexp_of]

  let decoder =
    let open D.Let_syntax in
    let%map id = D.field "id" D.string
    and monster_type = D.field "monsterType" D.string
    and initiative = D.field_or "initiative" D.int ~default:0
    and toughness = D.field_or "toughness" D.int ~default:10
    and defense = D.field_or "defense" D.int ~default:0
    and armor = D.field_or "armor" D.string ~default:""
    and pain_threshold = D.field_opt "painThreshold" D.int
    and note = D.field_or "note" D.string ~default:""
    and updated_at_ms = D.field_or "updatedAt" D.float ~default:0. in
    { id
    ; monster_type
    ; initiative
    ; toughness
    ; defense
    ; armor
    ; pain_threshold
    ; note
    ; updated_at_ms
    }
  ;;
end

module History_entry = struct
  type t =
    { id : string
    ; timestamp_ms : float
    ; label : string
    ; encounter : Encounter.t
    }
  [@@deriving compare, equal, sexp_of]

  let decoder =
    let open D.Let_syntax in
    let%map id = D.field "id" D.string
    and timestamp_ms = D.field_or "timestamp" D.float ~default:0.
    and label = D.field_or "label" D.string ~default:""
    and encounter = D.field "encounter" Encounter.decoder in
    { id; timestamp_ms; label; encounter }
  ;;
end

type t =
  { version : int
  ; characters : Character.t list
  ; encounter : Encounter.t
  ; bestiary : Bestiary_entry.t list
  ; history : History_entry.t list
  }
[@@deriving compare, equal, sexp_of]

let decoder =
  let open D.Let_syntax in
  let%map declared =
    D.validate (D.field "version" D.int) ~f:(fun declared ->
      (* [validateImportData] checks that this is a number and never compares it
         to anything, so a version 7 file is accepted and blind-cast. *)
      if declared = version
      then Ok declared
      else
        Error
          [%string
            "this file says version %{declared#Int}; this app reads version \
             %{version#Int}"])
  and characters = D.field "characters" (D.list Character.decoder)
  and encounter = D.field "encounter" Encounter.decoder
  and bestiary = D.field_or "bestiary" (D.list Bestiary_entry.decoder) ~default:[] in
  { version = declared; characters; encounter; bestiary; history = [] }
;;

module Local_storage = struct
  let characters = "sct.v1.characters"
  let encounter = "sct.v1.encounter"
  let encounter_history = "sct.v1.encounterHistory"
  let bestiary = "sct.v1.bestiary"
  let theme = "sct.v1.theme"

  (* One key, read independently of the others. A key that is absent gives the
     default; a key that is present and unreadable gives the default *and* an
     error, because starting without a bestiary beats refusing to start. *)
  let read find key decoder ~default =
    match find key with
    | None -> default, []
    | Some raw ->
      (match D.run_string decoder raw with
       | Ok value -> value, []
       | Error errors ->
         ( default
         , List.map errors ~f:(fun (e : D.Error.t) ->
             { e with
               path =
                 [%string "%{key}%{String.chop_prefix_if_exists e.path ~prefix:\"$\"}"]
             }) ))
  ;;

  let load ~find =
    let characters, e1 = read find characters (D.list Character.decoder) ~default:[] in
    let encounter, e2 =
      read
        find
        encounter
        Encounter.decoder
        ~default:{ Encounter.members = []; turn_index = 0; round = 1 }
    in
    let bestiary, e3 = read find bestiary (D.list Bestiary_entry.decoder) ~default:[] in
    let history, e4 =
      read find encounter_history (D.list History_entry.decoder) ~default:[]
    in
    { version; characters; encounter; bestiary; history }, List.concat [ e1; e2; e3; e4 ]
  ;;
end
