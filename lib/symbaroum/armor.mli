(** Armour, as the GM typed it, together with whatever the parser could make of
    it.

    [armor: string] in {{:src/types.ts} [types.ts]} is never parsed anywhere in
    the React app -- it is display text that happens to look like a rule. The
    monster presets spell it as a bare integer in 73 of 86 cases, as a die
    ([1D4], [1D8]) in 3, and as [null] in 10, while player characters use
    ["Light (d4)"] and ["Medium (d8)"]. All five spellings mean something to the
    damage calculation, and none of them reached it.

    The parse is total: {!parse} always returns a value, and a string it could
    not understand comes back with [reduction = None]. That is the honest
    representation. It round-trips the GM's free text exactly -- which is what
    lets the codec claim a true round-trip property rather than an "up to
    normalization" one -- while making "the model could not use this" visible in
    the type, so the analysis can report it as a caveat instead of quietly
    treating unreadable armour as zero.

    Keeping [text] is also why the parsed form is a field rather than the whole
    type: ["Light (d4)"] parses to [1d4], and rendering it back as ["1d4"] would
    be a visible regression against the React UI. *)

open! Core

module Reduction : sig
  (** How much damage the armour absorbs. *)
  type t =
    | Unarmored
    | Fixed of int
    | Rolled of Dice.t
  [@@deriving compare, equal, sexp_of, quickcheck]

  val min_value : t -> int
  val max_value : t -> int

  (** What the probability model uses. Damage is convolved against the full
      distribution, not against this; [mean] is for display. *)
  val mean : t -> float
end

type t = private
  { text : string (** exactly what the user typed, stripped of edge whitespace *)
  ; reduction : Reduction.t option (** [None] when {!text} could not be parsed *)
  }
[@@deriving compare, equal, sexp_of, quickcheck]

(** Note that this compares {!text}, not {!Reduction}: ["0"] and [""] are both
    unarmoured but are not the same armour, because they are not the same thing
    to show the user. Compare [reduction] directly for the rules question. *)

val unarmored : t
val parse : string -> t

(** [parse] of a missing or [null] JSON field. Equivalent to [parse ""]. *)
val none : t

val is_unparsed : t -> bool
