(** Initiative order, [0 .. 99].

    [initiative: number] in {{:src/types.ts} [types.ts]} is unbounded, and the
    add-NPC handler coerces it with [Number(...) || 0]
    ({{:src/App.tsx} [App.tsx:250]}), so [NaN], [-40] and [1e9] all reach the
    sort comparator. The sort is descending, so a negative value is not merely
    odd -- it silently reorders the whole encounter.

    Zero is the app's default for a player character and is kept legal: it means
    "not rolled yet", which is a real state at the top of a fight. *)

open! Core
include Bounded_int.S

(** Not rolled yet. *)
val zero : t
