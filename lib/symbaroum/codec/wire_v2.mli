(** The save format this port writes.

    v1 could not hold what the domain knows. It has one [toughness] where there
    is a current and a maximum, no name counter (so auto-naming restarts on
    reload), no attack profile (so the probability model's input is lost on the
    way to disk), no [is_builtin] flag, and no archive of cleared encounters. So
    there is a v2, and {!Symbaroum.Migrate} carries v1 forward into it.

    {1 Derived writer, hand-written reader}

    The records here derive their writer: encoding is total, so the mechanical
    direction is the safe one to mechanise, and a hand-written writer for a
    twelve-field record is boilerplate that can drift from the reader without
    anybody noticing. Decoding is partial and has to pass through smart
    constructors, so it is written out -- see {!Symbaroum.Json_decoder} for that
    argument at length.

    They also derive a full sexp round trip, [t_of_sexp] included, which is safe
    here for the same reason: these are total records with no invariants, so a
    deriver cannot build one that the domain would reject. It is used by the web
    layer, where Bonsai's model type wants a sexp round trip and the domain types
    deliberately have none -- so the model goes out through the wire types and
    back in through the smart constructors, exactly as a save file does.

    The consequence worth stating plainly: {b the deriver picks the JSON shape},
    and in two places the shape it picks is uglier than one would choose by hand.
    [name_counter] becomes [[["Goblin", 7]]] rather than [{"Goblin": 7}], and the
    same for a combatant's known attributes. That is the price of the mechanical
    writer and it is worth paying, because the alternative is two hand-written
    halves that agree only as long as somebody remembers to make them. The
    round-trip test is what holds the two halves together either way.

    Three sum types {i do} have hand-written encoders --
    {!Combatant.Allegiance}, {!Attack.t}'s provenance, and armour -- because
    there the JSON shape is a decision rather than boilerplate. They are called
    out where they appear.

    {1 What is not here}

    No theme: it is not part of {!Symbaroum.World.t}, deliberately, because it is
    not undoable. The UI reads its own key. *)

open! Core

(** [2]. *)
val version : int

module Attributes : sig
  (** Eight explicit fields rather than the domain's map, for the same reason
      {!Symbaroum.Wire_v1.Attributes} spells them out: a format that names the
      domain's keys is a format that changes when the domain does. *)
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
  [@@deriving compare, equal, sexp, yojson_of]

  val empty : t
  val decoder : t Json_decoder.t
end

module Toughness : sig
  type t =
    { current : int
    ; max : int
    }
  [@@deriving compare, equal, sexp, yojson_of]

  val decoder : t Json_decoder.t
end

module Dice : sig
  type t =
    { count : int
    ; sides : int
    ; modifier : int
    }
  [@@deriving compare, equal, sexp, yojson_of]

  val decoder : t Json_decoder.t
end

module Attack : sig
  (** [estimated_from] is [None] when the numbers came from the data and
      [Some "Ordinary"] when the damage die was guessed from the creature's
      resistance band. It survives the round trip because an estimate that
      forgets it is an estimate is exactly the failure
      {!Symbaroum.Attack_profile} exists to prevent. *)
  type t =
    { accurate : int
    ; damage : Dice.t
    ; estimated_from : string option
    }
  [@@deriving compare, equal, sexp, yojson_of]

  val decoder : t Json_decoder.t
end

module Character : sig
  (** [defense] is the absolute roll-under target, which is the form
      {!Symbaroum.Defense} stores. v1's field is a modifier; the migration
      converts. [pain_threshold] is still an [int option] and still means
      "[None] never prones, [Some 0] prones on every hit" -- the ambiguity was in
      the {i type}, and giving it a name did not change what the number on the
      wire is. *)
  type t =
    { id : string
    ; name : string
    ; role : string
    ; initiative : int
    ; toughness : Toughness.t
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; attributes : Attributes.t
    ; note : string
    ; is_builtin : bool
    }
  [@@deriving compare, equal, sexp, yojson_of]

  val decoder : t Json_decoder.t
end

module Combatant : sig
  module Allegiance : sig
    (** On the wire this is [{"pc": "pc_default_ymma"}] or [{"npc": "Goblin"}] or
        [{"npc": null}] -- one key, so the three fields v1 needed cannot
        disagree. Hand-written in both directions, because this shape is the
        decision and not the deriver's. *)
    type t =
      | Player_character of string
      | Non_player of string option
    [@@deriving compare, equal, sexp]

    val yojson_of_t : t -> Yojson.Safe.t
    val decoder : t Json_decoder.t
  end

  type t =
    { id : string
    ; allegiance : Allegiance.t
    ; name : string
    ; initiative : int
    ; toughness : Toughness.t
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; prone : bool
    ; flanked : bool
    ; attributes : Attributes.t
    ; attack : Attack.t option
    ; note : string
    }
  [@@deriving compare, equal, sexp, yojson_of]

  val decoder : t Json_decoder.t
end

module Encounter : sig
  (** [name_counter] is an option rather than a possibly-empty list, and the
      distinction is load-bearing: [None] means "this save predates the counter,
      rebuild it from the names", and [Some []] means "the counter is empty,
      leave it alone". Collapsing the two made a fight whose only combatant is an
      unnamed NPC come back with a counter it did not have, which is a round trip
      that changes the value. *)
  type t =
    { members : Combatant.t list
    ; turn_index : int
    ; round : int
    ; name_counter : (string * int) list option
    }
  [@@deriving compare, equal, sexp, yojson_of]

  val decoder : t Json_decoder.t
end

module Bestiary_entry : sig
  type t =
    { id : string
    ; monster_type : string
    ; initiative : int
    ; toughness : Toughness.t
    ; defense : int
    ; armor : string
    ; pain_threshold : int option
    ; attributes : Attributes.t
    ; attack : Attack.t option
    ; note : string
    ; updated_at_ms : float
    }
  [@@deriving compare, equal, sexp, yojson_of]

  val decoder : t Json_decoder.t
end

module Archive_entry : sig
  type t =
    { id : string
    ; at_ms : float
    ; label : string
    ; encounter : Encounter.t
    }
  [@@deriving compare, equal, sexp, yojson_of]

  val decoder : t Json_decoder.t
end

type t =
  { version : int
  ; characters : Character.t list
  ; encounter : Encounter.t
  ; bestiary : Bestiary_entry.t list
  ; archive : Archive_entry.t list
  }
[@@deriving compare, equal, sexp, yojson_of]

(** Rejects a version other than {!version}. *)
val decoder : t Json_decoder.t
