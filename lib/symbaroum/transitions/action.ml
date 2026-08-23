open! Core

type t =
  | Add_character of { id : Ids.Character_id.t }
  | Update_character of
      { id : Ids.Character_id.t
      ; patch : Character_patch.t
      }
  | Delete_character of { id : Ids.Character_id.t }
  | Add_player_characters of
      { characters : (Ids.Character_id.t * Ids.Combatant_id.t) list }
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

let coalesce_key = function
  | Update_character { id; patch } ->
    Some [%string "character:%{id#Ids.Character_id}:%{Character_patch.field patch}"]
  | Update_member { id; patch } ->
    Some [%string "member:%{id#Ids.Combatant_id}:%{Member_patch.field patch}"]
  | Add_character _
  | Delete_character _
  | Add_player_characters _
  | Add_npcs _
  | Adjust _
  | Remove_member _
  | Move_member _
  | Sort_by_initiative
  | Next_turn
  | Prev_turn
  | Clear_encounter _
  | Restore_encounter _
  | Delete_snapshot _
  | Delete_bestiary_entry _
  | Sync_members_from_roster -> None
;;

let is_undoable = function
  | Delete_snapshot _ | Delete_bestiary_entry _ | Sync_members_from_roster -> false
  | Add_character _
  | Update_character _
  | Delete_character _
  | Add_player_characters _
  | Add_npcs _
  | Update_member _
  | Adjust _
  | Remove_member _
  | Move_member _
  | Sort_by_initiative
  | Next_turn
  | Prev_turn
  | Clear_encounter _
  | Restore_encounter _ -> true
;;
