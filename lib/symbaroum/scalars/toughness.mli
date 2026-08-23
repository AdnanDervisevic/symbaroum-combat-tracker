(** Hit points: how much is left, and how much there was.

    [toughness: number] in {{:src/types.ts} [types.ts]} is current and maximum at
    once, so a wounded combatant is indistinguishable from a weaker healthy one.
    The bound [0 <= current] is re-derived at three view-layer call sites
    ({{:src/App.tsx} [App.tsx:407]},
    {{:src/components/cards/CombatantCard.tsx} [CombatantCard.tsx:89]},
    {{:src/components/cards/CharacterCard.tsx} [CharacterCard.tsx:52]}) and at
    zero call sites on the import path, so an imported combatant can be at -40.

    [max] is not decoration: the probability model needs it to define "down", and
    the UI needs it to draw a health bar that means anything. *)

open! Core

type t = private
  { current : int
  ; max : int
  }
[@@deriving compare, equal, hash, sexp_of, quickcheck]

val min_max : int
val max_max : int

(** [Error] unless [0 <= current <= max] and [min_max <= max <= max_max]. *)
val create : current:int -> max:int -> t Or_error.t

val create_exn : current:int -> max:int -> t

(** Saturating on both bounds. The import path uses this and reports the
    repair. *)
val create_clamped : current:int -> max:int -> t

(** Undamaged. *)
val full : int -> t Or_error.t

(** [damage t n] floors at zero and returns how much was actually taken, which is
    less than [n] when the blow overkills. The pain threshold is checked against
    {i that} number, not against the raw input -- see
    {!Symbaroum.Pain_threshold}. *)
val damage : t -> int -> t * int

(** [heal t n] caps at [max] and returns how much was actually restored. *)
val heal : t -> int -> t * int

val is_down : t -> bool

(** Changing the maximum keeps [current] within it. *)
val with_max : t -> int -> t Or_error.t
