(** High-water marks for the auto-generated NPC names, one per monster type.

    [addNpc] ({{:src/App.tsx} [App.tsx:231]}) names the next goblin by counting
    the goblins {i currently in the encounter}. So: add three, remove Goblin 2,
    add one more, and the new one is also called Goblin 3. The count is a
    property of the live roster; the name needs a property of the encounter's
    history. Keeping the marks {i in} the encounter is what makes them survive a
    removal -- and what makes them survive undo, export and reload, since they
    travel with the state they belong to.

    Saves written by the React app have no counter, so {!rebuild_from} recovers
    one from the highest number it can see. *)

open! Core

type t [@@deriving compare, equal, sexp_of]

val empty : t

(** The monster type used for NPCs added without one, so that ["NPC 3"] is
    counted by the same machinery as ["Goblin 3"]. *)
val anonymous : Monster_type.t

(** The next number for this type, and the counter that has taken it. *)
val next : t -> Monster_type.t -> t * int

(** [next_n t monster_type n] takes [n] numbers in one step. *)
val next_n : t -> Monster_type.t -> int -> t * int list

(** Raise a mark to at least [n]. Used when a name is supplied by hand rather
    than generated, so a later automatic name cannot collide with it. *)
val reserve : t -> Monster_type.t -> int -> t

(** The highest number handed out so far, or 0. *)
val peek : t -> Monster_type.t -> int

(** Derive marks from names that already exist, for save files written before
    this type did. A mark is the larger of the highest numeric suffix seen
    (["Goblin 7"] gives 7) and the number of combatants of that type, so a
    hand-named group still cannot collide. *)
val rebuild_from : (Monster_type.t * Name.t) list -> t * Normalization.t list

val to_alist : t -> (Monster_type.t * int) list
