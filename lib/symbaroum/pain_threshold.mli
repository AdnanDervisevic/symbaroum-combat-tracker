(** When a blow knocks a combatant prone.

    [painThreshold: number | null] hides a three-way distinction in a two-way
    type. [null] means "this creature never goes prone from pain"; [0] means
    "every hit knocks it prone", because [amount >= 0] is always true; and any
    positive number is a real threshold. The difference between the first two
    lives entirely in the reader's head and in the guard at
    {{:src/App.tsx} [App.tsx:411]}.

    {!is_exceeded} also fixes a second bug in that guard. It compares the {i raw
    number the user typed} against the threshold, before armour is subtracted --
    so a 9 typed against a combatant with 4 armour prones on 9 rather than on the
    5 that got through.

    [damage] here is the damage {i that got through armour}, deliberately not the
    amount capped by remaining toughness. The two differ only when the blow is
    lethal, and a combatant at zero toughness is down rather than prone, so the
    cap would change no outcome while making the rule harder to state. *)

open! Core

type t = private
  | No_threshold
  | Every_hit
  | At_least of int
[@@deriving compare, equal, hash, sexp_of, quickcheck]

val no_threshold : t
val every_hit : t

(** [at_least n] is {!every_hit} for [n <= 0], since a threshold of zero or less
    is met by any blow. *)
val at_least : int -> t

(** The React spelling: [None] is {!no_threshold}, [Some 0] is {!every_hit}. *)
val of_int_option : int option -> t

val to_int_option : t -> int option

(** [damage] is the damage {i dealt}, after armour and after clamping. *)
val is_exceeded : t -> damage:int -> bool
