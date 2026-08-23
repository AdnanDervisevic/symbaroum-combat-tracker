(** A roster entry: a player character, edited on the Characters tab and copied into the encounter when a fight starts. *)

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
