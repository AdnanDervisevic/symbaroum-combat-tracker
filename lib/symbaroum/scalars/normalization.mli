(** A repair the port made to data that arrived in an illegal shape. *)

open! Core

type t =
  | Turn_index_clamped of
      { given : int
      ; used : int
      }
  (** Both zero-based, as they arrive on the wire. {!to_string_hum} shifts
          them, because the UI counts "turn 3 of 5" and a GM has never seen a
          turn zero. *)
  | Round_clamped of
      { given : int
      ; used : int
      }
  | Duplicate_character_id of { id : string }
  (** The later entry was dropped. Two roster entries with one id is not a
          collision that can be repaired -- there is no way to tell which one the
          encounter members were pointing at. *)
  | Duplicate_combatant_id of
      { id : string
      ; replaced_with : string
      }
  (** The later combatant was given a fresh id derived from the old one, so
          nobody is dropped out of a fight. *)
  | Orphan_player_character of
      { name : string
      ; missing : string
      }
  (** A combatant pointed at a roster entry that is gone, so it became an
          NPC. *)
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

val to_string_hum : t -> string
