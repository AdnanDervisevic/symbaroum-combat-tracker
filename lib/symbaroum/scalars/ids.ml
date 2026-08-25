open! Core

module type S = String_id.S

module Character_id =
  String_id.Make
    (struct
      let module_name = "Symbaroum.Ids.Character_id"
    end)
    ()

module Combatant_id =
  String_id.Make
    (struct
      let module_name = "Symbaroum.Ids.Combatant_id"
    end)
    ()

module Bestiary_id =
  String_id.Make
    (struct
      let module_name = "Symbaroum.Ids.Bestiary_id"
    end)
    ()

module Snapshot_id =
  String_id.Make
    (struct
      let module_name = "Symbaroum.Ids.Snapshot_id"
    end)
    ()
