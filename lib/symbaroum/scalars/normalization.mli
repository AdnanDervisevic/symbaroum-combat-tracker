(** A repair the port made to data that arrived in an illegal shape.

    The rule this type exists to enforce: normalization is {b total} and
    {b reported}, never silent and never rejecting. Only structurally impossible
    input -- unparseable JSON, an unknown save version, [members] that is not an
    array -- is an error. Everything else is repaired, and every repair comes
    back in a list.

    That turns "we clamp somewhere" into a specification. The import dialog can
    say "Loaded -- 3 corrections applied" and the tests can assert exactly which
    three. The alternative, clamping quietly at whichever call site last
    remembered to, is what the React app does: three view-layer sites, and none
    at all on the import path. *)

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
