open! Core

type t =
  | Pain_threshold_exceeded of
      { name : Name.t
      ; damage : int
      }
  | Combatant_downed of { name : Name.t }
  | Round_completed of
      { round : Round.t
      ; standing : int
      ; down : int
      }
  | Encounter_archived of { label : string }
  | Encounter_restored of { label : string }
  | Data_normalized of Normalization.t list
  | Rejected of { reason : string }
[@@deriving compare, equal, sexp_of]

let to_string_hum = function
  | Pain_threshold_exceeded { name; damage } ->
    [%string "%{name#Name} takes %{damage#Int} damage and exceeds Pain Threshold"]
  | Combatant_downed { name } -> [%string "%{name#Name} is down"]
  | Round_completed { round; standing; down } ->
    let round = Round.to_int round in
    if down > 0
    then
      [%string "Round %{round#Int} complete - %{standing#Int} standing, %{down#Int} down"]
    else [%string "Round %{round#Int} complete - All %{standing#Int} combatants standing"]
  | Encounter_archived { label } -> [%string "Encounter saved - %{label}"]
  | Encounter_restored { label } -> [%string "Encounter restored - %{label}"]
  | Data_normalized [] -> "Loaded"
  | Data_normalized normalizations ->
    let n = List.length normalizations in
    let plural = if n = 1 then "" else "s" in
    [%string "Loaded - %{n#Int} correction%{plural} applied"]
  | Rejected { reason } -> reason
;;

let severity = function
  | Pain_threshold_exceeded _ -> `Warning
  | Combatant_downed _ -> `Warning
  | Round_completed _ -> `Info
  | Encounter_archived _ | Encounter_restored _ -> `Success
  | Data_normalized [] -> `Success
  | Data_normalized _ -> `Warning
  | Rejected _ -> `Error
;;
