open! Core

type t =
  | Turn_index_clamped of
      { given : int
      ; used : int
      }
  | Round_clamped of
      { given : int
      ; used : int
      }
  | Duplicate_character_id of { id : string }
  | Duplicate_combatant_id of
      { id : string
      ; replaced_with : string
      }
  | Orphan_player_character of
      { name : string
      ; missing : string
      }
  | Name_counter_rebuilt of { highest : (string * int) list }
  | Value_clamped of
      { field : string
      ; given : int
      ; used : int
      }
  | Field_unreadable of
      { field : string
      ; value : string
      }
[@@deriving compare, equal, sexp_of]

(* The fields hold what was on the wire, which is zero-based. These strings are
   read by a GM, who has never seen a zero-based turn: the UI counts "turn 3 of
   5". So the numbers are shifted here, once, at the point where they stop being
   data and start being a sentence. *)
let turn n = Int.to_string (n + 1)

let to_string_hum = function
  | Turn_index_clamped { given; used } ->
    [%string "There is no turn %{turn given}; moved to turn %{turn used}."]
  | Round_clamped { given; used } ->
    [%string "Round %{given#Int} is not a round; set to %{used#Int}."]
  | Duplicate_character_id { id } ->
    [%string "Two characters share the id %{id}; the later one was dropped."]
  | Duplicate_combatant_id { id; replaced_with } ->
    [%string "Two combatants share the id %{id}; the later one became %{replaced_with}."]
  | Orphan_player_character { name; missing } ->
    [%string "%{name} points at character %{missing}, which is gone; demoted to an NPC."]
  | Name_counter_rebuilt { highest } ->
    (* Naming the marks rather than counting them. "for 1 monster types" was
       both ungrammatical and useless: what a GM wants to know is that the next
       goblin will be Goblin 8. *)
    let marks =
      String.concat
        ~sep:", "
        (List.map highest ~f:(fun (monster_type, n) ->
           [%string "%{monster_type} %{n#Int}"]))
    in
    [%string "Rebuilt the auto-naming counter from %{marks}."]
  | Value_clamped { field; given; used } ->
    [%string "%{field} %{given#Int} is out of range; clamped to %{used#Int}."]
  | Field_unreadable { field; value } ->
    [%string "%{field} %{value} could not be read; replaced with a default."]
;;
