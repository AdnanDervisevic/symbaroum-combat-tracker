(** One entry of the shipped bestiary, normalized.

    {1 The Defense reconciliation}

    The [defense] field in {{:src/data/defaultMonsters.ts} [defaultMonsters.ts]}
    was transcribed from statblocks under more than one convention. Counted
    across all 86 presets, reading it as a {b modifier} -- so that the roll-under
    target is [10 - defense] -- lands inside {!Symbaroum.Defense}'s legal range
    for 74 of the 79 presets that have the field at all. The five that do not are
    the absolute-target spelling: Servant Daemon stores [15] at [qui: 15].

    The ruling for this port is that the stored field {b is a modifier}. It is
    applied uniformly -- to presets, to player characters, and to the defaults
    the UI offers -- because that reading is the only one under which the whole
    shipped dataset is legal. It also gives the right answer for the two
    placeholder player characters, whose [defense: 0] becomes a target of 10,
    exactly average, which is what a placeholder should mean. (Reading the field
    as an absolute target instead makes those two [0], which is not a legal
    roll-under target at all, and is the source of the [Infinity] in the old
    difficulty heuristic.)

    Where the modifier reading does not fit, defence is derived from Quick, which
    is present and internally consistent in all 86 presets. {!Defense_reading.t}
    records which of the two happened and {!defense_raw} keeps the original
    number, so the golden test in [test/test_monster_presets.ml] prints the
    substitution rather than performing it silently.

    {1 What is missing from the data}

    Seven presets carry no toughness, defence, armour or pain threshold at all --
    only attributes. They are normalized like any other, and the things that
    could not be recovered come back as {!Symbaroum.Caveat}s rather than as
    defaults. An estimate that cannot be told apart from a datum is worse than
    no estimate. *)

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

(** Whether {!Symbaroum.Difficulty} can use this creature: it needs a maximum
    toughness, a defence and an attack. *)
val is_modellable : t -> bool
