open! Core

(* [yojson_of_int], [yojson_of_option] and friends, which the [@@deriving
   yojson_of] expansions below call by name. *)
open Ppx_yojson_conv_lib.Yojson_conv.Primitives
module D = Json_decoder

let version = 2

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
  [@@deriving compare, equal, sexp_of, yojson_of]

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

module Toughness = struct
  type t =
    { current : int
    ; max : int
    }
  [@@deriving compare, equal, sexp_of, yojson_of]

  let decoder =
    let open D.Let_syntax in
    let%map current = D.field "current" D.int
    and max = D.field "max" D.int in
    { current; max }
  ;;
end

module Dice = struct
  type t =
    { count : int
    ; sides : int
    ; modifier : int
    }
  [@@deriving compare, equal, sexp_of, yojson_of]

  let decoder =
    let open D.Let_syntax in
    let%map count = D.field "count" D.int
    and sides = D.field "sides" D.int
    and modifier = D.field_or "modifier" D.int ~default:0 in
    { count; sides; modifier }
  ;;
end

module Attack = struct
  type t =
    { accurate : int
    ; damage : Dice.t
    ; estimated_from : string option
    }
  [@@deriving compare, equal, sexp_of, yojson_of]

  let decoder =
    let open D.Let_syntax in
    let%map accurate = D.field "accurate" D.int
    and damage = D.field "damage" Dice.decoder
    and estimated_from = D.field_opt "estimated_from" D.string in
    { accurate; damage; estimated_from }
  ;;
end

module Character = struct
  type t =
    { id : string
    ; name : string
    ; role : string
    ; initiative : int
    ; toughness : Toughness.t
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; attributes : Attributes.t
    ; note : string
    ; is_builtin : bool
    }
  [@@deriving compare, equal, sexp_of, yojson_of]

  let decoder =
    let open D.Let_syntax in
    let%map id = D.field "id" D.string
    and name = D.field "name" D.string
    and role = D.field_or "role" D.string ~default:""
    and initiative = D.field "initiative" D.int
    and toughness = D.field "toughness" Toughness.decoder
    and defense = D.field "defense" D.int
    and armor = D.field_or "armor" D.string ~default:""
    and pain_threshold = D.field_opt "pain_threshold" D.int
    and attributes = D.field_or "attributes" Attributes.decoder ~default:Attributes.empty
    and note = D.field_or "note" D.string ~default:""
    and is_builtin = D.field_or "is_builtin" D.bool ~default:false in
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
    ; is_builtin
    }
  ;;
end

module Combatant = struct
  module Allegiance = struct
    type t =
      | Player_character of string
      | Non_player of string option
    [@@deriving compare, equal, sexp_of]

    (* Hand-written, both directions. One key, so the three fields v1 needed
       cannot contradict each other -- which is the same argument
       [Combatant.Allegiance] makes in the domain, made again at the boundary
       where it would otherwise be lost. *)
    let yojson_of_t : t -> Yojson.Safe.t = function
      | Player_character id -> `Assoc [ "pc", `String id ]
      | Non_player None -> `Assoc [ "npc", `Null ]
      | Non_player (Some monster_type) -> `Assoc [ "npc", `String monster_type ]
    ;;

    let decoder =
      D.one_of
        "an allegiance, either {\"pc\": id} or {\"npc\": monster type or null}"
        [ D.map (D.field "pc" D.string) ~f:(fun id -> Player_character id)
        ; D.map
            (D.field
               "npc"
               (D.one_of
                  "a monster type or null"
                  [ D.map D.null ~f:(fun () -> None); D.map D.string ~f:Option.some ]))
            ~f:(fun monster_type -> Non_player monster_type)
        ]
    ;;
  end

  type t =
    { id : string
    ; allegiance : Allegiance.t
    ; name : string
    ; initiative : int
    ; toughness : Toughness.t
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; prone : bool
    ; flanked : bool
    ; attributes : Attributes.t
    ; attack : Attack.t option
    ; note : string
    }
  [@@deriving compare, equal, sexp_of, yojson_of]

  let decoder =
    let open D.Let_syntax in
    let%map id = D.field "id" D.string
    and allegiance = D.field "allegiance" Allegiance.decoder
    and name = D.field "name" D.string
    and initiative = D.field "initiative" D.int
    and toughness = D.field "toughness" Toughness.decoder
    and defense = D.field "defense" D.int
    and armor = D.field_or "armor" D.string ~default:""
    and pain_threshold = D.field_opt "pain_threshold" D.int
    and prone = D.field_or "prone" D.bool ~default:false
    and flanked = D.field_or "flanked" D.bool ~default:false
    and attributes = D.field_or "attributes" Attributes.decoder ~default:Attributes.empty
    and attack = D.field_opt "attack" Attack.decoder
    and note = D.field_or "note" D.string ~default:"" in
    { id
    ; allegiance
    ; name
    ; initiative
    ; toughness
    ; defense
    ; armor
    ; pain_threshold
    ; prone
    ; flanked
    ; attributes
    ; attack
    ; note
    }
  ;;
