(** One entry of the shipped bestiary, normalized. *)

open! Core

(** A loose display grouping -- ["Elf"], ["Abomination"], ["Human/Goblin"]. It
    carries no rules meaning; it exists so the add-combatant dialog can show
    headings. *)
module Category : String_id.S

(** The wire shape, exactly as transcribed from the TypeScript by
    [scripts/gen_monster_presets.py]. Nothing here is validated: that is the
    point, since it lets the generated file be diffed against its source line by
    line. *)
module Raw : sig
  type t =
    { name : string
    ; category : string
    ; resistance : string
    ; toughness : int option
    ; defense : int option
    ; armor : string option
    ; pain_threshold : int option
    ; attributes : (string * int option) list
    }
  [@@deriving compare, equal, sexp_of]
end

(** Which of the two readings produced {!defense}. *)
module Defense_reading : sig
  type t =
    | Stored_modifier (** [10 - defense] was a legal target, and was used. *)
    | Derived_from_quick (** The stored field was absent or illegal, so Quick was used. *)
    | Unknown (** Neither was available. Unreachable for the shipped data. *)
  [@@deriving compare, equal, enumerate, sexp_of, quickcheck]
end

type t = private
  { name : Monster_type.t
  ; category : Category.t
  ; resistance : Resistance.t
  ; toughness : Toughness.t option
  ; defense : Defense.t option
  ; defense_raw : int option (** the number the file stored, kept for the diff *)
  ; defense_reading : Defense_reading.t
  ; armor : Armor.t
  ; pain_threshold : Pain_threshold.t
  ; attributes : Attributes.t
  ; attack : Attack_profile.t option
  ; caveats : Caveat.t list
  }
[@@deriving compare, equal, sexp_of]

(** [Error] only for input that is structurally impossible: an empty name, an
    unknown resistance band, an unknown attribute key, an attribute score outside
    [1 .. 20]. Everything else is recoverable and is recovered, with a
    {!Symbaroum.Caveat} for anything that had to be guessed. *)
val of_raw : Raw.t -> t Or_error.t

(** What the add-NPC dialog puts in the initiative box, mirroring
    [handleLoadPreset] ({{:src/App.tsx} [App.tsx:203]}): the creature's Quick, or
    zero if it has none. *)
val initiative : t -> Initiative.t
