(** The kind of an NPC -- ["Goblin"], ["Spring Elf"] -- which is what the
    auto-namer counts and what a bestiary entry is keyed by.

    Distinct from {!Symbaroum.Name}: a combatant of monster type ["Goblin"] is
    named ["Goblin 3"]. *)

open! Core
include String_id.S
