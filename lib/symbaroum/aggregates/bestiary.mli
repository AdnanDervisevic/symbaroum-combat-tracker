(** Stat blocks the GM has used before, keyed by monster type.

    [addNpc] writes one of these every time it adds an NPC with a type, so the
    dialog can offer it again. The React entry
    ({{:src/types.ts} [types.ts]}) stores no attributes, which means the
    round trip preset -> encounter -> bestiary -> encounter silently loses the
    attribute block. Since the attribute block is what the probability model
    reads, this port keeps it.

    Keyed by {!Symbaroum.Monster_type}, not by
    {!Symbaroum.Ids.Bestiary_id}: the React code looks entries up by monster type
    ([prev.find((e) => e.monsterType === monsterType)]) and only uses the id to
    decide whether to append or replace. Making the type the key is what the code
    already means. The id survives so that deleting from the UI list keeps
    working. *)

open! Core

module Entry : sig
  type t =
    { id : Ids.Bestiary_id.t
    ; monster_type : Monster_type.t
    ; initiative : Initiative.t
    ; toughness : Toughness.t
    ; defense : Defense.t
    ; armor : Armor.t
    ; pain_threshold : Pain_threshold.t
    ; attributes : Attributes.t
    ; attack : Attack_profile.t option
    ; note : string
    ; updated_at : Time_ns.Alternate_sexp.t
    }
  [@@deriving compare, equal, fields ~getters, sexp_of]
end

type t = private
  { by_type : Entry.t Monster_type.Map.t
  ; order : Monster_type.t list
  }
[@@deriving compare, equal, sexp_of]

val empty : t
val of_list : Entry.t list -> t
val to_list : t -> Entry.t list
val find : t -> Monster_type.t -> Entry.t option
val find_by_id : t -> Ids.Bestiary_id.t -> Entry.t option
val length : t -> int

(** Replaces the entry for this monster type, keeping the id and the list
    position of the entry it replaces. *)
val upsert : t -> Entry.t -> t

val remove : t -> Ids.Bestiary_id.t -> t
