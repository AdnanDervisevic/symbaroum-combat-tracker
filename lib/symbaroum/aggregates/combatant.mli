(** A participant in the encounter. *)

open! Core

module Allegiance : sig
  type t =
    | Player_character of Ids.Character_id.t
    | Non_player of Monster_type.t option
  [@@deriving compare, equal, sexp_of, quickcheck]

  val is_player : t -> bool
  val character_id : t -> Ids.Character_id.t option

  (** {!Symbaroum.Name_counter.anonymous} for an NPC with no type of its own, so
      that auto-naming has a key for it either way. [None] for a player
      character, which is never auto-named. *)
  val naming_key : t -> Monster_type.t option
end

type t =
  { id : Ids.Combatant_id.t
  ; allegiance : Allegiance.t
  ; name : Name.t
  ; initiative : Initiative.t
  ; toughness : Toughness.t
  ; defense : Defense.t
  ; armor : Armor.t
  ; pain_threshold : Pain_threshold.t
  ; prone : bool
  ; flanked : bool
  ; attributes : Attributes.t
  ; attack : Attack_profile.t option
  ; note : string
  }
[@@deriving compare, equal, fields ~getters, sexp_of, quickcheck]

(** Mirrors [characterToCombatant] in
    {{:src/utils/combatLogic.ts} [combatLogic.ts]}. *)
val of_character : Character.t -> id:Ids.Combatant_id.t -> t

(** Mirrors [syncMemberFromPc]: name, armour, defence, pain threshold and
    attributes follow the roster entry; initiative, toughness and the in-fight
    flags do not. *)
val sync_from_character : t -> Character.t -> t

val is_down : t -> bool

(** Applies damage, floors at zero, and reports what actually landed and whether
    this blow is the one that knocked the combatant prone. The pain check uses
    the damage {i dealt}, not the number typed into the box -- see
    {!Symbaroum.Pain_threshold}. *)
val hurt : t -> int -> t * [ `Dealt of int ] * [ `Newly_prone of bool ]

(** Healing above zero also gets a combatant back on their feet, as
    [applyAdjustment] does. *)
val heal : t -> int -> t * [ `Restored of int ]
