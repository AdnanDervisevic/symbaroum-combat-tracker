(** Every transition the app can make, as data.

    In the React app these are seventeen closures defined inside the [App]
    component, each calling one or two [setState]s. As a variant they become
    something a test can build a list of, a property test can generate, and the
    undo stack can reason about.

    {b Effects are arguments, not results.} A command that needs a fresh id or
    the current time carries them, because a reducer that calls [uid()] or
    [Date.now()] is not a function and cannot be tested by comparing outputs.
    The impurity moves out to the one place that is allowed to have it -- the
    event handler in the UI -- and everything downstream stays pure. *)

open! Core

type t =
  | Add_character of { id : Ids.Character_id.t }
  | Update_character of
      { id : Ids.Character_id.t
      ; patch : Character_patch.t
      }
  | Delete_character of { id : Ids.Character_id.t }
  | Add_player_characters of
      { characters : (Ids.Character_id.t * Ids.Combatant_id.t) list
        (** the roster entry to add, and the id its combatant will have *)
      }
  | Add_npcs of
      { draft : Npc_draft.t
      ; ids : Ids.Combatant_id.t list
      ; bestiary_id : Ids.Bestiary_id.t
      ; at : Time_ns.Alternate_sexp.t
      }
  | Update_member of
      { id : Ids.Combatant_id.t
      ; patch : Member_patch.t
      }
  | Adjust of
      { id : Ids.Combatant_id.t
      ; amount : Adjust_amount.t
      ; mode : [ `Hurt | `Heal ]
      }
  | Remove_member of { id : Ids.Combatant_id.t }
  | Move_member of
      { id : Ids.Combatant_id.t
      ; direction : [ `Up | `Down ]
      }
  | Sort_by_initiative
  | Next_turn
  | Prev_turn
  | Clear_encounter of
      { snapshot_id : Ids.Snapshot_id.t
      ; at : Time_ns.Alternate_sexp.t
      }
  | Restore_encounter of { id : Ids.Snapshot_id.t }
  | Delete_snapshot of { id : Ids.Snapshot_id.t }
  | Delete_bestiary_entry of { id : Ids.Bestiary_id.t }
  | Sync_members_from_roster
[@@deriving compare, equal, sexp_of]

(** Two commands with the same non-[None] key collapse into a single undo entry.
    Only field edits have one, and the key names the field, so typing a sentence
    into a note costs one undo rather than fifty -- and then changing a different
    field starts a new entry. See {!Symbaroum.Undo_history.push}. *)
val coalesce_key : t -> string option

(** Whether this command should be recorded on the undo stack at all. Stepping
    the turn is; deleting a bestiary entry is not, because it is not part of the
    fight. *)
val is_undoable : t -> bool
