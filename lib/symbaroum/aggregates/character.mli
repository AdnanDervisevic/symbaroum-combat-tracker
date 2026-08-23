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
    in {{:src/utils/combatLogic.ts} [combatLogic.ts]}, including its
    [defense: 10] -- an exactly average roll-under target. *)
val create_new : id:Ids.Character_id.t -> t
