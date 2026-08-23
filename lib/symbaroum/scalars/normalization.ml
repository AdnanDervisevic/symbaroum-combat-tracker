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

let to_string_hum = function
  | Turn_index_clamped { given; used } ->
    [%string "Turn %{given#Int} is out of range; moved to %{used#Int}."]
  | Round_clamped { given; used } ->
    [%string "Round %{given#Int} is not a round; set to %{used#Int}."]
  | Duplicate_character_id { id } ->
    [%string "Two characters share the id %{id}; the later one was dropped."]
  | Duplicate_combatant_id { id; replaced_with } ->
    [%string "Two combatants share the id %{id}; the later one became %{replaced_with}."]
  | Orphan_player_character { name; missing } ->
    [%string "%{name} points at character %{missing}, which is gone; demoted to an NPC."]
  | Name_counter_rebuilt { highest } ->
    let types = List.length highest in
    [%string "Rebuilt the auto-naming counter for %{types#Int} monster types."]
  | Value_clamped { field; given; used } ->
    [%string "%{field} %{given#Int} is out of range; clamped to %{used#Int}."]
  | Field_unreadable { field; value } ->
    [%string "%{field} %{value} could not be read; replaced with a default."]
;;
