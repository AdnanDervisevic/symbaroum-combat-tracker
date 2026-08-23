(** The add-NPC form, after the strings in it have been read.

    [NpcDraft] in {{:src/components/modals/AddCombatantModal.tsx}
    [AddCombatantModal.tsx]} holds what the user typed; this holds what it
    parsed to. The difference matters at exactly one place --
    [addNpc] ({{:src/App.tsx} [App.tsx:246]}), which coerces every field on the
    way out ([Number(x) || 0], [.trim() || "Light (d4)"]) and then quietly omits
    [attributes] altogether, dropping the preset stat block that the probability
    model needs. Here the parse happens once, in the form, and what comes out is
    a value the encounter can hold. *)

open! Core

type t =
  { monster_type : Monster_type.t option
  ; name : Name.t option (** a name typed by hand, which suppresses auto-naming *)
  ; count : Npc_count.t
  ; initiative : Initiative.t
  ; toughness : Toughness.t
  ; defense : Defense.t
  ; armor : Armor.t
  ; pain_threshold : Pain_threshold.t
  ; attributes : Attributes.t
  ; attack : Attack_profile.t option
  ; note : string
  }
[@@deriving compare, equal, fields ~getters, sexp_of, quickcheck]

(** What the dialog opens with. One value differs from [buildNpcDraft]
    ({{:src/App.tsx} [App.tsx:41]}), for the reason given in
    {!Symbaroum.Character.create_new}: the React default of [defense: 10] is a
    roll-under target of zero under this port's reading of the field. *)
val default : t

(** Mirrors [handleLoadPreset] ({{:src/App.tsx} [App.tsx:203]}), including its
    fallback of 10 toughness for a preset that records none -- which is
    defensible here and only here, because the number lands in a form field the
    GM can see and change before it becomes a combatant. *)
val of_preset : Monster_preset.t -> t

val of_bestiary_entry : Bestiary.Entry.t -> t

(** The names for this batch, and the counter that has taken those numbers.

    A hand-typed name is used as-is for a single NPC and numbered from 1 for a
    batch, exactly as [addNpc] does. Otherwise the numbers come from
    {!Symbaroum.Name_counter}, which is what stops the third goblin from being
    called "Goblin 3" twice. *)
val names : t -> name_counter:Name_counter.t -> Name_counter.t * Name.t list

val to_combatants
  :  t
  -> ids:Ids.Combatant_id.t list
  -> names:Name.t list
  -> Combatant.t list

(** [None] when the draft has no monster type, since the bestiary is keyed by
    one. *)
val to_bestiary_entry
  :  t
  -> id:Ids.Bestiary_id.t
  -> at:Time_ns.Alternate_sexp.t
  -> Bestiary.Entry.t option
