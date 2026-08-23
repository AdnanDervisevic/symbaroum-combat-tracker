(** The save format the deployed React app writes. {b Frozen forever.}

    Real people have real data in this shape, in [localStorage] under the
    [sct.v1.*] keys and in files exported from the live site. Nothing in this
    module may change in a way that stops reading an old blob.

    {1 Total records, no invariants}

    Every type here mirrors {{:src/types.ts} [types.ts]} field for field,
    including the three ways it spells "absent". These are the {i wire} shapes:
    [toughness] is one [int] doing the job of a current and a maximum,
    [painThreshold] is an [int option] whose [None] and [Some 0] mean opposite
    things, and [source] is a bare string that may say anything. None of that is
    repaired here. Decoding this module's types can only fail on input that is
    structurally not this format; everything else is somebody else's problem, and
    that somebody is {!Symbaroum.Wire_v2.to_domain}.

    Separating the two is what makes the pipeline testable: a malformed file
    fails here with a JSON path, and a legal-but-wrong file passes here and comes
    out of the domain conversion with a list of repairs.

    {1 Why the eight attribute keys are spelled out}

    {!Symbaroum.Attribute} already maps ["acc"] to [Accurate], and reusing it
    would be shorter. It would also couple a frozen format to a living type: add
    a ninth attribute to the domain and this reader starts looking for a ninth
    key in files that will never have one. Independence from the domain is the
    property that makes a format freezable, so the keys are written out. *)

open! Core

module Attributes : sig
  (** [CharacterAttributes]. Each of the eight is [number | null] and may also be
      missing, which is three spellings of the same absence. *)
  type t =
    { acc : int option
    ; cun : int option
    ; dis : int option
    ; per : int option
    ; qui : int option
    ; res : int option
    ; str : int option
    ; vig : int option
    }
  [@@deriving compare, equal, sexp_of]

  val empty : t
  val decoder : t Json_decoder.t
end

module Character : sig
  type t =
    { id : string
    ; name : string
    ; role : string
    ; initiative : int
    ; toughness : int
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; attributes : Attributes.t option
    ; note : string
    }
  [@@deriving compare, equal, sexp_of]

  val decoder : t Json_decoder.t
end

module Combatant : sig
  (** [source], [refId] and [monsterType] are three loosely coupled fields whose
      legal combinations are a convention rather than a type -- which is what
      {!Symbaroum.Combatant.Allegiance} fuses. Faithfully, they are three fields
      here. *)
  type t =
    { id : string
    ; source : string
    ; ref_id : string option
    ; monster_type : string option
    ; name : string
    ; initiative : int
    ; toughness : int
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; prone : bool
    ; flanked : bool
    ; attributes : Attributes.t option
    ; note : string
    }
  [@@deriving compare, equal, sexp_of]

  val decoder : t Json_decoder.t
end

module Encounter : sig
  (** [turn_index] and [round] are unconstrained, which is the whole point:
      [{members = []; turn_index = 5; round = 0}] is a value this type can hold,
      because it is a value the format can hold. *)
  type t =
    { members : Combatant.t list
    ; turn_index : int
    ; round : int
    }
  [@@deriving compare, equal, sexp_of]

  val decoder : t Json_decoder.t
end

module Bestiary_entry : sig
  type t =
    { id : string
    ; monster_type : string
    ; initiative : int
    ; toughness : int
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; note : string
    ; updated_at_ms : int (** [Date.now()], so milliseconds since the epoch *)
    }
  [@@deriving compare, equal, sexp_of]

  val decoder : t Json_decoder.t
end

module History_entry : sig
  type t =
    { id : string
    ; timestamp_ms : int
    ; label : string
    ; encounter : Encounter.t
    }
  [@@deriving compare, equal, sexp_of]

  val decoder : t Json_decoder.t
end

(** The exported file: [ExportPayload]. Note that it carries no encounter
    history -- that lives only in [localStorage] -- so an export and a browser
    hold different subsets of the same state. *)
type t =
  { version : int
  ; characters : Character.t list
  ; encounter : Encounter.t
  ; bestiary : Bestiary_entry.t list
  ; history : History_entry.t list
    (** always [[]] from a file; populated when the source is [localStorage] *)
  }
[@@deriving compare, equal, sexp_of]

(** [1]. *)
val version : int

(** Rejects a version other than {!version}. [validateImportData]
    ({{:src/utils/exportImport.ts} [exportImport.ts:44]}) checks that [version]
    is a {i number} and never compares it to anything, so a [version: 7] file is
    accepted and blind-cast. *)
val decoder : t Json_decoder.t

module Local_storage : sig
  (** The five keys the deployed app writes. Keep reading these forever. *)

  val characters : string
  val encounter : string
  val encounter_history : string
  val bestiary : string

  (** ["light"] or ["dark"]. Not part of {!Symbaroum.World.t} -- the theme is
      deliberately outside the undo history -- so the UI reads this one itself.
      The name lives here because this is where the [sct.v1.*] spelling is
      recorded. *)
  val theme : string

  (** Assembles the four state-bearing keys into a {!t}, reading each through
      [find] -- [localStorage.getItem] in the browser, a fixture in the tests.

      Every key is independently optional and independently repairable: a fresh
      install has none, and a browser interrupted mid-write has some. A key that
      is present but unreadable is reported and skipped rather than failing the
      load, because losing the bestiary is a better outcome than refusing to
      start. *)
  val load : find:(string -> string option) -> t * Json_decoder.Error.t list
end