end

(* The deriver renders this as [["Goblin", 7]] rather than {"Goblin": 7}. See the
   note in the .mli: the shape is the deriver's to choose, and the round-trip
   test is what keeps the reader honest about it. *)
let mark_decoder =
  let open D.Let_syntax in
  let pair =
    D.validate (D.list D.json) ~f:(function
      | [ `String key; `Int n ] -> Ok (key, n)
      | _ -> Error "expected a [name, count] pair")
  in
  let%map marks = D.list pair in
  marks
;;

module Encounter = struct
  type t =
    { members : Combatant.t list
    ; turn_index : int
    ; round : int
    ; name_counter : (string * int) list option
    }
  [@@deriving compare, equal, sexp_of, yojson_of]

  let decoder =
    let open D.Let_syntax in
    let%map members = D.field "members" (D.list Combatant.decoder)
    and turn_index = D.field_or "turn_index" D.int ~default:0
    and round = D.field_or "round" D.int ~default:1
    and name_counter = D.field_opt "name_counter" mark_decoder in
    { members; turn_index; round; name_counter }
  ;;
end

module Bestiary_entry = struct
  type t =
    { id : string
    ; monster_type : string
    ; initiative : int
    ; toughness : Toughness.t
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; attributes : Attributes.t
    ; attack : Attack.t option
    ; note : string
    ; updated_at_ms : int
    }
  [@@deriving compare, equal, sexp_of, yojson_of]

  let decoder =
    let open D.Let_syntax in
    let%map id = D.field "id" D.string
    and monster_type = D.field "monster_type" D.string
    and initiative = D.field "initiative" D.int
    and toughness = D.field "toughness" Toughness.decoder
    and defense = D.field "defense" D.int
    and armor = D.field_or "armor" D.string ~default:""
    and pain_threshold = D.field_opt "pain_threshold" D.int
    and attributes = D.field_or "attributes" Attributes.decoder ~default:Attributes.empty
    and attack = D.field_opt "attack" Attack.decoder
    and note = D.field_or "note" D.string ~default:""
    and updated_at_ms = D.field_or "updated_at_ms" D.int ~default:0 in
    { id
    ; monster_type
    ; initiative
    ; toughness
    ; defense
    ; armor
    ; pain_threshold
    ; attributes
    ; attack
    ; note
    ; updated_at_ms
    }
  ;;
end

module Archive_entry = struct
  type t =
    { id : string
    ; at_ms : int
    ; label : string
    ; encounter : Encounter.t
    }
  [@@deriving compare, equal, sexp_of, yojson_of]

  let decoder =
    let open D.Let_syntax in
    let%map id = D.field "id" D.string
    and at_ms = D.field_or "at_ms" D.int ~default:0
    and label = D.field_or "label" D.string ~default:""
    and encounter = D.field "encounter" Encounter.decoder in
    { id; at_ms; label; encounter }
  ;;
end

type t =
  { version : int
  ; characters : Character.t list
  ; encounter : Encounter.t
  ; bestiary : Bestiary_entry.t list
  ; archive : Archive_entry.t list
  }
[@@deriving compare, equal, sexp_of, yojson_of]

let decoder =
  let open D.Let_syntax in
  let%map declared =
    D.validate (D.field "version" D.int) ~f:(fun declared ->
      if declared = version
      then Ok declared
      else
        Error
          [%string
            "this file says version %{declared#Int}; this app reads version \
             %{version#Int}"])
  and characters = D.field "characters" (D.list Character.decoder)
  and encounter = D.field "encounter" Encounter.decoder
  and bestiary = D.field_or "bestiary" (D.list Bestiary_entry.decoder) ~default:[]
  and archive = D.field_or "archive" (D.list Archive_entry.decoder) ~default:[] in
  { version = declared; characters; encounter; bestiary; archive }
;;
