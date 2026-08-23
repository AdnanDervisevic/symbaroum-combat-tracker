(** A roster entry: a player character, edited on the Characters tab and copied
    into the encounter when a fight starts.

    The record is public rather than [private], which is a deliberate exception
    to how the rest of this library is built. [private] exists to force
    construction through a smart constructor that can reject an illegal
    combination -- but there is no illegal combination here. Every field is
    already a type that cannot hold a bad value, and no invariant relates one
    field to another. Sealing the record would buy nothing and would cost the
    functional-update syntax that the editing commands in Phase 3 are written
    with.

    {!is_builtin} is the field that replaces
    {{:src/components/cards/CharacterCard.tsx} [CharacterCard.tsx:112]}, which
    asks whether [id.startsWith('pc_default_')] to decide whether a character is
    one of the four shipped ones. That is a data property smuggled into a name:
    it is invisible to the type system, and it silently changes meaning the
    moment an import renumbers ids. Ids here are {!Symbaroum.Ids.Character_id}
    and carry nothing. *)

open! Core

type t =
  { id : Ids.Character_id.t
  ; name : Name.t
  ; role : string
  ; initiative : Initiative.t
  ; toughness : Toughness.t
  ; defense : Defense.t
  ; armor : Armor.t
  ; pain_threshold : Pain_threshold.t
  ; attributes : Attributes.t
  ; note : string
  ; is_builtin : bool
  }
[@@deriving compare, equal, fields ~getters, sexp_of, quickcheck]

(** The blank character the "Add" button creates, mirroring [buildNewCharacter]
    in {{:src/utils/combatLogic.ts} [combatLogic.ts]}.

    One value differs from the React original, and deliberately. That function
    sets [defense: 10], which under this port's reading of the field -- it is a
    modifier, so the target is [10 - defense] -- would be a target of zero, and
    zero is not a roll-under target anyone can fail. The React default is the
    inconsistent value, not the reading: the same file's four shipped characters
    store [8], [3], [0] and [0], which are only legal as modifiers. The default
    here is a modifier of [0], an exactly average target of 10. *)
val create_new : id:Ids.Character_id.t -> t

(** Defence expressed the way the character sheet and the JSON both write it:
    [10 - target]. *)
val defense_modifier : t -> int
